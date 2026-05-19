import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/otp_gateway/repositories/otp_gateway_repository.dart';
import 'package:super_admin_agent/domain/otp_gateway/use_cases/report_delivery_status_use_case.dart';
import 'package:super_admin_agent/domain/otp_gateway/value_objects/sms_delivery_report.dart';
import 'package:super_admin_agent/shared/domain/audit_log_service.dart';

class MockOtpGatewayRepository extends Mock implements OtpGatewayRepository {}
class MockAuditLogService extends Mock implements AuditLogService {}
class _FakeAuditEntry extends Fake implements AuditEntry {}
class _FakeSmsDeliveryReport extends Fake implements SmsDeliveryReport {}

void main() {
  late MockOtpGatewayRepository repository;
  late MockAuditLogService auditLogService;
  late ReportDeliveryStatusUseCase useCase;

  setUpAll(() {
    registerFallbackValue(_FakeAuditEntry());
    registerFallbackValue(_FakeSmsDeliveryReport());
  });

  setUp(() {
    repository = MockOtpGatewayRepository();
    auditLogService = MockAuditLogService();
    useCase = ReportDeliveryStatusUseCase(
      repository: repository,
      auditLogService: auditLogService,
    );

    when(() => auditLogService.log(any())).thenAnswer((_) async => const Right(null));
  });

  final _report = SmsDeliveryReport(
    commandId: 'cmd-1',
    status: SmsDeliveryStatus.failedNoService,
    reportedAt: DateTime.now(),
    nonce: 'n',
    signature: 's',
    agentPublicKeyId: 'k',
  );

  test('audit log partial entry is written BEFORE repository call, even for failures', () async {
    when(() => repository.submitDeliveryReport(report: any(named: 'report'), systemId: any(named: 'systemId')))
        .thenAnswer((_) async => const Right(null));

    await useCase.execute(report: _report, systemId: 'sys-1');

    final captured = verify(() => auditLogService.log(captureAny())).captured;
    expect(captured.length, 2);

    final firstEntry = captured.first as AuditEntry;
    expect(firstEntry.outcome, AuditOutcome.partial);
    expect(firstEntry.actionType, AuditActionType.otpSmsFailed);

    final secondEntry = captured.last as AuditEntry;
    expect(secondEntry.outcome, AuditOutcome.success);
    expect(secondEntry.actionType, AuditActionType.otpReportSubmitted);
  });
}
