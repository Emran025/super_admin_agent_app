/// The signed observation report submitted to the server.
///
/// INVARIANT: The field expressing match status is named [isMatch] ONLY.
/// Names such as [isConfirmed], [isApproved], [isVerified], or [isPaid]
/// are FORBIDDEN — they imply decision authority the agent does not have (CF-04).
///
/// [isMatch] is advisory: "the extracted values matched the expected values."
/// The server applies its own business rules before confirming the payment.
class ObservationReport {
  final String sessionId;
  final String intentId;
  final String observationId;

  /// Advisory: true means extracted values matched expected values.
  /// This is NOT a payment confirmation — the server decides that.
  final bool isMatch;

  final String? parsedPayerName;
  final String? parsedAmount;
  final String? parsedCurrency;
  final DateTime reportedAt;
  final String nonce;
  final String signature;
  final String agentPublicKeyId;

  const ObservationReport({
    required this.sessionId,
    required this.intentId,
    required this.observationId,
    required this.isMatch,
    this.parsedPayerName,
    this.parsedAmount,
    this.parsedCurrency,
    required this.reportedAt,
    required this.nonce,
    required this.signature,
    required this.agentPublicKeyId,
  });
}
