import 'dart:async';

import 'package:flutter/services.dart';

/// Platform channel for user SMS inbox (Chats UI only).
class TelephonySmsInboxService {
  static const _channel = MethodChannel('com.superadmin.agent/sms_inbox');
  static const _events = EventChannel('com.superadmin.agent/sms_inbox_events');

  const TelephonySmsInboxService();

  Stream<void> get onInboxChanged {
    return _events.receiveBroadcastStream().map((_) {});
  }

  Future<List<Map<dynamic, dynamic>>> getConversations() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getConversations');
    if (result == null) return [];
    return result.map((e) => Map<dynamic, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<dynamic, dynamic>>> getMessages(int threadId) async {
    final result = await _channel.invokeMethod<List<dynamic>>('getMessages', {
      'threadId': threadId,
    });
    if (result == null) return [];
    return result.map((e) => Map<dynamic, dynamic>.from(e as Map)).toList();
  }

  Future<void> markThreadAsRead(int threadId) async {
    await _channel.invokeMethod<void>('markThreadAsRead', {'threadId': threadId});
  }

  Future<Map<dynamic, dynamic>> sendMessage({
    required String address,
    required String body,
  }) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('sendMessage', {
      'address': address,
      'body': body,
    });
    return Map<dynamic, dynamic>.from(result ?? {});
  }

  Future<Map<dynamic, dynamic>> retryMessage(int messageId) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('retryMessage', {
      'messageId': messageId,
    });
    return Map<dynamic, dynamic>.from(result ?? {});
  }

  Future<bool> deleteMessage(int messageId) async {
    final result = await _channel.invokeMethod<bool>('deleteMessage', {
      'messageId': messageId,
    });
    return result ?? false;
  }

}
