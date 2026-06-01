import '../repositories/sms_conversation_repository.dart';
import '../repositories/user_messaging_repository.dart';

class MarkThreadReadUseCase {
  const MarkThreadReadUseCase({required UserMessagingRepository repository})
      : _repository = repository;

  final UserMessagingRepository _repository;

  Future<SmsInboxFailure?> execute(int threadId) => _repository.markThreadAsRead(threadId);
}
