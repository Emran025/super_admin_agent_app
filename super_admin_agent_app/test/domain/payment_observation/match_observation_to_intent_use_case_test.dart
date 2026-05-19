import 'package:flutter_test/flutter_test.dart';

import 'package:super_admin_agent/domain/payment_observation/entities/bank_sms_observation.dart';
import 'package:super_admin_agent/domain/payment_observation/entities/payment_observation_session.dart';
import 'package:super_admin_agent/domain/payment_observation/entities/session_status.dart';
import 'package:super_admin_agent/domain/payment_observation/use_cases/match_observation_to_intent_use_case.dart';

void main() {
  late MatchObservationToIntentUseCase useCase;

  setUp(() {
    useCase = MatchObservationToIntentUseCase();
  });

  PaymentObservationSession _session({String? expectedPayerName}) => PaymentObservationSession(
        sessionId: 'sess-1',
        systemId: 'sys-1',
        intentId: 'intent-1',
        expectedSenderName: 'BANK',
        parsingTemplate: 'regex',
        expectedPayerName: expectedPayerName,
        expectedAmount: '100.00',
        expectedCurrency: 'USD',
        expiresAt: DateTime.now(),
        status: SessionStatus.active,
      );

  BankSmsObservation _observation(String? payer, String? amt, String? curr) => BankSmsObservation(
        observationId: 'obs-1',
        sessionId: 'sess-1',
        receivedAt: DateTime.now(),
        parsedPayerName: payer,
        parsedAmount: amt,
        parsedCurrency: curr,
      );

  test('all fields matching returns isMatch: true', () {
    final result = useCase.execute(
      observation: _observation('John', '100.00', 'usd'),
      session: _session(expectedPayerName: 'john'), // Case insensitive
    );

    expect(result.isMatch, isTrue);
  });

  test('mismatched amount returns isMatch: false', () {
    final result = useCase.execute(
      observation: _observation('John', '50.00', 'USD'),
      session: _session(expectedPayerName: 'John'),
    );

    expect(result.isMatch, isFalse);
  });

  test('any null parsed field returns isMatch: false', () {
    final result = useCase.execute(
      observation: _observation('John', null, 'USD'),
      session: _session(expectedPayerName: 'John'),
    );

    expect(result.isMatch, isFalse);
  });

  test('payer name match is skipped if session expectedPayerName is null', () {
    final result = useCase.execute(
      observation: _observation('Anyone', '100.00', 'USD'),
      session: _session(expectedPayerName: null),
    );

    expect(result.isMatch, isTrue);
  });
}
