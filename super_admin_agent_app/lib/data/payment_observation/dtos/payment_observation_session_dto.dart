import '../../../domain/payment_observation/entities/payment_observation_session.dart';
import '../../../domain/payment_observation/entities/session_status.dart';

/// Maps [GET /v1/payment-sessions/{id}] JSON response to
/// [PaymentObservationSession].
class PaymentObservationSessionDto {
  final String sessionId;
  final String systemId;
  final String intentId;
  final String expectedSenderName;
  final String parsingTemplate;
  final String? expectedPayerName;
  final String expectedAmount;
  final String expectedCurrency;
  final String expiresAt;
  final String status;

  const PaymentObservationSessionDto({
    required this.sessionId,
    required this.systemId,
    required this.intentId,
    required this.expectedSenderName,
    required this.parsingTemplate,
    this.expectedPayerName,
    required this.expectedAmount,
    required this.expectedCurrency,
    required this.expiresAt,
    required this.status,
  });

  factory PaymentObservationSessionDto.fromJson(Map<String, dynamic> json) {
    return PaymentObservationSessionDto(
      sessionId: json['session_id'] as String,
      systemId: json['system_id'] as String,
      intentId: json['intent_id'] as String,
      expectedSenderName: json['expected_sender_name'] as String,
      parsingTemplate: json['parsing_template'] as String,
      expectedPayerName: json['expected_payer_name'] as String?,
      expectedAmount: json['expected_amount'] as String,
      expectedCurrency: json['expected_currency'] as String,
      expiresAt: json['expires_at'] as String,
      status: (json['status'] as String?) ?? 'ACTIVE',
    );
  }

  PaymentObservationSession toEntity() {
    return PaymentObservationSession(
      sessionId: sessionId,
      systemId: systemId,
      intentId: intentId,
      expectedSenderName: expectedSenderName,
      parsingTemplate: parsingTemplate,
      expectedPayerName: expectedPayerName,
      expectedAmount: expectedAmount,
      expectedCurrency: expectedCurrency,
      expiresAt: DateTime.parse(expiresAt).toUtc(),
      status: _mapStatus(status),
    );
  }

  static SessionStatus _mapStatus(String raw) => switch (raw.toUpperCase()) {
        'MATCHED' => SessionStatus.matched,
        'EXPIRED' => SessionStatus.expired,
        'REPORTED' => SessionStatus.reported,
        _ => SessionStatus.active,
      };
}
