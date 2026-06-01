import '../repositories/sms_conversation_repository.dart';
import '../repositories/user_messaging_repository.dart';

class RetryUserSmsUseCase {
  const RetryUserSmsUseCase({required UserMessagingRepository repository})
      : _repository = repository;

  final UserMessagingRepository _repository;

  Future<({UserSendResult? result, SmsInboxFailure? failure})> execute(int messageId) {
    return _repository.retryMessage(messageId);
  }
}
