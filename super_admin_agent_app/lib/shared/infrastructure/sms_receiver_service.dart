import 'package:flutter/services.dart';

import '../../domain/payment_observation/use_cases/process_incoming_sms_use_case.dart';

/// Singleton service that exposes a stream of incoming SMS events.
///
/// Uses an [EventChannel] to receive events from a Kotlin [BroadcastReceiver]
/// registered for [android.provider.Telephony.SMS_RECEIVED].
///
/// TODO(phase-7-android): Implement Kotlin BroadcastReceiver for
/// SMS_RECEIVED → EventChannel to Flutter.
class SmsReceiverService {
  static const EventChannel _channel =
      EventChannel('com.superadmin.agent/sms_receiver');

  static SmsReceiverService? _instance;

  SmsReceiverService._();

  static SmsReceiverService get instance {
    _instance ??= SmsReceiverService._();
    return _instance!;
  }

  /// Stream of raw SMS events from the Android broadcast receiver.
  ///
  /// Each event is a [Map] with keys: [sender], [body], [timestamp_ms].
  Stream<RawSmsEvent> get incomingSms {
    return _channel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return RawSmsEvent(
        senderName: map['sender'] as String,
        body: map['body'] as String,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp_ms'] as int,
          isUtc: true,
        ),
      );
    });
  }
}
