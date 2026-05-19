import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../repositories/pairing_repository.dart';
import '../../../shared/domain/audit_log_service.dart';

/// Removes a paired system and logs the outcome.
///
/// Audit entry is written here — NOT in the repository (Constraint 2.7).
class UnpairSystemUseCase {
  final PairingRepository _repository;
  final AuditLogService _auditLogService;
  final _uuid = const Uuid();

  const UnpairSystemUseCase({
    required PairingRepository repository,
    required AuditLogService auditLogService,
  })  : _repository = repository,
        _auditLogService = auditLogService;

  Future<Either<PairingFailure, void>> execute(String systemId) async {
    final result = await _repository.removePairedSystem(systemId);

    final outcome = result.isRight() ? AuditOutcome.success : AuditOutcome.failure;
    final failureCode = result.isLeft() ? 'REMOVE_FAILED' : null;

    await _auditLogService.log(
      AuditEntry(
        entryId: _uuid.v4(),
        actionType: AuditActionType.unpairingCompleted,
        systemId: systemId,
        timestamp: DateTime.now().toUtc(),
        outcome: outcome,
        failureCode: failureCode,
      ),
    );

    return result;
  }
}
