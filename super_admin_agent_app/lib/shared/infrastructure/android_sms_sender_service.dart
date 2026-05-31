import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

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
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true));

  const AndroidSmsSenderService();

  @override
  Future<SmsDeliveryStatus> send({
    required String recipientPhoneNumber,
    required String messageBody,
    required SimSlot simSlot,
    required String customerName,
    required String systemName,
  }) async {
    try {
      _log.d('[OTP] AndroidSmsSenderService invoking MethodChannel "sendSms" for customer: $customerName from system: $systemName...');
      final result = await _channel.invokeMethod<String>('sendSms', {
        'recipient': recipientPhoneNumber,
        'body': messageBody,
        'sim_slot': simSlot.name,
        'customer_name': customerName,
        'system_name': systemName,
      });
      _log.d('[OTP] AndroidSmsSenderService MethodChannel result: $result');

      return _mapStatus(result);
    } on PlatformException catch (e) {
      _log.w('[OTP] AndroidSmsSenderService PlatformException: $e');
      // TODO(phase-7-android): Map specific PlatformException codes to statuses.
      return SmsDeliveryStatus.failedGeneric;
    } catch (e) {
      _log.w('[OTP] AndroidSmsSenderService generic exception: $e');
      return SmsDeliveryStatus.failedGeneric;
    }
  }

  SmsDeliveryStatus _mapStatus(String? result) {
    if (result != null && result.startsWith('failed_generic_')) {
      _log.w('[OTP] AndroidSmsSenderService OS rejected SMS with code: $result (1=Generic Failure, 2=Radio Off, 4=No Service)');
      return SmsDeliveryStatus.failedGeneric;
    }
    return switch (result) {
      'sent' => SmsDeliveryStatus.sent,
      'delivered' => SmsDeliveryStatus.delivered,
      'failed_no_service' => SmsDeliveryStatus.failedNoService,
      _ => SmsDeliveryStatus.failedGeneric,
    };
  }
}
