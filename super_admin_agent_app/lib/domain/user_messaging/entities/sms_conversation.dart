import 'package:equatable/equatable.dart';

/// A thread in the device SMS store (user-facing inbox only).
///
/// Distinct from agent OTP / payment observation models.
class SmsConversation extends Equatable {
  const SmsConversation({
    required this.threadId,
    required this.address,
    required this.displayName,
    required this.snippet,
    required this.timestamp,
    required this.unreadCount,
    required this.isRead,
  });

  final int threadId;
  final String address;
  final String displayName;
  final String snippet;
  final DateTime timestamp;
  final int unreadCount;
  final bool isRead;

  /// First character for avatar initials (supports Arabic).
  String get avatarInitial {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first);
  }

  bool get hasUnread => unreadCount > 0;

  @override
  List<Object?> get props => [
        threadId,
        address,
        displayName,
        snippet,
        timestamp,
        unreadCount,
        isRead,
      ];
}
