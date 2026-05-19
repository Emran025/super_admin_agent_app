// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// Parsed output from an SMS body using a server-provided regex template.
///
/// Null fields indicate the corresponding named group was not matched.
/// The raw SMS body is consumed during parsing and does NOT appear in this
/// object — by design (Constraint 2.7 extension to SMS parsing).
class ParsedPaymentData {
  final String? payerName;
  final String? amount;
  final String? currency;

  const ParsedPaymentData({
    this.payerName,
    this.amount,
    this.currency,
  });

  /// True when all three fields were successfully parsed.
  bool get hasAllFields =>
      payerName != null && amount != null && currency != null;
}

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

/// Parses a raw SMS body using a server-provided regex template.
///
/// The template must use named groups: [payer], [amount], [currency].
/// Any parse failure (no match, malformed regex, thrown exception)
/// returns a [ParsedPaymentData] with all null fields — never throws.
abstract class SmsParsingService {
  /// Parse [rawSmsBody] using [parsingTemplate].
  ///
  /// - Returns [ParsedPaymentData] with all fields populated on success.
  /// - Returns [ParsedPaymentData] with all null fields on any failure.
  /// - Never throws — all exceptions are swallowed internally.
  ParsedPaymentData parse({
    required String rawSmsBody,
    required String parsingTemplate,
  });
}
