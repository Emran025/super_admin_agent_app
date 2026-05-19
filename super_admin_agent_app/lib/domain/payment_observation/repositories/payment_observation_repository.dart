import 'package:dartz/dartz.dart';

import '../entities/payment_observation_session.dart';
import '../value_objects/observation_report.dart';

// ---------------------------------------------------------------------------
// Failures
// ---------------------------------------------------------------------------

abstract class PaymentObservationFailure {
  const PaymentObservationFailure();
}

class SessionNotFoundFailure extends PaymentObservationFailure {
  const SessionNotFoundFailure();
}

class SessionNotActiveFailure extends PaymentObservationFailure {
  const SessionNotActiveFailure();
}

class ReportSubmissionFailure extends PaymentObservationFailure {
  final String detail;
  const ReportSubmissionFailure(this.detail);
}

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

/// Repository contract for the payment observation capability.
abstract class PaymentObservationRepository {
  /// Fetches an observation session from [GET /v1/payment-sessions/{sessionId}].
  Future<Either<PaymentObservationFailure, PaymentObservationSession>>
      fetchSession({
    required String sessionId,
    required String systemId,
  });

  /// Submits an observation report to the server.
  ///
  /// Must be called even if the session has expired — Invariant 7.
  Future<Either<PaymentObservationFailure, void>> submitReport({
    required ObservationReport report,
    required String systemId,
  });
}
