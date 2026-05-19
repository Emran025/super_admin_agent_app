import 'package:dartz/dartz.dart';
import '../entities/otp_dispatch_command.dart';
import '../value_objects/sms_delivery_report.dart';

abstract class OtpGatewayFailure { const OtpGatewayFailure(); }
class CommandNotFoundFailure extends OtpGatewayFailure { const CommandNotFoundFailure(); }
class CommandAlreadyDispatchedFailure extends OtpGatewayFailure { const CommandAlreadyDispatchedFailure(); }
class SmsDispatchFailure extends OtpGatewayFailure {
  final String detail;
  const SmsDispatchFailure(this.detail);
}
class ReportSubmissionFailure extends OtpGatewayFailure {
  final String detail;
  const ReportSubmissionFailure(this.detail);
}

abstract class OtpGatewayRepository {
  Future<Either<OtpGatewayFailure, OtpDispatchCommand>> fetchCommand({
    required String commandId,
    required String systemId,
  });

  Future<Either<OtpGatewayFailure, void>> submitDeliveryReport({
    required SmsDeliveryReport report,
    required String systemId,
  });
}
