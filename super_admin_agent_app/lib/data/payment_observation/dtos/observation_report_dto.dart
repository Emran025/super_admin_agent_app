import '../../../domain/payment_observation/value_objects/observation_report.dart';

/// Serializes [ObservationReport] to the POST body for
/// [POST /v1/payment-sessions/{sessionId}/report].
///
/// The raw SMS body NEVER appears here — [ObservationReport] has no such field.
class ObservationReportDto {
  static Map<String, dynamic> toJson(ObservationReport report) {
    return {
      'session_id': report.sessionId,
      'intent_id': report.intentId,
      'observation_id': report.observationId,
      'is_match': report.isMatch,
      'parsed_payer_name': report.parsedPayerName,
      'parsed_amount': report.parsedAmount,
      'parsed_currency': report.parsedCurrency,
      'reported_at': report.reportedAt.toIso8601String(),
      'nonce': report.nonce,
      'agent_public_key_id': report.agentPublicKeyId,
      'signature': report.signature,
    };
  }
}
