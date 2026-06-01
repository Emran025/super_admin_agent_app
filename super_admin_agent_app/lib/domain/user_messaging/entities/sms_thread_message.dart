import 'package:equatable/equatable.dart';

import 'user_message_delivery_status.dart';

class SmsThreadMessage extends Equatable {
  const SmsThreadMessage({
    required this.messageId,
    required this.address,
    required this.body,
    required this.timestamp,
    required this.isOutgoing,
    required this.deliveryStatus,
  });

  final int messageId;
  final String address;
  final String body;
  final DateTime timestamp;
  final bool isOutgoing;
  final UserMessageDeliveryStatus deliveryStatus;

  bool get isFailed => isOutgoing && deliveryStatus == UserMessageDeliveryStatus.failed;
  bool get isPending => isOutgoing && deliveryStatus == UserMessageDeliveryStatus.pending;

  @override
  List<Object?> get props => [
        messageId,
        address,
        body,
        timestamp,
        isOutgoing,
        deliveryStatus,
      ];
}
