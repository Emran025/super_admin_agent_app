import 'package:dartz/dartz.dart';

import '../../../domain/otp_gateway/entities/otp_dispatch_command.dart';
import '../../../domain/otp_gateway/repositories/otp_gateway_repository.dart';
import '../../../domain/otp_gateway/value_objects/sms_delivery_report.dart';
import '../../../shared/data/http_client_factory.dart';
import '../remote/otp_gateway_remote_data_source.dart';

/// Implements [OtpGatewayRepository].
///
/// Creates a system-specific [OtpGatewayRemoteDataSource] per call using
/// [HttpClientFactory.forSystem()]. This ensures each request carries the
/// correct [agentId] in the auth headers.
class OtpGatewayRepositoryImpl implements OtpGatewayRepository {
  final HttpClientFactory _clientFactory;

  const OtpGatewayRepositoryImpl({required HttpClientFactory clientFactory})
      : _clientFactory = clientFactory;

  @override
  Future<Either<OtpGatewayFailure, OtpDispatchCommand>> fetchCommand({
    required String commandId,
    required String systemId,
  }) async {
    try {
      final source = OtpGatewayRemoteDataSource(
        dio: _clientFactory.forSystem(systemId),
      );
      final command = await source.fetchCommand(commandId);
      return Right(command);
    } on OtpGatewayFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(SmsDispatchFailure(e.toString()));
    }
  }

  @override
  Future<Either<OtpGatewayFailure, void>> submitDeliveryReport({
    required SmsDeliveryReport report,
    required String systemId,
  }) async {
    try {
      final source = OtpGatewayRemoteDataSource(
        dio: _clientFactory.forSystem(systemId),
      );
      await source.submitDeliveryReport(report);
      return const Right(null);
    } on OtpGatewayFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ReportSubmissionFailure(e.toString()));
    }
  }
}
