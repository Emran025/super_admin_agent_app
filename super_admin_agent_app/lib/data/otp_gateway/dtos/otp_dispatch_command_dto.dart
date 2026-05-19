import '../../../domain/otp_gateway/entities/dispatch_status.dart';
import '../../../domain/otp_gateway/entities/otp_dispatch_command.dart';

/// Maps the server JSON response from [GET /v1/otp-commands/{id}]
/// to an [OtpDispatchCommand].
class OtpDispatchCommandDto {
  final String commandId;
  final String systemId;
  final String recipientPhoneNumber;
  final String messageBody;
  final String issuedAt;
  final String simSlot;

  const OtpDispatchCommandDto({
    required this.commandId,
    required this.systemId,
    required this.recipientPhoneNumber,
    required this.messageBody,
    required this.issuedAt,
    required this.simSlot,
  });

  factory OtpDispatchCommandDto.fromJson(Map<String, dynamic> json) {
    return OtpDispatchCommandDto(
      commandId: json['command_id'] as String,
      systemId: json['system_id'] as String,
      recipientPhoneNumber: json['recipient_phone_number'] as String,
      messageBody: json['message_body'] as String,
      issuedAt: json['issued_at'] as String,
      simSlot: (json['sim_slot'] as String?) ?? 'defaultSlot',
    );
  }

  OtpDispatchCommand toEntity() {
    return OtpDispatchCommand(
      commandId: commandId,
      systemId: systemId,
      recipientPhoneNumber: recipientPhoneNumber,
      messageBody: messageBody,
      issuedAt: DateTime.parse(issuedAt).toUtc(),
      simSlot: _mapSimSlot(simSlot),
      status: DispatchStatus.pending,
    );
  }

  static SimSlot _mapSimSlot(String raw) => switch (raw.toLowerCase()) {
        'sim1' => SimSlot.sim1,
        'sim2' => SimSlot.sim2,
        _ => SimSlot.defaultSlot,
      };
}
