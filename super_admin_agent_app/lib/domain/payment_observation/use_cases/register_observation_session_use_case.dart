import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../entities/payment_observation_session.dart';
import '../repositories/payment_observation_repository.dart';
import '../../../shared/domain/audit_log_service.dart';

/// Fetches a payment observation session and logs the event.
class RegisterObservationSessionUseCase {
  final PaymentObservationRepository _repository;
  final AuditLogService _auditLogService;
  final _uuid = const Uuid();

  const RegisterObservationSessionUseCase({
    required PaymentObservationRepository repository,
    required AuditLogService auditLogService,
  })  : _repository = repository,
        _auditLogService = auditLogService;

  Future<Either<PaymentObservationFailure, PaymentObservationSession>> execute({
    required String sessionId,
    required String systemId,
  }) async {
    final result = await _repository.fetchSession(
      sessionId: sessionId,
      systemId: systemId,
    );

    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: AuditActionType.paymentSessionOpened,
      systemId: systemId,
      commandId: sessionId,
      timestamp: DateTime.now().toUtc(),
      outcome: result.isRight() ? AuditOutcome.success : AuditOutcome.failure,
    ));

    return result;
  }
}
