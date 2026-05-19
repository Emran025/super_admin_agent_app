import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../repositories/otp_gateway_repository.dart';
import '../value_objects/sms_delivery_report.dart';
import '../../../shared/domain/audit_log_service.dart';

/// Reports delivery status to the server.
///
/// Audit log is written BEFORE the network call (Constraint 2.3 pattern).
/// Report is submitted even on delivery failure — server decides retry (Constraint 2.2).
class ReportDeliveryStatusUseCase {
  final OtpGatewayRepository _repository;
  final AuditLogService _auditLogService;
  final _uuid = const Uuid();

  const ReportDeliveryStatusUseCase({
    required OtpGatewayRepository repository,
    required AuditLogService auditLogService,
  })  : _repository = repository,
        _auditLogService = auditLogService;

  Future<Either<OtpGatewayFailure, void>> execute({
    required SmsDeliveryReport report,
    required String systemId,
  }) async {
    // Write pre-submission audit entry BEFORE the network call.
    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: report.status == SmsDeliveryStatus.sent ||
              report.status == SmsDeliveryStatus.delivered
          ? AuditActionType.otpSmsSent
          : AuditActionType.otpSmsFailed,
      systemId: systemId,
      commandId: report.commandId,
      timestamp: DateTime.now().toUtc(),
      outcome: AuditOutcome.partial,
    ));

    final result = await _repository.submitDeliveryReport(
      report: report,
      systemId: systemId,
    );

    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: AuditActionType.otpReportSubmitted,
      systemId: systemId,
      commandId: report.commandId,
      timestamp: DateTime.now().toUtc(),
      outcome: result.isRight() ? AuditOutcome.success : AuditOutcome.failure,
    ));

    return result;
  }
}
