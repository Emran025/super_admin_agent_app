import 'package:flutter/material.dart';

import '../../../domain/user_messaging/entities/sms_thread_message.dart';
import '../../../domain/user_messaging/entities/user_message_delivery_status.dart';
import '../../shared/theme/radius_tokens.dart';
import '../../shared/theme/spacing_tokens.dart';
import '../utils/conversation_time_formatter.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onFailedTap,
  });

  final SmsThreadMessage message;
  final VoidCallback? onFailedTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOutgoing = message.isOutgoing;

    final bubbleColor = isOutgoing ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isOutgoing ? cs.onPrimary : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md, vertical: 4),
      child: Align(
        alignment: isOutgoing ? Alignment.centerLeft : Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Column(
            crossAxisAlignment:
                isOutgoing ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Material(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(RadiusTokens.lg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    message.body,
                    style: TextStyle(color: textColor, height: 1.35, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ConversationTimeFormatter.format(message.timestamp),
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                  if (isOutgoing) ...[
                    const SizedBox(width: 4),
                    _DeliveryIcon(status: message.deliveryStatus, color: cs.onSurfaceVariant),
                  ],
                ],
              ),
              if (message.isFailed) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: onFailedTap,
                  borderRadius: BorderRadius.circular(RadiusTokens.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 14, color: cs.error),
                        const SizedBox(width: 4),
                        Text(
                          'فشل الإرسال. اضغط للخيارات',
                          style: TextStyle(color: cs.error, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({required this.status, required this.color});

  final UserMessageDeliveryStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      UserMessageDeliveryStatus.pending => Icons.schedule,
      UserMessageDeliveryStatus.sent => Icons.done,
      UserMessageDeliveryStatus.failed => Icons.error_outline,
      UserMessageDeliveryStatus.received => Icons.done,
    };
    return Icon(icon, size: 12, color: color);
  }
}
