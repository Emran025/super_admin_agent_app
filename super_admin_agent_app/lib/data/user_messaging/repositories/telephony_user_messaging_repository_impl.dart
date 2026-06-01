import 'package:flutter/services.dart';

import '../../../domain/user_messaging/entities/sms_conversation.dart';
import '../../../domain/user_messaging/entities/sms_thread_message.dart';
import '../../../domain/user_messaging/entities/user_message_delivery_status.dart';
import '../../../domain/user_messaging/repositories/sms_conversation_repository.dart';
import '../../../domain/user_messaging/repositories/user_messaging_repository.dart';
import '../../../shared/infrastructure/telephony_sms_inbox_service.dart';

class TelephonyUserMessagingRepositoryImpl implements UserMessagingRepository {
  const TelephonyUserMessagingRepositoryImpl({
    TelephonySmsInboxService inboxService = const TelephonySmsInboxService(),
  }) : _inboxService = inboxService;

  final TelephonySmsInboxService _inboxService;

  @override
  Future<({List<SmsConversation>? conversations, SmsInboxFailure? failure})>
      listConversations() async {
    try {
      final raw = await _inboxService.getConversations();
      final conversations = raw.map(_mapConversation).whereType<SmsConversation>().toList();
      return (conversations: conversations, failure: null);
    } on PlatformException catch (e) {
      return (conversations: null, failure: _mapPlatformError(e));
    } catch (e) {
      return (conversations: null, failure: SmsInboxQueryFailed(e.toString()));
    }
  }

  @override
  Future<({List<SmsThreadMessage>? messages, SmsInboxFailure? failure})> getThreadMessages(
    int threadId,
  ) async {
    try {
      final raw = await _inboxService.getMessages(threadId);
      final messages = raw.map(_mapMessage).whereType<SmsThreadMessage>().toList();
      return (messages: messages, failure: null);
    } on PlatformException catch (e) {
      return (messages: null, failure: _mapPlatformError(e));
    } catch (e) {
      return (messages: null, failure: SmsInboxQueryFailed(e.toString()));
    }
  }

  @override
  Future<SmsInboxFailure?> markThreadAsRead(int threadId) async {
    try {
      await _inboxService.markThreadAsRead(threadId);
      return null;
    } on PlatformException catch (e) {
      return _mapPlatformError(e);
    } catch (e) {
      return SmsInboxQueryFailed(e.toString());
    }
  }

  @override
  Future<({UserSendResult? result, SmsInboxFailure? failure})> sendMessage({
    required String address,
    required String body,
  }) async {
    try {
      final raw = await _inboxService.sendMessage(address: address, body: body);
      return (result: _mapSendResult(raw), failure: null);
    } on PlatformException catch (e) {
      return (result: null, failure: _mapPlatformError(e));
    } catch (e) {
      return (result: null, failure: SmsInboxQueryFailed(e.toString()));
    }
  }

  @override
  Future<({UserSendResult? result, SmsInboxFailure? failure})> retryMessage(
    int messageId,
  ) async {
    try {
      final raw = await _inboxService.retryMessage(messageId);
      return (result: _mapSendResult(raw), failure: null);
    } on PlatformException catch (e) {
      return (result: null, failure: _mapPlatformError(e));
    } catch (e) {
      return (result: null, failure: SmsInboxQueryFailed(e.toString()));
    }
  }

  @override
  Future<bool> deleteMessage(int messageId) async {
    try {
      return await _inboxService.deleteMessage(messageId);
    } catch (_) {
      return false;
    }
  }

  SmsInboxFailure _mapPlatformError(PlatformException e) {
    if (e.code == 'PERMISSION_DENIED') return const SmsInboxPermissionDenied();
    return SmsInboxQueryFailed(e.message ?? e.code);
  }

  SmsConversation? _mapConversation(Map<dynamic, dynamic> row) {
    final threadId = row['threadId'];
    final address = row['address'] as String?;
    if (threadId is! int && threadId is! num) return null;
    if (address == null || address.isEmpty) return null;

    final timestampMs = row['timestampMs'];
    final ts = timestampMs is int
        ? timestampMs
        : timestampMs is num
            ? timestampMs.toInt()
            : 0;

    return SmsConversation(
      threadId: threadId is int ? threadId : (threadId as num).toInt(),
      address: address,
      displayName: (row['displayName'] as String?)?.trim().isNotEmpty == true
          ? row['displayName'] as String
          : address,
      snippet: (row['snippet'] as String?) ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      unreadCount: _asInt(row['unreadCount']),
      isRead: row['isRead'] == true,
    );
  }

  SmsThreadMessage? _mapMessage(Map<dynamic, dynamic> row) {
    final messageId = row['messageId'];
    if (messageId is! int && messageId is! num) return null;

    final timestampMs = row['timestampMs'];
    final ts = timestampMs is int
        ? timestampMs
        : timestampMs is num
            ? timestampMs.toInt()
            : 0;

    return SmsThreadMessage(
      messageId: messageId is int ? messageId : (messageId as num).toInt(),
      address: (row['address'] as String?) ?? '',
      body: (row['body'] as String?) ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      isOutgoing: row['isOutgoing'] == true,
      deliveryStatus: _mapDelivery(row['deliveryStatus'] as String?),
    );
  }

  UserMessageDeliveryStatus _mapDelivery(String? status) {
    return switch (status) {
      'pending' => UserMessageDeliveryStatus.pending,
      'failed' => UserMessageDeliveryStatus.failed,
      'sent' => UserMessageDeliveryStatus.sent,
      _ => UserMessageDeliveryStatus.received,
    };
  }

  UserSendResult? _mapSendResult(Map<dynamic, dynamic> raw) {
    final messageId = raw['messageId'];
    if (messageId is! int && messageId is! num) return null;
    final statusStr = raw['status'] as String? ?? 'failed';
    final delivery = switch (statusStr) {
      'sent' => UserMessageDeliveryStatus.sent,
      'pending' => UserMessageDeliveryStatus.pending,
      'failed_no_service' || 'failed' => UserMessageDeliveryStatus.failed,
      _ => UserMessageDeliveryStatus.failed,
    };
    return UserSendResult(
      messageId: messageId is int ? messageId : (messageId as num).toInt(),
      deliveryStatus: delivery,
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
