import 'package:flutter_test/flutter_test.dart';
import 'package:super_admin_agent/shared/data/crypto_nonce_generator.dart';

void main() {
  const generator = CryptoNonceGenerator();

  group('CryptoNonceGenerator', () {
    test('each nonce is exactly 43 characters long', () {
      for (int i = 0; i < 20; i++) {
        final nonce = generator.generate();
        expect(nonce.length, equals(43),
            reason: 'base64url(32 bytes) without padding must be 43 chars');
      }
    });

    test('nonce contains no +, /, or = characters (URL-safe, no padding)', () {
      for (int i = 0; i < 50; i++) {
        final nonce = generator.generate();
        expect(nonce.contains('+'), isFalse, reason: 'must be base64url, not base64');
        expect(nonce.contains('/'), isFalse, reason: 'must be base64url, not base64');
        expect(nonce.contains('='), isFalse, reason: 'padding must be stripped');
      }
    });

    test('100 consecutive calls produce 100 distinct values', () {
      final nonces = <String>{};
      for (int i = 0; i < 100; i++) {
        nonces.add(generator.generate());
      }
      expect(nonces.length, equals(100), reason: 'nonces must never be reused');
    });
  });
}
