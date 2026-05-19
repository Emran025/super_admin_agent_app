import 'session_status.dart';

/// An active observation session opened by a server command.
///
/// The [parsingTemplate] is opaque — owned and versioned by the server.
/// The agent never validates, modifies, or caches the template beyond
/// the lifetime of this session.
class PaymentObservationSession {
  final String sessionId;
  final String systemId;
  final String intentId;
  final String expectedSenderName;
  final String parsingTemplate;
  final String? expectedPayerName;
  final String expectedAmount;
  final String expectedCurrency;
  final DateTime expiresAt;
  final SessionStatus status;

  const PaymentObservationSession({
    required this.sessionId,
    required this.systemId,
    required this.intentId,
    required this.expectedSenderName,
    required this.parsingTemplate,
    this.expectedPayerName,
    required this.expectedAmount,
    required this.expectedCurrency,
    required this.expiresAt,
    this.status = SessionStatus.active,
  });

  PaymentObservationSession copyWith({SessionStatus? status}) {
    return PaymentObservationSession(
      sessionId: sessionId,
      systemId: systemId,
      intentId: intentId,
      expectedSenderName: expectedSenderName,
      parsingTemplate: parsingTemplate,
      expectedPayerName: expectedPayerName,
      expectedAmount: expectedAmount,
      expectedCurrency: expectedCurrency,
      expiresAt: expiresAt,
      status: status ?? this.status,
    );
  }
}
