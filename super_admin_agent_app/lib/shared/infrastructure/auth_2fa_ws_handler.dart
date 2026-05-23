import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';

import 'agent_websocket_service.dart';
import 'ws_message_router.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// WebSocket handler for the [two_fa] capability.
///
/// Runs exclusively in the **background service isolate** — it has no access
/// to the Flutter widget tree or any UI navigator. Its only job is to:
///
///   1. Forward the challenge identifiers to the **main isolate** via the
///      background-service IPC channel so that main.dart can show the
///      [ChallengeApprovalDialog].
///   2. Update the persistent foreground notification so the user sees a
///      "tap to approve" prompt even if the app is not in the foreground.
///
/// IPC direction note
/// ──────────────────
/// [FlutterBackgroundService().invoke()] sends events MAIN → BACKGROUND.
/// To send BACKGROUND → MAIN (what we need here), call
/// [ServiceInstance.invoke()] — i.e. [AgentForegroundService.instance?.invoke()].
/// The main isolate then receives the event via
/// [FlutterBackgroundService().on('show_challenge').listen(...)].
class Auth2faWsHandler implements CapabilityCommandHandler {
  const Auth2faWsHandler();

  @override
  Future<void> handle({
    required String commandId,
    required String systemId,
    Map<String, dynamic>? payload,
  }) async {
    _log.i('[Auth2faWsHandler] challenge received — commandId=$commandId systemId=$systemId');

    // 1. Send the challenge to the main isolate so it can show the approval dialog.
    //    ServiceInstance.invoke() is the background→main direction.
    final service = AgentForegroundService.instance;
    if (service == null) {
      _log.e('[Auth2faWsHandler] AgentForegroundService.instance is null — cannot dispatch show_challenge IPC');
      return;
    }

    service.invoke('show_challenge', {
      'commandId': commandId,
      'systemId': systemId,
    });
    _log.i('[Auth2faWsHandler] show_challenge IPC dispatched to main isolate');

    // 2. Update the persistent foreground notification to prompt the user.
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Super Admin Agent — Action Required',
        content: 'Pending 2FA approval: open the app to approve or deny',
      );
    }
  }
}
