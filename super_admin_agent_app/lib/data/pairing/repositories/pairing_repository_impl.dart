import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../domain/pairing/entities/paired_system.dart';
import '../../../domain/pairing/entities/pairing_token.dart';
import '../../../domain/pairing/repositories/pairing_repository.dart';
import '../../../shared/domain/secure_storage_service.dart';
import '../dtos/pairing_dtos.dart';

// Secure storage keys for Reverb WebSocket connection parameters.
// Must match the constants in AgentWebSocketService.
const _kReverbHost = 'reverb_host';
const _kReverbPort = 'reverb_port';
const _kReverbAppKey = 'reverb_app_key';

/// Concrete implementation of [PairingRepository].
///
/// Uses a plain unauthenticated [Dio] instance — the only acceptable
/// use of raw [Dio()] in this codebase. At pairing time, there is no
/// agent identity to sign with. Authentication is the one-time token
/// in the request body. (Spec §4 justification)
///
/// All URLs come from the QR token — never hardcoded (Constraint 2.2 / Axiom 9).
///
/// After a successful server registration, the Reverb WebSocket connection
/// parameters (reverb_host, reverb_port, reverb_app_key) returned in the
/// pairing response are stored in secure storage so that [AgentWebSocketService]
/// can connect to Reverb at startup without re-fetching them.
class PairingRepositoryImpl implements PairingRepository {
  static const String _storageKey = 'paired_systems_json_list';

  final SecureStorageService _secureStorage;

  // Plain unauthenticated Dio — intentional, see class doc.
  final Dio _dio;

  PairingRepositoryImpl({
    required SecureStorageService secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _dio = dio ?? Dio();

  @override
  Either<PairingFailure, PairingToken> parsePairingToken(String rawQrValue) {
    try {
      final dto = PairingTokenDto.fromJson(rawQrValue);
      final entity = dto.toEntity();

      // Surface expired tokens as a distinct failure type.
      if (entity.isExpired) {
        return const Left(TokenExpiredFailure());
      }

      return Right(entity);
    } on FormatException catch (e) {
      return Left(TokenInvalidFailure(e.message));
    } catch (_) {
      return const Left(TokenInvalidFailure('Missing or invalid required field'));
    }
  }

  @override
  Future<Either<PairingFailure, PairedSystem>> registerWithServer({
    required PairingToken token,
    required String publicKeyBase64,
    required String publicKeyId,
  }) async {
    try {
      // URL comes from the QR token — never hardcoded (Axiom 9 / CF-03).
      final response = await _dio.post<Map<String, dynamic>>(
        '${token.pairingEndpoint}/v1/pair',
        data: {
          'pairing_token': token.token,
          'public_key_base64': publicKeyBase64,
          'public_key_id': publicKeyId,
        },
      );

      final body = response.data;
      if (body == null) {
        return const Left(RegistrationFailure('Empty server response'));
      }

      final dto = PairedSystemDto.fromJson(body);

      // Persist Reverb WebSocket connection parameters to secure storage so
      // that AgentWebSocketService can connect to Reverb after pairing.
      // These are NOT part of the PairedSystem entity itself.
      await _saveReverbParams(dto);

      return Right(dto.toEntity());
    } on DioException catch (e) {
      return Left(RegistrationFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(RegistrationFailure(e.toString()));
    }
  }

  @override
  Future<Either<PairingFailure, void>> savePairedSystem(
    PairedSystem system,
  ) async {
    final loadResult = await _loadAll();
    final systems = loadResult.getOrElse(() => []);

    // Replace existing entry if systemId already present, else append.
    final updated = [
      ...systems.where((s) => s.systemId != system.systemId),
      system,
    ];

    return _persistAll(updated);
  }

  @override
  Future<Either<PairingFailure, List<PairedSystem>>> loadPairedSystems() async {
    return _loadAll();
  }

  @override
  Future<Either<PairingFailure, void>> removePairedSystem(
    String systemId,
  ) async {
    final loadResult = await _loadAll();
    final systems = loadResult.getOrElse(() => []);
    final updated = systems.where((s) => s.systemId != systemId).toList();
    return _persistAll(updated);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Saves Reverb WebSocket connection parameters from the server pairing
  /// response to secure storage. Silently skips fields that are absent
  /// (e.g. during unit tests with partial mocks).
  Future<void> _saveReverbParams(PairedSystemDto dto) async {
    if (dto.reverbHost != null) {
      await _secureStorage.write(key: _kReverbHost, value: dto.reverbHost!);
    }
    if (dto.reverbPort != null) {
      await _secureStorage.write(
        key: _kReverbPort,
        value: dto.reverbPort!.toString(),
      );
    }
    if (dto.reverbAppKey != null) {
      await _secureStorage.write(
        key: _kReverbAppKey,
        value: dto.reverbAppKey!,
      );
    }
  }

  Future<Either<PairingFailure, List<PairedSystem>>> _loadAll() async {
    final readResult = await _secureStorage.read(key: _storageKey);
    return readResult.fold(
      (_) => const Left(StorePairedSystemFailure(cause: 'Read failed')),
      (raw) {
        if (raw == null || raw.isEmpty) return const Right([]);
        try {
          final list = jsonDecode(raw) as List;
          final systems = list
              .map((e) => PairedSystemDto.fromJson(e as Map<String, dynamic>).toEntity())
              .toList();
          return Right(systems);
        } catch (e) {
          return Left(StorePairedSystemFailure(cause: e));
        }
      },
    );
  }

  Future<Either<PairingFailure, void>> _persistAll(
    List<PairedSystem> systems,
  ) async {
    try {
      final json = jsonEncode(
        systems.map((s) => PairedSystemDto.fromEntity(s).toJson()).toList(),
      );
      final writeResult = await _secureStorage.write(
        key: _storageKey,
        value: json,
      );
      return writeResult.fold(
        (e) => Left(StorePairedSystemFailure(cause: e)),
        (_) => const Right(null),
      );
    } catch (e) {
      return Left(StorePairedSystemFailure(cause: e));
    }
  }
}
