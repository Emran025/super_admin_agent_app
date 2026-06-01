import '../entities/sms_conversation.dart';
import '../entities/sms_thread_message.dart';
import '../entities/user_message_delivery_status.dart';
import 'sms_conversation_repository.dart';

/// Result of a user-initiated send (not OTP gateway).
class UserSendResult {
  const UserSendResult({
    required this.messageId,
    required this.deliveryStatus,
  });

  final int messageId;
  final UserMessageDeliveryStatus deliveryStatus;
}

/// Full user SMS inbox operations (compensating UI only).
abstract class UserMessagingRepository {
  Future<({List<SmsConversation>? conversations, SmsInboxFailure? failure})>
      listConversations();

  Future<({List<SmsThreadMessage>? messages, SmsInboxFailure? failure})> getThreadMessages(
    int threadId,
  );

  Future<SmsInboxFailure?> markThreadAsRead(int threadId);

  Future<({UserSendResult? result, SmsInboxFailure? failure})> sendMessage({
    required String address,
    required String body,
  });

  Future<({UserSendResult? result, SmsInboxFailure? failure})> retryMessage(int messageId);

  Future<bool> deleteMessage(int messageId);
}
