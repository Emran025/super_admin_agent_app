import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../repositories/auth_challenge_repository.dart';
import '../value_objects/signed_challenge_response.dart';
import '../../../shared/domain/audit_log_service.dart';

/// Submits a signed challenge response to the server.
///
/// Audit log is written BEFORE the network call (Constraint 2.3):
/// - A `partial` entry is written first — honest about the attempt.
/// - After the call, a `success` or `failure` entry is written.
/// This guarantees the audit trail even if the app crashes mid-call.
class SubmitChallengeResponseUseCase {
  final AuthChallengeRepository _repository;
  final AuditLogService _auditLogService;
  final _uuid = const Uuid();

  const SubmitChallengeResponseUseCase({
    required AuthChallengeRepository repository,
    required AuditLogService auditLogService,
  })  : _repository = repository,
        _auditLogService = auditLogService;

  Future<Either<AuthChallengeFailure, void>> execute({
    required SignedChallengeResponse response,
    required String systemId,
  }) async {
    // Step 1: Write pre-submission audit entry (Constraint 2.3 — BEFORE network).
    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: AuditActionType.challengeResponded,
      systemId: systemId,
      commandId: response.challengeId,
      timestamp: DateTime.now().toUtc(),
      outcome: AuditOutcome.partial,
    ));

    // Step 2: Submit to server.
    final result = await _repository.submitResponse(
      response: response,
      systemId: systemId,
    );

    // Step 3: Write outcome audit entry.
    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: result.isRight()
          ? AuditActionType.challengeResponded
          : AuditActionType.challengeSubmissionFailed,
      systemId: systemId,
      commandId: response.challengeId,
      timestamp: DateTime.now().toUtc(),
      outcome: result.isRight() ? AuditOutcome.success : AuditOutcome.failure,
      failureCode: result.isLeft() ? 'SUBMISSION_FAILED' : null,
    ));

    return result;
  }
}
