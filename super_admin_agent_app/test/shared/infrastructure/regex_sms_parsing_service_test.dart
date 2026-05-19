import 'package:flutter_test/flutter_test.dart';
import 'package:super_admin_agent/shared/infrastructure/regex_sms_parsing_service.dart';

void main() {
  const service = RegexSmsParsingService();

  group('RegexSmsParsingService', () {
    const validTemplate =
        r'(?<payer>[\w\s]+) sent (?<amount>[\d.]+) (?<currency>[A-Z]+)';

    test('valid SMS body matching the template returns all three fields', () {
      const sms = 'John Doe sent 100.50 USD';
      final result = service.parse(
        rawSmsBody: sms,
        parsingTemplate: validTemplate,
      );

      expect(result.payerName, equals('John Doe'));
      expect(result.amount, equals('100.50'));
      expect(result.currency, equals('USD'));
      expect(result.hasAllFields, isTrue);
    });

    test('SMS body that does not match returns all null fields', () {
      const sms = 'This message does not match anything';
      final result = service.parse(
        rawSmsBody: sms,
        parsingTemplate: validTemplate,
      );

      expect(result.payerName, isNull);
      expect(result.amount, isNull);
      expect(result.currency, isNull);
      expect(result.hasAllFields, isFalse);
    });

    test('malformed regex returns all null fields (does not throw)', () {
      const sms = 'John Doe sent 100.50 USD';
      const badTemplate = r'(?<payer>[invalid regex (((';

      expect(
        () => service.parse(rawSmsBody: sms, parsingTemplate: badTemplate),
        returnsNormally,
      );

      final result = service.parse(
        rawSmsBody: sms,
        parsingTemplate: badTemplate,
      );

      expect(result.payerName, isNull);
      expect(result.amount, isNull);
      expect(result.currency, isNull);
    });

    test('raw SMS body is not stored wholesale in ParsedPaymentData fields', () {
      const sms = 'Alice sent 200.00 EUR and extra garbage content that should not appear';
      final result = service.parse(
        rawSmsBody: sms,
        parsingTemplate: validTemplate,
      );

      // The full raw body must not appear verbatim in any returned field.
      expect(result.payerName, isNot(equals(sms)));
      expect(result.amount, isNot(equals(sms)));
      expect(result.currency, isNot(equals(sms)));

      // Parsed fields are extracted substrings, not the raw body.
      expect(result.payerName, equals('Alice'));
      expect(result.amount, equals('200.00'));
      expect(result.currency, equals('EUR'));
    });
  });
}
