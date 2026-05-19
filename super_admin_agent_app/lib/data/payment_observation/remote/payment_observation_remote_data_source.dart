import 'package:dio/dio.dart';

import '../../../domain/payment_observation/entities/payment_observation_session.dart';
import '../../../domain/payment_observation/repositories/payment_observation_repository.dart';
import '../../../domain/payment_observation/value_objects/observation_report.dart';
import '../dtos/observation_report_dto.dart';
import '../dtos/payment_observation_session_dto.dart';

/// Remote data source for the payment observation capability.
class PaymentObservationRemoteDataSource {
  final Dio _dio;

  const PaymentObservationRemoteDataSource({required Dio dio}) : _dio = dio;

  Future<PaymentObservationSession> fetchSession(String sessionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/payment-sessions/$sessionId',
      );
      return PaymentObservationSessionDto.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const SessionNotFoundFailure();
      }
      if (e.response?.statusCode == 410) {
        throw const SessionNotActiveFailure();
      }
      rethrow;
    }
  }

  Future<void> submitReport(ObservationReport report) async {
    await _dio.post<void>(
      '/v1/payment-sessions/${report.sessionId}/report',
      data: ObservationReportDto.toJson(report),
    );
  }
}
