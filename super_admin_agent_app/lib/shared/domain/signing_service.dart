import 'package:dartz/dartz.dart';

// ---------------------------------------------------------------------------
// Failures
// ---------------------------------------------------------------------------

abstract class SigningFailure {
  const SigningFailure();
}

class KeyUnavailableFailure extends SigningFailure {
  const KeyUnavailableFailure();
}

class SigningOperationFailure extends SigningFailure {
  final Object? cause;
  const SigningOperationFailure({this.cause});
}

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

/// The sole signing path in the system (Constraint 2.2).
///
/// Callers receive a [String] signature — key material is never exposed.
/// All keys are managed internally by the implementation.
abstract class SigningService {
  /// The key alias sent in the [X-Agent-Public-Key-Id] header.
  String get publicKeyId;

  /// DER-encoded public key, base64url encoded.
  Either<SigningFailure, String> getPublicKeyBase64();

  /// Generate the EC P-256 key pair. Idempotent — safe to call multiple times.
  /// Called once during the pairing ceremony.
  Future<Either<SigningFailure, void>> generateKeyPair();

  /// Loads an existing key pair from secure storage into memory.
  ///
  /// Call this at app startup (both UI and background isolates) so that
  /// [publicKeyId] and [getPublicKeyBase64] are always populated when a
  /// key pair has previously been generated. Unlike [generateKeyPair], this
  /// never creates a new key — it is a no-op when no key exists.
  Future<void> loadExistingKeyPair();

  /// Returns true when a key pair has been generated and is stored.
  Future<bool> hasKeyPair();

  /// Returns a base64url-encoded ECDSA-SHA256 signature over [canonicalInput].
  ///
  /// The private key is never exposed to callers — it is retrieved internally
  /// from [SecureStorageService] and used only within this call's scope.
  Future<Either<SigningFailure, String>> sign(String canonicalInput);

  /// Permanently deletes the key pair. Called only on full unpair.
  Future<Either<SigningFailure, void>> deleteKeyPair();
}
