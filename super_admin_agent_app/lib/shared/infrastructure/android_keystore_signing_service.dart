import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';

import '../domain/secure_storage_service.dart';
import '../domain/signing_service.dart';

/// Phase 1 software-backed implementation of [SigningService].
///
/// Uses pointycastle for EC P-256 key generation and ECDSA-SHA256 signing.
/// The private key is stored in [SecureStorageService] and is NEVER exposed
/// to callers (Constraint 2.4).
///
/// # TODO(phase-7-android): Replace with Android Keystore hardware binding
/// - Platform channel call to Android Keystore for key generation
/// - Hardware-backed signing: private key never exists in Dart memory
/// - Synchronous [publicKeyId] from hardware key alias
class AndroidKeystoreSigningService implements SigningService {
  static const String _privateKeyStorageKey = 'agent_ec_private_key_bytes';
  static const String _publicKeyStorageKey = 'agent_ec_public_key_bytes';
  static const String _keyIdStorageKey = 'agent_key_id';

  final SecureStorageService _secureStorage;
  final _uuid = const Uuid();

  String? _cachedPublicKeyBase64;
  String? _cachedKeyId;

  AndroidKeystoreSigningService({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  @override
  String get publicKeyId {
    // TODO(phase-7-android): Return hardware key alias from Android Keystore.
    return _cachedKeyId ?? '';
  }

  @override
  Either<SigningFailure, String> getPublicKeyBase64() {
    if (_cachedPublicKeyBase64 == null) {
      return const Left(KeyUnavailableFailure());
    }
    return Right(_cachedPublicKeyBase64!);
  }

  @override
  Future<bool> hasKeyPair() async {
    final result = await _secureStorage.read(key: _privateKeyStorageKey);
    return result.fold((_) => false, (v) => v != null);
  }

  @override
  Future<void> loadExistingKeyPair() async {
    if (await hasKeyPair()) {
      await _loadCachedPublicKey();
    }
  }

  @override
  Future<Either<SigningFailure, void>> generateKeyPair() async {
    try {
      // Idempotent: skip if key already exists.
      if (await hasKeyPair()) {
        await _loadCachedPublicKey();
        return const Right(null);
      }

      // Generate EC P-256 key pair via pointycastle.
      final domainParams = ECDomainParameters('prime256v1');
      final keyGen = ECKeyGenerator()
        ..init(
          ParametersWithRandom(
            ECKeyGeneratorParameters(domainParams),
            _buildSecureRandom(),
          ),
        );

      final keyPair = keyGen.generateKeyPair();
      final privateKey = keyPair.privateKey as ECPrivateKey;
      final publicKey = keyPair.publicKey as ECPublicKey;

      // Encode private key scalar as 32-byte big-endian.
      final privateBytes = _encodePrivateKey(privateKey);
      // Encode public key as uncompressed point (65 bytes: 04 || X || Y).
      final publicBytes = _encodePublicKey(publicKey);

      final keyId = _uuid.v4();

      // Write to secure storage — private key leaves this scope only as bytes
      // on the way to encrypted storage. It is never returned to callers.
      final writePrivate = await _secureStorage.write(
        key: _privateKeyStorageKey,
        value: base64Url.encode(privateBytes),
      );
      if (writePrivate.isLeft()) {
        // ignore: prefer_const_constructors
        return Left(
          // ignore: prefer_const_constructors
          SigningOperationFailure(cause: 'Failed to store private key'),
        );
      }

      final writePublic = await _secureStorage.write(
        key: _publicKeyStorageKey,
        value: base64Url.encode(publicBytes),
      );
      if (writePublic.isLeft()) {
        // ignore: prefer_const_constructors
        return Left(
          // ignore: prefer_const_constructors
          SigningOperationFailure(cause: 'Failed to store public key'),
        );
      }

      final writeId = await _secureStorage.write(
        key: _keyIdStorageKey,
        value: keyId,
      );
      if (writeId.isLeft()) {
        // ignore: prefer_const_constructors
        return Left(
          // ignore: prefer_const_constructors
          SigningOperationFailure(cause: 'Failed to store key ID'),
        );
      }

      _cachedPublicKeyBase64 = base64Url.encode(publicBytes);
      _cachedKeyId = keyId;

      return const Right(null);
    } catch (e) {
      return Left(SigningOperationFailure(cause: e));
    }
  }

  @override
  Future<Either<SigningFailure, String>> sign(String canonicalInput) async {
    try {
      // Read private key from secure storage.
      final readResult = await _secureStorage.read(key: _privateKeyStorageKey);
      final privateKeyBase64 = readResult.fold(
        (_) => null,
        (v) => v,
      );

      if (privateKeyBase64 == null) {
        return const Left(KeyUnavailableFailure());
      }

      final privateBytes = base64Url.decode(privateKeyBase64);
      final domainParams = ECDomainParameters('prime256v1');
      final privateKey = ECPrivateKey(
        _decodeBigInt(privateBytes),
        domainParams,
      );

      // Sign with ECDSA-SHA256.
      final signer = Signer('SHA-256/ECDSA')
        ..init(
          true,
          ParametersWithRandom(
            PrivateKeyParameter<ECPrivateKey>(privateKey),
            _buildSecureRandom(),
          ),
        );

      final message = Uint8List.fromList(utf8.encode(canonicalInput));
      final ecSig = signer.generateSignature(message) as ECSignature;

      // DER-encode the signature.
      final derBytes = _derEncodeSignature(ecSig);
      final signature = base64Url.encode(derBytes).replaceAll('=', '');

      return Right(signature);
    } catch (e) {
      return Left(SigningOperationFailure(cause: e));
    }
  }

  @override
  Future<Either<SigningFailure, void>> deleteKeyPair() async {
    try {
      await _secureStorage.delete(key: _privateKeyStorageKey);
      await _secureStorage.delete(key: _publicKeyStorageKey);
      await _secureStorage.delete(key: _keyIdStorageKey);
      _cachedPublicKeyBase64 = null;
      _cachedKeyId = null;
      return const Right(null);
    } catch (e) {
      return Left(SigningOperationFailure(cause: e));
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadCachedPublicKey() async {
    final pubResult = await _secureStorage.read(key: _publicKeyStorageKey);
    pubResult.fold((_) {}, (v) => _cachedPublicKeyBase64 = v);
    final idResult = await _secureStorage.read(key: _keyIdStorageKey);
    idResult.fold((_) {}, (v) => _cachedKeyId = v);
  }

  Uint8List _encodePrivateKey(ECPrivateKey key) {
    final bytes = _encodeBigInt(key.d!);
    // Pad to 32 bytes if necessary.
    if (bytes.length < 32) {
      return Uint8List(32)..setRange(32 - bytes.length, 32, bytes);
    }
    return bytes;
  }

  Uint8List _encodePublicKey(ECPublicKey key) {
    final q = key.Q!;
    final x = _encodeBigInt(q.x!.toBigInteger()!);
    final y = _encodeBigInt(q.y!.toBigInteger()!);
    final result = Uint8List(65);
    result[0] = 0x04; // Uncompressed point marker.
    result.setRange(1, 33, x.length < 32 ? (Uint8List(32)..setRange(32 - x.length, 32, x)) : x);
    result.setRange(33, 65, y.length < 32 ? (Uint8List(32)..setRange(32 - y.length, 32, y)) : y);
    return result;
  }

  Uint8List _encodeBigInt(BigInt number) {
    final bytes = <int>[];
    var n = number;
    while (n > BigInt.zero) {
      bytes.add((n & BigInt.from(0xFF)).toInt());
      n >>= 8;
    }
    return Uint8List.fromList(bytes.reversed.toList());
  }

  BigInt _decodeBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  /// DER-encode an ECDSA (r, s) signature pair.
  Uint8List _derEncodeSignature(ECSignature sig) {
    final r = _encodeDerInteger(sig.r);
    final s = _encodeDerInteger(sig.s);
    final payload = [...r, ...s];
    return Uint8List.fromList([
      0x30,
      payload.length,
      ...payload,
    ]);
  }

  List<int> _encodeDerInteger(BigInt value) {
    final bytes = _encodeBigInt(value);
    // If high bit is set, prepend 0x00 to avoid sign ambiguity.
    final padded =
        (bytes.isNotEmpty && bytes[0] & 0x80 != 0) ? [0x00, ...bytes] : bytes;
    return [0x02, padded.length, ...padded];
  }

  FortunaRandom _buildSecureRandom() {
    final secureRandom = FortunaRandom();
    final rng = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }
}
