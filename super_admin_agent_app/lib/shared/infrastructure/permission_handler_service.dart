import 'package:permission_handler/permission_handler.dart';

/// Requests runtime permissions required by the capabilities.
///
/// If permissions are denied, the app still runs, but specific
/// capabilities (like sending OTP SMS) will gracefully fail and report
/// the failure when commanded.
class PermissionHandlerService {
  const PermissionHandlerService();

  Future<Map<Permission, bool>> requestAll() async {
    final statuses = await [
      Permission.sms,
      Permission.phone,
      Permission.camera, // For pairing QR scan
      Permission.notification,
    ].request();

    return statuses.map((key, value) => MapEntry(key, value.isGranted));
  }
}
