import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../presentation/auth_2fa/cubit/auth_challenge_cubit.dart';
import '../../presentation/auth_2fa/widgets/challenge_approval_dialog.dart';
import 'fcm_message_router.dart';

/// FCM handler for the [two_fa] capability.
///
/// On receiving a command:
/// 1. Creates a fresh [AuthChallengeCubit] from DI
/// 2. Calls [loadChallenge] to fetch the challenge from the server
/// 3. Pushes [ChallengeApprovalDialog] via the global navigator key
///
/// The global navigator key is the only coupling to the presentation layer.
/// TODO(phase-7): extract to a NavigationService abstraction to reduce coupling.
class Auth2faFcmHandler implements CapabilityCommandHandler {
  final GetIt _getIt;

  /// The global navigator key declared in [main.dart].
  /// Required to push UI from outside a [BuildContext].
  final GlobalKey<NavigatorState> navigatorKey;

  Auth2faFcmHandler({
    required this.navigatorKey,
    GetIt? getIt,
  }) : _getIt = getIt ?? GetIt.instance;

  @override
  Future<void> handle({
    required String commandId,
    required String systemId,
  }) async {
    // Create a fresh cubit — each challenge gets its own lifecycle.
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
