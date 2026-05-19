import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../entities/otp_dispatch_command.dart';
import '../repositories/otp_gateway_repository.dart';
import '../../../shared/domain/audit_log_service.dart';

class ReceiveDispatchCommandUseCase {
  final OtpGatewayRepository _repository;
  final AuditLogService _auditLogService;
  final _uuid = const Uuid();

  const ReceiveDispatchCommandUseCase({
    required OtpGatewayRepository repository,
    required AuditLogService auditLogService,
  })  : _repository = repository,
        _auditLogService = auditLogService;

  Future<Either<OtpGatewayFailure, OtpDispatchCommand>> execute({
    required String commandId,
    required String systemId,
  }) async {
    final result = await _repository.fetchCommand(
      commandId: commandId,
      systemId: systemId,
    );
    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: AuditActionType.otpDispatchReceived,
      systemId: systemId,
      commandId: commandId,
      timestamp: DateTime.now().toUtc(),
      outcome: result.isRight() ? AuditOutcome.success : AuditOutcome.failure,
    ));
    return result;
  }
}
