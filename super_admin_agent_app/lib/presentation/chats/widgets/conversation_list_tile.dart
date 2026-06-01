import 'package:flutter/material.dart';

import '../../../domain/user_messaging/entities/sms_conversation.dart';
import '../../shared/theme/radius_tokens.dart';
import '../../shared/theme/spacing_tokens.dart';
import '../utils/avatar_color.dart';
import '../utils/conversation_time_formatter.dart';

class ConversationListTile extends StatelessWidget {
  const ConversationListTile({
    super.key,
    required this.conversation,
    this.onTap,
  });

  final SmsConversation conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final avatarColor = avatarColorForKey(conversation.address);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.xs,
      ),
      leading: CircleAvatar(
        backgroundColor: avatarColor.withValues(alpha: 0.25),
        child: Text(
          conversation.avatarInitial,
          style: TextStyle(
            color: avatarColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      title: Text(
        conversation.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.titleMedium?.copyWith(
          fontWeight: conversation.hasUnread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        conversation.snippet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            ConversationTimeFormatter.format(conversation.timestamp),
            style: tt.labelSmall?.copyWith(
              color: conversation.hasUnread ? cs.primary : cs.onSurfaceVariant,
              fontWeight: conversation.hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (conversation.hasUnread) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(RadiusTokens.pill),
              ),
              child: Text(
                conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
