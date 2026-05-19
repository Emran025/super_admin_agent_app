import 'package:flutter/services.dart';

import '../../domain/otp_gateway/entities/otp_dispatch_command.dart';
import '../../domain/otp_gateway/use_cases/execute_sms_dispatch_use_case.dart';
import '../../domain/otp_gateway/value_objects/sms_delivery_report.dart';

/// Platform-channel implementation of [SmsSenderService].
///
/// Sends SMS via Android's [SmsManager] through a Kotlin [MethodChannel].
/// The Kotlin side is not implemented until the native Android phase.
///
/// In tests, use a mock [SmsSenderService] — never this class.
///
/// TODO(phase-7-android): Implement Kotlin MethodChannel handler using
/// SmsManager with sentIntent/deliveredIntent PendingIntents.
class AndroidSmsSenderService implements SmsSenderService {
  static const MethodChannel _channel =
      MethodChannel('com.superadmin.agent/sms_sender');

  const AndroidSmsSenderService();

  @override
  Future<SmsDeliveryStatus> send({
    required String recipientPhoneNumber,
    required String messageBody,
    required SimSlot simSlot,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('sendSms', {
        'recipient': recipientPhoneNumber,
        'body': messageBody,
        'sim_slot': simSlot.name,
      });

      return _mapStatus(result);
    } on PlatformException {
      // TODO(phase-7-android): Map specific PlatformException codes to statuses.
      return SmsDeliveryStatus.failedGeneric;
    } catch (_) {
      return SmsDeliveryStatus.failedGeneric;
    }
  }

  SmsDeliveryStatus _mapStatus(String? result) {
    return switch (result) {
      'sent' => SmsDeliveryStatus.sent,
      'delivered' => SmsDeliveryStatus.delivered,
      'failed_no_service' => SmsDeliveryStatus.failedNoService,
      _ => SmsDeliveryStatus.failedGeneric,
    };
  }
}
