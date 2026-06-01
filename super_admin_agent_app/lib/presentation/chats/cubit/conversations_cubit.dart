import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/user_messaging/entities/sms_conversation.dart';
import '../../../domain/user_messaging/repositories/sms_conversation_repository.dart';
import '../../../domain/user_messaging/use_cases/list_sms_conversations_use_case.dart';
import '../../../shared/infrastructure/default_sms_app_service.dart';
import '../../../shared/infrastructure/telephony_sms_inbox_service.dart';
import 'conversations_state.dart';

class ConversationsCubit extends Cubit<ConversationsState> {
  ConversationsCubit({
    required ListSmsConversationsUseCase listUseCase,
    DefaultSmsAppService defaultSmsAppService = const DefaultSmsAppService(),
    TelephonySmsInboxService inboxService = const TelephonySmsInboxService(),
  })  : _listUseCase = listUseCase,
        _defaultSmsAppService = defaultSmsAppService,
        _inboxService = inboxService,
        super(const ConversationsInitial());

  final ListSmsConversationsUseCase _listUseCase;
  final DefaultSmsAppService _defaultSmsAppService;
  final TelephonySmsInboxService _inboxService;

  List<SmsConversation> _lastConversations = [];
  bool _isDefaultSmsApp = false;
  String _searchQuery = '';
  StreamSubscription<void>? _inboxSubscription;

  void startWatching() {
    _inboxSubscription?.cancel();
    _inboxSubscription = _inboxService.onInboxChanged.listen((_) => load());
  }

  Future<void> load() async {
    emit(ConversationsLoading(isDefaultSmsApp: _isDefaultSmsApp));
    try {
      _isDefaultSmsApp = await _defaultSmsAppService.isDefaultSmsApp();
    } catch (_) {
      _isDefaultSmsApp = false;
    }
    emit(ConversationsLoading(isDefaultSmsApp: _isDefaultSmsApp));

    final result = await _listUseCase.execute();
    if (result.failure != null) {
      switch (result.failure!) {
        case SmsInboxPermissionDenied():
          emit(ConversationsPermissionDenied(isDefaultSmsApp: _isDefaultSmsApp));
        case SmsInboxQueryFailed(:final message):
          emit(ConversationsError(message: message, isDefaultSmsApp: _isDefaultSmsApp));
      }
      return;
    }

    _lastConversations = result.conversations ?? [];
    emit(
      ConversationsLoaded(
        conversations: _lastConversations,
        isDefaultSmsApp: _isDefaultSmsApp,
        searchQuery: _searchQuery,
      ),
    );
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    final current = state;
    if (current is ConversationsLoaded) {
      emit(
        ConversationsLoaded(
          conversations: _lastConversations,
          isDefaultSmsApp: _isDefaultSmsApp,
          searchQuery: query,
        ),
      );
    }
  }

  Future<void> refreshDefaultSmsStatus() async {
    try {
      _isDefaultSmsApp = await _defaultSmsAppService.isDefaultSmsApp();
    } catch (_) {
      _isDefaultSmsApp = false;
    }
    final current = state;
    if (current is ConversationsLoaded) {
      emit(
        ConversationsLoaded(
          conversations: _lastConversations,
          isDefaultSmsApp: _isDefaultSmsApp,
          searchQuery: _searchQuery,
        ),
      );
    } else if (current is ConversationsPermissionDenied) {
      emit(ConversationsPermissionDenied(isDefaultSmsApp: _isDefaultSmsApp));
    } else if (current is ConversationsError) {
      emit(ConversationsError(message: current.message, isDefaultSmsApp: _isDefaultSmsApp));
    } else if (current is ConversationsLoading) {
      emit(ConversationsLoading(isDefaultSmsApp: _isDefaultSmsApp));
    }
  }

  @override
  Future<void> close() {
    _inboxSubscription?.cancel();
    return super.close();
  }
}
