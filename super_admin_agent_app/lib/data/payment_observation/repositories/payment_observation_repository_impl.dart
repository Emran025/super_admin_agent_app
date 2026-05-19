import 'package:dartz/dartz.dart';

import '../../../domain/payment_observation/entities/payment_observation_session.dart';
import '../../../domain/payment_observation/repositories/payment_observation_repository.dart';
import '../../../domain/payment_observation/value_objects/observation_report.dart';
import '../../../shared/data/http_client_factory.dart';
import '../remote/payment_observation_remote_data_source.dart';

/// Implements [PaymentObservationRepository].
///
/// Creates a system-specific data source per call using
/// [HttpClientFactory.forSystem()].
class PaymentObservationRepositoryImpl implements PaymentObservationRepository {
  final HttpClientFactory _clientFactory;

  const PaymentObservationRepositoryImpl({
    required HttpClientFactory clientFactory,
  }) : _clientFactory = clientFactory;

  @override
  Future<Either<PaymentObservationFailure, PaymentObservationSession>>
      fetchSession({
    required String sessionId,
    required String systemId,
  }) async {
    try {
      final source = PaymentObservationRemoteDataSource(
        dio: _clientFactory.forSystem(systemId),
      );
      final session = await source.fetchSession(sessionId);
      return Right(session);
    } on PaymentObservationFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ReportSubmissionFailure(e.toString()));
    }
  }

  @override
  Future<Either<PaymentObservationFailure, void>> submitReport({
    required ObservationReport report,
    required String systemId,
  }) async {
    try {
      final source = PaymentObservationRemoteDataSource(
        dio: _clientFactory.forSystem(systemId),
      );
      await source.submitReport(report);
      return const Right(null);
    } on PaymentObservationFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ReportSubmissionFailure(e.toString()));
    }
  }
}
