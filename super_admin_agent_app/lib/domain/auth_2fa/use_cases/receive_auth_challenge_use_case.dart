import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../entities/auth_challenge.dart';
import '../repositories/auth_challenge_repository.dart';
import '../../../shared/domain/audit_log_service.dart';

class ReceiveAuthChallengeUseCase {
  final AuthChallengeRepository _repository;
  final AuditLogService _auditLogService;
  final _uuid = const Uuid();

  const ReceiveAuthChallengeUseCase({
    required AuthChallengeRepository repository,
    required AuditLogService auditLogService,
  })  : _repository = repository,
        _auditLogService = auditLogService;

  Future<Either<AuthChallengeFailure, AuthChallenge>> execute({
    required String challengeId,
    required String systemId,
  }) async {
    final result = await _repository.fetchChallenge(
      challengeId: challengeId,
      systemId: systemId,
    );

    final outcome = result.isRight() ? AuditOutcome.success : AuditOutcome.failure;
    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: AuditActionType.challengeReceived,
      systemId: systemId,
      commandId: challengeId,
      timestamp: DateTime.now().toUtc(),
      outcome: outcome,
    ));

    return result;
  }
}
