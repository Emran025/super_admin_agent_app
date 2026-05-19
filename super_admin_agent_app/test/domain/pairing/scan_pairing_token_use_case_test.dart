import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/pairing/entities/pairing_token.dart';
import 'package:super_admin_agent/domain/pairing/repositories/pairing_repository.dart';
import 'package:super_admin_agent/domain/pairing/use_cases/scan_pairing_token_use_case.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPairingRepository extends Mock implements PairingRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _validQr({DateTime? expiresAt}) => '''
{
  "version": "1",
  "system_id": "sys-001",
  "system_label": "Test Server",
  "pairing_endpoint": "https://server.example.com",
  "token": "one-time-token-xyz",
  "expires_at": "${(expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 1))).toIso8601String()}",
  "capabilities": ["two_fa", "otp_gateway"]
}
''';

PairingToken _mockToken() => PairingToken(
      version: '1',
      systemId: 'sys-001',
      systemLabel: 'Test Server',
      pairingEndpoint: 'https://server.example.com',
      token: 'one-time-token-xyz',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      capabilities: const ['two_fa', 'otp_gateway'],
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPairingRepository repository;
  late ScanPairingTokenUseCase useCase;

  setUp(() {
    repository = MockPairingRepository();
    useCase = ScanPairingTokenUseCase(repository: repository);
  });

  group('ScanPairingTokenUseCase', () {
    test('empty string returns Left(TokenInvalidFailure) without calling repo',
        () {
      final result = useCase.execute('');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<TokenInvalidFailure>()),
        (_) => fail('Expected Left'),
      );
      verifyNever(() => repository.parsePairingToken(any()));
    });

    test('whitespace-only string returns Left(TokenInvalidFailure) without calling repo',
        () {
      final result = useCase.execute('   ');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<TokenInvalidFailure>()),
        (_) => fail('Expected Left'),
      );
      verifyNever(() => repository.parsePairingToken(any()));
    });

    test('valid non-empty value delegates to repository and returns token', () {
      final token = _mockToken();
      when(() => repository.parsePairingToken(any()))
          .thenReturn(Right(token));

      final result = useCase.execute(_validQr());

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (t) {
          expect(t.systemId, equals('sys-001'));
          expect(t.systemLabel, equals('Test Server'));
        },
      );
      verify(() => repository.parsePairingToken(any())).called(1);
    });

    test('when repo returns TokenInvalidFailure, use case propagates it', () {
      when(() => repository.parsePairingToken(any()))
          .thenReturn(const Left(TokenInvalidFailure('Missing field')));

      final result = useCase.execute('{"incomplete": true}');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<TokenInvalidFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
