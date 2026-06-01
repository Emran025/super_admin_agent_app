import '../entities/sms_thread_message.dart';
import '../repositories/sms_conversation_repository.dart';
import '../repositories/user_messaging_repository.dart';

class GetThreadMessagesUseCase {
  const GetThreadMessagesUseCase({required UserMessagingRepository repository})
      : _repository = repository;

  final UserMessagingRepository _repository;

  Future<({List<SmsThreadMessage>? messages, SmsInboxFailure? failure})> execute(
    int threadId,
  ) {
    return _repository.getThreadMessages(threadId);
  }
}
