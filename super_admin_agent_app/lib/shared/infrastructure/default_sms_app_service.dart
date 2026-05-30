import 'package:flutter/services.dart';

/// Dart interface to the Android "app_control" MethodChannel.
///
/// Provides methods to check and request the Default SMS App role,
/// which is required for:
///   - Reliably sending SMS (avoids RESULT_ERROR_GENERIC_FAILURE on some
///     carriers / Android versions that restrict background SMS sending).
///   - Writing sent messages to the Telephony inbox so they appear in
///     native SMS apps.
///   - Receiving incoming SMS_DELIVER broadcasts (instead of the shared
///     SMS_RECEIVED broadcast available to any app).
class DefaultSmsAppService {
  static const MethodChannel _channel =
      MethodChannel('com.superadmin.agent/app_control');

  const DefaultSmsAppService();

  /// Returns true if this app is currently the Default SMS App.
  Future<bool> isDefaultSmsApp() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDefaultSmsApp');
      return result ?? false;
    } on PlatformException catch (e) {
      print('⚠️ [DefaultSmsApp] isDefaultSmsApp error: $e');
      return false;
    }
  }

  /// Asks Android to show the "Change default SMS app?" dialog.
  ///
  /// Returns one of:
  ///   - `"already_default"` — app was already the default
  ///   - `"granted"` — user selected this app as default
  ///   - `"denied"` — user declined
  ///
  /// Throws [PlatformException] if the OS dialog cannot be shown.
  Future<String> requestDefaultSmsApp() async {
    try {
      final result = await _channel.invokeMethod<String>('requestDefaultSmsApp');
      return result ?? 'denied';
    } on PlatformException catch (e) {
      print('⚠️ [DefaultSmsApp] requestDefaultSmsApp error: $e');
      rethrow;
    }
  }
}
