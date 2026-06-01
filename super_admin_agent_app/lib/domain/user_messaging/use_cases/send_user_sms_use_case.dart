import '../repositories/sms_conversation_repository.dart';
import '../repositories/user_messaging_repository.dart';

class SendUserSmsUseCase {
  const SendUserSmsUseCase({required UserMessagingRepository repository})
      : _repository = repository;

  final UserMessagingRepository _repository;

  Future<({UserSendResult? result, SmsInboxFailure? failure})> execute({
    required String address,
    required String body,
  }) {
    return _repository.sendMessage(address: address.trim(), body: body);
  }
}
