/// A parsed observation from a bank SMS.
///
/// Contains ONLY parsed fields — never the raw SMS body (Constraint 2.1).
/// No [rawBody] field. No [senderName] field. Only purpose-specific data.
class BankSmsObservation {
  final String observationId;
  final String sessionId;
  final DateTime receivedAt;
  final String? parsedPayerName;
  final String? parsedAmount;
  final String? parsedCurrency;

  const BankSmsObservation({
    required this.observationId,
    required this.sessionId,
    required this.receivedAt,
    this.parsedPayerName,
    this.parsedAmount,
    this.parsedCurrency,
  });

  /// True when all three parsed fields are non-null.
  bool get hasAllFields =>
      parsedPayerName != null &&
      parsedAmount != null &&
      parsedCurrency != null;
}
