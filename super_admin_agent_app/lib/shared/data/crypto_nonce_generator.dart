import 'dart:convert';
import 'dart:math';
import '../domain/nonce_generator.dart';

/// Generates 256-bit cryptographically secure nonces.
///
/// Invariants verified by unit tests:
/// - Output is exactly 43 characters long
/// - No `+`, `/`, or `=` characters (URL-safe, no padding)
/// - 100 consecutive calls produce 100 distinct values
class CryptoNonceGenerator implements NonceGenerator {
  const CryptoNonceGenerator();

  @override
  String generate() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    // base64Url encodes 32 bytes to 44 chars including trailing '=' padding.
    // Remove the padding to produce a clean 43-char token.
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
