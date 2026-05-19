import '../domain/sms_parsing_service.dart';

/// Regex-based implementation of [SmsParsingService].
///
/// The server provides a [parsingTemplate] — a Dart regex pattern that must
/// contain named groups: [payer], [amount], [currency].
///
/// Invariants:
/// - Never throws. All exceptions produce a [ParsedPaymentData] with all null fields.
/// - The raw [rawSmsBody] does not appear in the returned value — it is consumed.
/// - A malformed [parsingTemplate] (invalid regex) returns null fields, not an exception.
class RegexSmsParsingService implements SmsParsingService {
  const RegexSmsParsingService();

  @override
  ParsedPaymentData parse({
    required String rawSmsBody,
    required String parsingTemplate,
  }) {
    try {
      final regex = RegExp(parsingTemplate);
      final match = regex.firstMatch(rawSmsBody);

      if (match == null) {
        return const ParsedPaymentData();
      }

      return ParsedPaymentData(
        payerName: _safeGroup(match, 'payer'),
        amount: _safeGroup(match, 'amount'),
        currency: _safeGroup(match, 'currency'),
      );
    } catch (_) {
      // Malformed regex or any other exception: return null fields silently.
      return const ParsedPaymentData();
    }
  }

  String? _safeGroup(RegExpMatch match, String name) {
    try {
      return match.namedGroup(name);
    } catch (_) {
      return null;
    }
  }
}
