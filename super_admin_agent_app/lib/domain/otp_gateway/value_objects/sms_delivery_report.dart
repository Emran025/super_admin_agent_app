import 'package:equatable/equatable.dart';

enum SmsDeliveryStatus { sent, delivered, failedNoService, failedGeneric }

/// The signed delivery report sent back to the server.
///
/// Has NO [messageBody] field — OTP content must not leave the send path.
/// Has NO [recipientPhoneNumber] — not needed by the server for verification.
class SmsDeliveryReport extends Equatable {
  final String commandId;
  final SmsDeliveryStatus status;
  final DateTime reportedAt;
  final String nonce;
  final String signature;
  final String agentPublicKeyId;

  const SmsDeliveryReport({
    required this.commandId,
    required this.status,
    required this.reportedAt,
    required this.nonce,
    required this.signature,
    required this.agentPublicKeyId,
  });

  @override
  List<Object?> get props => [commandId, status, reportedAt, nonce];
}
