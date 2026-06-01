import 'package:flutter_test/flutter_test.dart';
import 'package:super_admin_agent/domain/user_messaging/entities/sms_conversation.dart';

void main() {
  test('avatarInitial uses first rune for Arabic names', () {
    final c = SmsConversation(
      threadId: 1,
      address: '+966500000000',
      displayName: 'أحمد',
      snippet: 'test',
      timestamp: DateTime.utc(2024, 1, 1),
      unreadCount: 0,
      isRead: true,
    );
    expect(c.avatarInitial, 'أ');
    expect(c.hasUnread, isFalse);
  });
}
