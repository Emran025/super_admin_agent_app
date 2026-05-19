/// Generates cryptographically secure nonces for request signing.
///
/// Specification:
/// - 256-bit (32 bytes) of entropy
/// - Encoded as base64url (RFC 4648 §5)
/// - No padding characters (`=`)
/// - Source: [Random.secure()] only — never [Random()]
/// - Each call produces a fresh value; nonces are never cached or reused
///
/// Violation of any of these rules makes replay protection meaningless.
abstract class NonceGenerator {
  /// Returns a new 43-character base64url nonce.
  ///
  /// 32 bytes → 256 bits of entropy.
  /// base64url(32 bytes) = ceil(32 * 4/3) = 43 characters (no padding).
  String generate();
}
