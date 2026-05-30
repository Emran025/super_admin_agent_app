import 'package:equatable/equatable.dart';
import 'dispatch_status.dart';

enum SimSlot { defaultSlot, sim1, sim2 }

class OtpDispatchCommand extends Equatable {
  final String commandId;
  final String systemId;
  final String recipientPhoneNumber;

  /// Write-only. Pass to SmsSenderService immediately.
  /// Do not store, log, or reference after send() returns. (Invariant 1)
  final String messageBody;

  final DateTime issuedAt;
  final SimSlot simSlot;
  final DispatchStatus status;
  
  final String customerName;
  final String systemName;
  const OtpDispatchCommand({
    required this.commandId,
    required this.systemId,
    required this.recipientPhoneNumber,
    required this.messageBody,
    required this.issuedAt,
    this.simSlot = SimSlot.defaultSlot,
    this.status = DispatchStatus.pending,
    this.customerName = 'Customer',
    this.systemName = 'SuperAdmin',
  }) : assert(messageBody != '', 'messageBody must not be empty (SC-8)');

  OtpDispatchCommand copyWith({
    DispatchStatus? status,
    String? messageBody,
    String? customerName,
    String? systemName,
  }) => OtpDispatchCommand(
        commandId: commandId,
        systemId: systemId,
        recipientPhoneNumber: recipientPhoneNumber,
        messageBody: messageBody ?? this.messageBody,
        issuedAt: issuedAt,
        simSlot: simSlot,
        status: status ?? this.status,
        customerName: customerName ?? this.customerName,
        systemName: systemName ?? this.systemName,
      );

  @override
  List<Object?> get props => [commandId, systemId, status, customerName, systemName];
}
