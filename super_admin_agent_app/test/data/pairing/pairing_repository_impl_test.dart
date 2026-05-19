import 'package:flutter_test/flutter_test.dart';

import 'package:super_admin_agent/data/pairing/repositories/pairing_repository_impl.dart';
import 'package:super_admin_agent/domain/pairing/repositories/pairing_repository.dart';

import '../../helpers/fake_secure_storage.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _validJson({DateTime? expiresAt}) {
  final exp = (expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)))
      .toIso8601String();
  return '''
{
  "version": "1",
  "system_id": "sys-abc",
  "system_label": "Alpha Server",
  "pairing_endpoint": "https://alpha.example.com",
  "token": "tok-123",
  "expires_at": "$exp",
  "capabilities": ["two_fa"]
}
''';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late PairingRepositoryImpl repository;

  setUp(() {
    repository = PairingRepositoryImpl(
      secureStorage: FakeSecureStorage(),
    );
  });

  group('PairingRepositoryImpl.parsePairingToken', () {
    test('valid JSON with all fields returns Right(PairingToken)', () {
      final result = repository.parsePairingToken(_validJson());

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (token) {
          expect(token.systemId, equals('sys-abc'));
          expect(token.systemLabel, equals('Alpha Server'));
          expect(token.pairingEndpoint, equals('https://alpha.example.com'));
          expect(token.capabilities, contains('two_fa'));
          expect(token.isExpired, isFalse);
        },
      );
    });

    test('JSON with past expires_at returns Left(TokenExpiredFailure)', () {
      final expired = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final result = repository.parsePairingToken(_validJson(expiresAt: expired));

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<TokenExpiredFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('malformed JSON returns Left(TokenInvalidFailure)', () {
      final result = repository.parsePairingToken('not valid json }{');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<TokenInvalidFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('JSON missing system_id returns Left(TokenInvalidFailure)', () {
      const json = '''
{
  "version": "1",
  "system_label": "Alpha Server",
  "pairing_endpoint": "https://alpha.example.com",
  "token": "tok-123",
  "expires_at": "2099-01-01T00:00:00Z",
  "capabilities": []
}
''';
      final result = repository.parsePairingToken(json);

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<TokenInvalidFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
