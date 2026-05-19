import '../entities/bank_sms_observation.dart';
import '../entities/payment_observation_session.dart';

/// The result of matching an observation against the session's expected values.
///
/// [isMatch] is advisory — the server makes the final payment decision.
/// Field must never be named [isConfirmed], [isApproved], or [isPaid] (CF-04).
class ObservationMatchResult {
  /// True when all parsed fields match the session's expected values.
  /// Advisory only — NOT a payment confirmation.
  final bool isMatch;
  final BankSmsObservation observation;

  const ObservationMatchResult({
    required this.isMatch,
    required this.observation,
  });
}

/// Evaluates whether a parsed observation matches the session's intent.
///
/// All three conditions must be true for [isMatch: true]:
/// - [parsedAmount] == [expectedAmount]
/// - [parsedCurrency] (uppercased) == [expectedCurrency] (uppercased)
/// - [parsedPayerName] (lowercased) == [expectedPayerName] (lowercased), if non-null
///
/// Any null parsed field → [isMatch: false].
class MatchObservationToIntentUseCase {
  const MatchObservationToIntentUseCase();

  ObservationMatchResult execute({
    required BankSmsObservation observation,
    required PaymentObservationSession session,
  }) {
    if (!observation.hasAllFields) {
      return ObservationMatchResult(isMatch: false, observation: observation);
    }

    final amountMatches = observation.parsedAmount == session.expectedAmount;

    final currencyMatches =
        observation.parsedCurrency!.toUpperCase() ==
        session.expectedCurrency.toUpperCase();

    final payerMatches = session.expectedPayerName == null ||
        observation.parsedPayerName!.toLowerCase() ==
            session.expectedPayerName!.toLowerCase();

    final isMatch = amountMatches && currencyMatches && payerMatches;

    return ObservationMatchResult(isMatch: isMatch, observation: observation);
  }
}
