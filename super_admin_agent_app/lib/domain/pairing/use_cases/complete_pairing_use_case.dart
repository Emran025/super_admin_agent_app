import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../entities/paired_system.dart';
import '../entities/pairing_token.dart';
import '../repositories/pairing_repository.dart';
import '../../../shared/domain/audit_log_service.dart';
import '../../../shared/domain/signing_service.dart';

/// Executes the full pairing ceremony in strict order (Constraint 2.7).
///
/// Step order is NOT negotiable:
/// 1. Check token expiry
/// 2. Generate key pair
/// 3. Get public key
/// 4. Register with server
/// 5. Save paired system
/// 6. Log success
/// 7. Return Right(pairedSystem)
///
/// Audit entries are written HERE — never from the repository (Constraint 2.7).
class CompletePairingUseCase {
  final PairingRepository _repository;
  final SigningService _signingService;
  final AuditLogService _auditLogService;
  final _uuid = const Uuid();

  const CompletePairingUseCase({
    required PairingRepository repository,
    required SigningService signingService,
    required AuditLogService auditLogService,
  })  : _repository = repository,
        _signingService = signingService,
        _auditLogService = auditLogService;

  Future<Either<PairingFailure, PairedSystem>> execute(
    PairingToken token,
  ) async {
    // Step 1: Check token expiry (Constraint 2.3).
    if (token.isExpired) {
      await _log(
        systemId: token.systemId,
        actionType: AuditActionType.pairingFailed,
        outcome: AuditOutcome.failure,
        failureCode: 'TOKEN_EXPIRED',
      );
      return const Left(TokenExpiredFailure());
    }

    // Step 2: Generate key pair — idempotent.
    final keyGenResult = await _signingService.generateKeyPair();
    if (keyGenResult.isLeft()) {
      await _log(
        systemId: token.systemId,
        actionType: AuditActionType.pairingFailed,
        outcome: AuditOutcome.failure,
        failureCode: 'KEY_GEN_FAILED',
      );
      return Left(
        _signingFailureToPairingFailure(keyGenResult),
      );
    }

    // Step 3: Get public key bytes.
    final publicKeyResult = _signingService.getPublicKeyBase64();
    if (publicKeyResult.isLeft()) {
      await _log(
        systemId: token.systemId,
        actionType: AuditActionType.pairingFailed,
        outcome: AuditOutcome.failure,
        failureCode: 'PUBLIC_KEY_UNAVAILABLE',
      );
      return const Left(RegistrationFailure('Public key unavailable'));
    }
    final publicKeyBase64 = publicKeyResult.getOrElse(() => '');

    // Step 4: Register with server.
    final registerResult = await _repository.registerWithServer(
      token: token,
      publicKeyBase64: publicKeyBase64,
      publicKeyId: _signingService.publicKeyId,
    );
    if (registerResult.isLeft()) {
      await _log(
        systemId: token.systemId,
        actionType: AuditActionType.pairingFailed,
        outcome: AuditOutcome.failure,
        failureCode: 'REGISTRATION_FAILED',
      );
      return registerResult;
    }
    final pairedSystem = registerResult.getOrElse(
      () => throw StateError('unreachable'),
    );

    // Step 5: Save paired system.
    final saveResult = await _repository.savePairedSystem(pairedSystem);
    if (saveResult.isLeft()) {
      await _log(
        systemId: token.systemId,
        actionType: AuditActionType.pairingFailed,
        outcome: AuditOutcome.failure,
        failureCode: 'SAVE_FAILED',
      );
      return const Left(StorePairedSystemFailure(cause: 'Save failed'));
    }

    // Step 6: Log success.
    await _log(
      systemId: token.systemId,
      actionType: AuditActionType.pairingCompleted,
      outcome: AuditOutcome.success,
    );

    // Step 7: Return.
    return Right(pairedSystem);
  }

  Future<void> _log({
    required String systemId,
    required AuditActionType actionType,
    required AuditOutcome outcome,
    String? failureCode,
  }) async {
    await _auditLogService.log(
      AuditEntry(
        entryId: _uuid.v4(),
        actionType: actionType,
        systemId: systemId,
        timestamp: DateTime.now().toUtc(),
        outcome: outcome,
        failureCode: failureCode,
      ),
    );
  }

  PairingFailure _signingFailureToPairingFailure(
    Either<SigningFailure, void> result,
  ) {
    return result.fold(
      (failure) => failure is KeyUnavailableFailure
          ? const RegistrationFailure('Key unavailable')
          : const RegistrationFailure('Signing operation failed'),
      (_) => const RegistrationFailure('Unknown signing failure'),
    );
  }
}
