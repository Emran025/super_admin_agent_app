import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/payment_observation/entities/payment_observation_session.dart';
import 'package:super_admin_agent/domain/payment_observation/entities/session_status.dart';
import 'package:super_admin_agent/domain/payment_observation/use_cases/process_incoming_sms_use_case.dart';
import 'package:super_admin_agent/shared/domain/sms_parsing_service.dart';

class MockSmsParsingService extends Mock implements SmsParsingService {}

void main() {
  late MockSmsParsingService parsingService;
  late ProcessIncomingSmsUseCase useCase;

  setUp(() {
    parsingService = MockSmsParsingService();
    useCase = ProcessIncomingSmsUseCase(
      parsingService: parsingService,
      generateId: () => 'obs-1',
    );
  });

  PaymentObservationSession createSession(SessionStatus status) => PaymentObservationSession(
        sessionId: 'sess-1',
        systemId: 'sys-1',
        intentId: 'intent-1',
        expectedSenderName: 'BANK',
        parsingTemplate: 'regex',
        expectedAmount: '100.00',
        expectedCurrency: 'USD',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        status: status,
      );

  test('SMS from wrong sender returns null without parsing', () {
    final result = useCase.execute(
      event: RawSmsEvent(senderName: 'OTHER', body: 'Payment', receivedAt: DateTime.now()),
      session: createSession(SessionStatus.active),
    );

    expect(result, isNull);
    verifyNever(() => parsingService.parse(
          rawSmsBody: any(named: 'rawSmsBody'),
          parsingTemplate: any(named: 'parsingTemplate'),
        ));
  });

  test('SMS when session is not active returns null without parsing', () {
    final result = useCase.execute(
      event: RawSmsEvent(senderName: 'BANK', body: 'Payment', receivedAt: DateTime.now()),
      session: createSession(SessionStatus.expired),
    );

    expect(result, isNull);
    verifyNever(() => parsingService.parse(
          rawSmsBody: any(named: 'rawSmsBody'),
          parsingTemplate: any(named: 'parsingTemplate'),
        ));
  });

  test('valid SMS is parsed and returns BankSmsObservation', () {
    when(() => parsingService.parse(
          rawSmsBody: any(named: 'rawSmsBody'),
          parsingTemplate: any(named: 'parsingTemplate'),
        )).thenReturn(const ParsedPaymentData(
      payerName: 'John',
      amount: '100.00',
      currency: 'USD',
    ));

    final result = useCase.execute(
      event: RawSmsEvent(senderName: 'bank', body: 'Payment from John 100.00 USD', receivedAt: DateTime.now()),
      session: createSession(SessionStatus.active),
    );

    expect(result, isNotNull);
    expect(result!.parsedPayerName, 'John');
    expect(result.parsedAmount, '100.00');
    expect(result.parsedCurrency, 'USD');

    // Confirm raw body is passed exactly to the parser
    verify(() => parsingService.parse(
          rawSmsBody: 'Payment from John 100.00 USD',
          parsingTemplate: 'regex',
        )).called(1);
  });

  test('failed parse returns BankSmsObservation with null fields (Invariant 6)', () {
    when(() => parsingService.parse(
          rawSmsBody: any(named: 'rawSmsBody'),
          parsingTemplate: any(named: 'parsingTemplate'),
        )).thenReturn(const ParsedPaymentData(
      payerName: null,
      amount: null,
      currency: null,
    ));

    final result = useCase.execute(
      event: RawSmsEvent(senderName: 'bank', body: 'Unrelated message', receivedAt: DateTime.now()),
      session: createSession(SessionStatus.active),
    );

    expect(result, isNotNull);
    expect(result!.parsedPayerName, isNull);
    expect(result.parsedAmount, isNull);
    expect(result.parsedCurrency, isNull);
  });
}
