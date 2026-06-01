import 'package:equatable/equatable.dart';

import '../../../domain/user_messaging/entities/sms_thread_message.dart';

sealed class ThreadState extends Equatable {
  const ThreadState({required this.isDefaultSmsApp});

  final bool isDefaultSmsApp;

  @override
  List<Object?> get props => [isDefaultSmsApp];
}

class ThreadInitial extends ThreadState {
  const ThreadInitial({super.isDefaultSmsApp = false});
}

class ThreadLoading extends ThreadState {
  const ThreadLoading({required super.isDefaultSmsApp});
}

class ThreadLoaded extends ThreadState {
  const ThreadLoaded({
    required super.isDefaultSmsApp,
    required this.messages,
    this.isSending = false,
  });

  final List<SmsThreadMessage> messages;
  final bool isSending;

  @override
  List<Object?> get props => [...super.props, messages, isSending];
}

class ThreadError extends ThreadState {
  const ThreadError({
    required super.isDefaultSmsApp,
    required this.message,
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}
