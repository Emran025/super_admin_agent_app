import '../entities/sms_conversation.dart';
import '../repositories/sms_conversation_repository.dart';
import '../repositories/user_messaging_repository.dart';

class ListSmsConversationsUseCase {
  const ListSmsConversationsUseCase({required UserMessagingRepository repository})
      : _repository = repository;

  final UserMessagingRepository _repository;

  Future<({List<SmsConversation>? conversations, SmsInboxFailure? failure})> execute() {
    return _repository.listConversations();
  }
}
