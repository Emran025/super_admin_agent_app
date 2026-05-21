import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../presentation/auth_2fa/cubit/auth_challenge_cubit.dart';
import '../../presentation/auth_2fa/widgets/challenge_approval_dialog.dart';
import 'agent_websocket_service.dart';
import 'ws_message_router.dart';

/// WebSocket handler for the [two_fa] capability.
///
/// Structurally identical to the former Auth2faFcmHandler.
/// On receiving a command:
/// 1. Creates a fresh [AuthChallengeCubit] from DI
/// 2. Calls [loadChallenge] to fetch the challenge from the server
/// 3. Pushes [ChallengeApprovalDialog] via the global navigator key
class Auth2faWsHandler implements CapabilityCommandHandler {
  final GetIt _getIt;
  final GlobalKey<NavigatorState> navigatorKey;

  Auth2faWsHandler({
    required this.navigatorKey,
    GetIt? getIt,
  }) : _getIt = getIt ?? GetIt.instance;

  @override
  Future<void> handle({
    required String commandId,
    required String systemId,
    Map<String, dynamic>? payload,
  }) async {
    // 1. Notify the main isolate (if running) to display the challenge dialog
    FlutterBackgroundService().invoke('show_challenge', {
      'commandId': commandId,
      'systemId': systemId,
    });

    // 2. Update the background/foreground service notification with details of the pending 2FA request
    final service = AgentForegroundService.instance;
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Super Admin Agent - Action Required',
        content: 'Pending 2FA Approval: tap to approve or deny',
      );
    }

    final cubit = _getIt<AuthChallengeCubit>();

    await cubit.loadChallenge(
      challengeId: commandId,
      systemId: systemId,
    );

    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) return;

    await navigatorState.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const ChallengeApprovalDialog(),
        ),
      ),
    );
  }
}
