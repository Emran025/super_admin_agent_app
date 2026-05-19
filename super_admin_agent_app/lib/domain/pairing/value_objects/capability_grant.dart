/// Capability string constants granted to this agent by a paired server system.
///
/// Capabilities are [String] — not an enum — because new capability IDs may be
/// added by the server without a client code change (Constraint 2.6).
///
/// Unknown capability strings received from the server are silently ignored.
abstract class Capability {
  /// Push-based two-factor authentication approval.
  static const String twoFa = 'two_fa';

  /// SMS OTP gateway dispatching.
  static const String otpGateway = 'otp_gateway';

  /// Inbound SMS payment observation and reporting.
  static const String paymentObservation = 'payment_observation';

  static const Set<String> _known = {twoFa, otpGateway, paymentObservation};

  /// Returns true when [value] is a known capability in this client version.
  /// Unknown values from the server are not failures — they are silently skipped.
  static bool isKnown(String value) => _known.contains(value);
}
