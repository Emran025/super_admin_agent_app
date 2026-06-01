import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/user_messaging/entities/sms_conversation.dart';
import '../../../domain/user_messaging/entities/user_message_delivery_status.dart';
import '../../../domain/user_messaging/repositories/sms_conversation_repository.dart';
import '../../../domain/user_messaging/use_cases/get_thread_messages_use_case.dart';
import '../../../domain/user_messaging/use_cases/mark_thread_read_use_case.dart';
import '../../../domain/user_messaging/use_cases/retry_user_sms_use_case.dart';
import '../../../domain/user_messaging/use_cases/send_user_sms_use_case.dart';
import '../../../shared/infrastructure/default_sms_app_service.dart';
import '../../../shared/infrastructure/telephony_sms_inbox_service.dart';
import 'thread_state.dart';

class ThreadCubit extends Cubit<ThreadState> {
  ThreadCubit({
    required conversation,
    required GetThreadMessagesUseCase getMessagesUseCase,
    required SendUserSmsUseCase sendUseCase,
    required RetryUserSmsUseCase retryUseCase,
    required MarkThreadReadUseCase markReadUseCase,
    DefaultSmsAppService defaultSmsAppService = const DefaultSmsAppService(),
    TelephonySmsInboxService inboxService = const TelephonySmsInboxService(),
  })  : _conversation = conversation,
        _getMessagesUseCase = getMessagesUseCase,
        _sendUseCase = sendUseCase,
        _retryUseCase = retryUseCase,
        _markReadUseCase = markReadUseCase,
        _defaultSmsAppService = defaultSmsAppService,
        _inboxService = inboxService,
        super(const ThreadInitial());

  final SmsConversation _conversation;
  final GetThreadMessagesUseCase _getMessagesUseCase;
  final SendUserSmsUseCase _sendUseCase;
  final RetryUserSmsUseCase _retryUseCase;
  final MarkThreadReadUseCase _markReadUseCase;
  final DefaultSmsAppService _defaultSmsAppService;
  final TelephonySmsInboxService _inboxService;

  StreamSubscription<void>? _inboxSubscription;
  bool _isDefaultSmsApp = false;

  SmsConversation get conversation => _conversation;

  void startWatching() {
    _inboxSubscription?.cancel();
    _inboxSubscription = _inboxService.onInboxChanged.listen((_) => load());
  }

  Future<void> load() async {
    final prevSending = state is ThreadLoaded ? (state as ThreadLoaded).isSending : false;
    emit(ThreadLoading(isDefaultSmsApp: _isDefaultSmsApp));
    try {
      _isDefaultSmsApp = await _defaultSmsAppService.isDefaultSmsApp();
    } catch (_) {
      _isDefaultSmsApp = false;
    }

    await _markReadUseCase.execute(_conversation.threadId);

    final result = await _getMessagesUseCase.execute(_conversation.threadId);
    if (result.failure != null) {
      final msg = switch (result.failure!) {
        SmsInboxPermissionDenied() => 'إذن قراءة الرسائل مطلوب',
        SmsInboxQueryFailed(:final message) => message,
      };
      emit(ThreadError(isDefaultSmsApp: _isDefaultSmsApp, message: msg));
      return;
    }

    emit(
      ThreadLoaded(
        isDefaultSmsApp: _isDefaultSmsApp,
        messages: result.messages ?? [],
        isSending: prevSending,
      ),
    );
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final current = state;
    if (current is ThreadLoaded) {
      emit(ThreadLoaded(
        isDefaultSmsApp: current.isDefaultSmsApp,
        messages: current.messages,
        isSending: true,
      ));
    }

    final result = await _sendUseCase.execute(
      address: _conversation.address,
      body: trimmed,
    );

    await load();
    final after = state;
    if (after is ThreadLoaded) {
      emit(ThreadLoaded(
        isDefaultSmsApp: after.isDefaultSmsApp,
        messages: after.messages,
        isSending: false,
      ));
    }

    if (result.failure != null || result.result?.deliveryStatus == UserMessageDeliveryStatus.failed) {
      // UI shows failed row from Telephony refresh
    }
  }

  Future<bool> retryMessage(int messageId) async {
    final result = await _retryUseCase.execute(messageId);
    await load();
    return result.result?.deliveryStatus == UserMessageDeliveryStatus.sent;
  }

  Future<void> refreshDefaultSmsStatus() async {
    try {
      _isDefaultSmsApp = await _defaultSmsAppService.isDefaultSmsApp();
    } catch (_) {
      _isDefaultSmsApp = false;
    }
    final current = state;
    if (current is ThreadLoaded) {
      emit(ThreadLoaded(
        isDefaultSmsApp: _isDefaultSmsApp,
        messages: current.messages,
        isSending: current.isSending,
      ));
    } else if (current is ThreadError) {
      emit(ThreadError(isDefaultSmsApp: _isDefaultSmsApp, message: current.message));
    }
  }

  @override
  Future<void> close() {
    _inboxSubscription?.cancel();
    return super.close();
  }
}
