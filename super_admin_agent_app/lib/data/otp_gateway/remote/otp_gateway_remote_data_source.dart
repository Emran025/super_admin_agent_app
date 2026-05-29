import 'package:dio/dio.dart';

import '../../../domain/otp_gateway/entities/otp_dispatch_command.dart';
import '../../../domain/otp_gateway/repositories/otp_gateway_repository.dart';
import '../../../domain/otp_gateway/value_objects/sms_delivery_report.dart';
import '../dtos/otp_dispatch_command_dto.dart';

/// Remote data source for the OTP Gateway capability.
///
/// Communicates with the server via an authenticated [Dio] instance produced
/// by [HttpClientFactory.forSystem()]. Auth headers are added by the
/// signing interceptor — never added here directly.
///
/// The message body is NEVER included in the delivery report POST body.
class OtpGatewayRemoteDataSource {
  final Dio _dio;

  const OtpGatewayRemoteDataSource({required Dio dio}) : _dio = dio;

  /// Fetches an OTP dispatch command from [GET /v1/otp-commands/{commandId}].
  Future<OtpDispatchCommand> fetchCommand(String commandId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/otp-commands/$commandId',
      );
      return OtpDispatchCommandDto.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const CommandNotFoundFailure();
      }
      if (e.response?.statusCode == 409) {
        throw const CommandAlreadyDispatchedFailure();
      }
      rethrow;
    }
  }

  /// Submits a delivery report to [POST /v1/otp-commands/{commandId}/report].
  ///
  /// The POST body contains only signed metadata — NO message body.
  Future<void> submitDeliveryReport(SmsDeliveryReport report) async {
    final serverStatus = switch (report.status) {
      SmsDeliveryStatus.sent || SmsDeliveryStatus.delivered => 'delivered',
      SmsDeliveryStatus.failedNoService || SmsDeliveryStatus.failedGeneric => 'failed',
    };

    await _dio.post<void>(
      '/api/v1/otp-commands/${report.commandId}/report',
      data: {
        'command_id': report.commandId,
        'status': serverStatus,
        'reported_at': report.reportedAt.toIso8601String(),
        'nonce': report.nonce,
        'agent_public_key_id': report.agentPublicKeyId,
        'signature': report.signature,
      },
    );
  }
}
