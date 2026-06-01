import '../entities/sms_conversation.dart';

/// Failure modes when reading the Telephony inbox.
sealed class SmsInboxFailure {
  const SmsInboxFailure();
}

class SmsInboxPermissionDenied extends SmsInboxFailure {
  const SmsInboxPermissionDenied();
}

class SmsInboxQueryFailed extends SmsInboxFailure {
  const SmsInboxQueryFailed(this.message);
  final String message;
}

/// Reads user SMS threads from the platform store.
///
/// Implementations must not be used by OTP gateway or payment observation.
abstract class SmsConversationRepository {
  Future<({List<SmsConversation>? conversations, SmsInboxFailure? failure})>
      listConversations();
}
