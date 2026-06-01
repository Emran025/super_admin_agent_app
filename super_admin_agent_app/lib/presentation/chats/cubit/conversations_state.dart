import 'package:equatable/equatable.dart';

import '../../../domain/user_messaging/entities/sms_conversation.dart';

sealed class ConversationsState extends Equatable {
  const ConversationsState();

  @override
  List<Object?> get props => [];
}

class ConversationsInitial extends ConversationsState {
  const ConversationsInitial({this.isDefaultSmsApp = false});
  final bool isDefaultSmsApp;

  @override
  List<Object?> get props => [isDefaultSmsApp];
}

class ConversationsLoading extends ConversationsState {
  const ConversationsLoading({this.isDefaultSmsApp = false});
  final bool isDefaultSmsApp;

  @override
  List<Object?> get props => [isDefaultSmsApp];
}

class ConversationsLoaded extends ConversationsState {
  const ConversationsLoaded({
    required this.conversations,
    required this.isDefaultSmsApp,
    this.searchQuery = '',
  });

  final List<SmsConversation> conversations;
  final bool isDefaultSmsApp;
  final String searchQuery;

  List<SmsConversation> get filtered {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return conversations;
    return conversations.where((c) {
      return c.displayName.toLowerCase().contains(q) ||
          c.address.contains(q) ||
          c.snippet.toLowerCase().contains(q);
    }).toList();
  }

  @override
  List<Object?> get props => [conversations, isDefaultSmsApp, searchQuery];
}

class ConversationsPermissionDenied extends ConversationsState {
  const ConversationsPermissionDenied({required this.isDefaultSmsApp});
  final bool isDefaultSmsApp;

  @override
  List<Object?> get props => [isDefaultSmsApp];
}

class ConversationsError extends ConversationsState {
  const ConversationsError({
    required this.message,
    required this.isDefaultSmsApp,
  });

  final String message;
  final bool isDefaultSmsApp;

  @override
  List<Object?> get props => [message, isDefaultSmsApp];
}
