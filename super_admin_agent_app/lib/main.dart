import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'di/app_module.dart';
import 'presentation/auth_2fa/cubit/auth_challenge_cubit.dart';
import 'presentation/auth_2fa/widgets/challenge_approval_dialog.dart';
import 'presentation/dashboard/cubit/linked_systems_cubit.dart';
import 'presentation/dashboard/pages/dashboard_page.dart';
import 'presentation/pairing/cubit/pairing_cubit.dart';
import 'presentation/pairing/pages/link_system_page.dart';
import 'presentation/pairing/pages/pairing_page.dart';
import 'presentation/shared/theme/app_theme.dart';
import 'shared/domain/paired_system_registry.dart';
import 'shared/infrastructure/agent_websocket_service.dart';
import 'shared/infrastructure/permission_handler_service.dart';

// ---------------------------------------------------------------------------
// Module-level logger (main isolate)
// ---------------------------------------------------------------------------

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

// ---------------------------------------------------------------------------
// Global navigator key
// ---------------------------------------------------------------------------

/// Required for pushing the 2FA approval dialog from [Auth2faWsHandler],
/// which has no BuildContext (WebSocket arrives outside the widget tree).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  // 1. Flutter engine must be initialized before any plugin is used.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Wire all services into the DI container.
  //    NOTE: loadExistingKeyPair() was removed from setupDependencies() to
  //    avoid blocking the main thread with SecureStorage reads. The signing
  //    key is loaded lazily on first authenticated request, and the background
  //    isolate performs its own independent loadExistingKeyPair().
  await setupDependencies();

  // 3. Load all paired systems into the in-memory registry.
  //    This must happen before runApp() so the initial route can be resolved.
  await getIt<PairedSystemRegistry>().reload();

  // 4. Listen for 2FA challenge approval requests from the background service isolate.
  FlutterBackgroundService().on('show_challenge').listen((event) {
    _log.i('[main] show_challenge IPC received — event=$event');
    if (event != null) {
      final commandId = event['commandId'] as String?;
      final systemId = event['systemId'] as String?;
      final externalSystemId = event['externalSystemId'] as String?;
      if (commandId != null && systemId != null) {
        _show2FaDialog(commandId, systemId, externalSystemId);
      } else {
        _log.w('[main] show_challenge: missing commandId or systemId in payload');
      }
    } else {
      _log.w('[main] show_challenge: received null event');
    }
  });

  // 5. Start the app — render the first frame ASAP.
  runApp(const SuperAdminAgentApp());

  // 6. Deferred initialisation — runs AFTER the first frame is painted.
  //    This keeps the startup-to-first-frame path as lean as possible on
  //    low-end devices (Redmi 9A / M2006C3LC / Helio G25).
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // 6a. Request runtime permissions (shows system dialogs, which don't need
    //     the app's own UI to be ready yet — Android handles the dialog).
    const PermissionHandlerService().requestAll();

    // 6b. Start the Android Foreground Service.
    //     The background service spawns a separate Dart isolate that performs
    //     heavy I/O (SQLite init, DI wiring, SecureStorage reads, WebSocket
    //     connect). Starting it before runApp() forces the main thread to
    //     compete for resources, causing 200–250 frame drops on low-end devices.
    //     NOTE: SqliteAuditLogService.init() is intentionally NOT called here.
    //     The audit log database is opened exclusively inside the background
    //     service isolate (_onStart). Calling it in both the UI isolate and the
    //     background isolate simultaneously causes sqflite to race on the same
    //     SQLite file, corrupting the internal transaction state.
    await AgentForegroundService.init();
  });
}

/// Dynamic dialog dispatcher for background-triggered 2FA authentication challenges.
void _show2FaDialog(String commandId, String systemId, String? externalSystemId) {
  final navigatorState = navigatorKey.currentState;
  if (navigatorState == null) return;

  final cubit = getIt<AuthChallengeCubit>();
  cubit.loadChallenge(
    challengeId: commandId,
    systemId: systemId,
    externalSystemId: externalSystemId,
  );

  navigatorState.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const ChallengeApprovalDialog(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Root app widget
// ---------------------------------------------------------------------------

class SuperAdminAgentApp extends StatelessWidget {
  const SuperAdminAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Admin Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),

      // Global navigator key — required for 2FA dialog from WS handler.
      navigatorKey: navigatorKey,

      // Initial route is determined at runtime by registry state.
      initialRoute: '/',
      onGenerateInitialRoutes: (_) {
        return [
          MaterialPageRoute<void>(
            builder: (_) => _resolveInitialPage(),
          ),
        ];
      },

      routes: {
        '/pair': (_) => BlocProvider(
              create: (_) => getIt<PairingCubit>(),
              child: const PairingPage(),
            ),
        '/dashboard': (_) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => getIt<PairingCubit>()),
                BlocProvider(create: (_) => getIt<LinkedSystemsCubit>()),
              ],
              child: const DashboardPage(),
            ),
        '/link-system': (_) => BlocProvider(
              create: (_) => getIt<LinkedSystemsCubit>(),
              child: const LinkSystemPage(),
            ),
      },
    );
  }

  /// Determines the starting page based on registry state at cold start.
  Widget _resolveInitialPage() {
    final registry = getIt<PairedSystemRegistry>();
    if (registry.all.isEmpty) {
      return BlocProvider(
        create: (_) => getIt<PairingCubit>(),
        child: const PairingPage(),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<PairingCubit>()),
        BlocProvider(create: (_) => getIt<LinkedSystemsCubit>()),
      ],
      child: const DashboardPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase 7 TODO list — handoff points for native Android engineer
// ---------------------------------------------------------------------------

// TODO(phase-7-android): Implement Kotlin MethodChannel handler for Android Keystore hardware-backed signing
// TODO(phase-7-android): Implement Kotlin MethodChannel handler for SmsManager with sentIntent/deliveredIntent PendingIntents
// TODO(phase-7-android): Implement Kotlin BroadcastReceiver for SMS_RECEIVED → EventChannel to Flutter
// TODO(phase-7-android): Implement KeyguardManager.isDeviceSecure() check via platform channel (SC-10)
// TODO(phase-7): Inject HttpClientFactory into AgentWebSocketService for full signing interceptor on channel auth
// TODO(phase-7): Re-initialise DI and AgentWebSocketService inside the background isolate (_onStart)
// TODO(phase-7): Extract global navigator key to a NavigationService abstraction
// TODO(phase-7): Refactor AuthChallengeCubit DI to inject systemId at call time rather than placeholder
// TODO(future): Hardware Keystore key rotation policy
// TODO(future): Certificate pinning on Dio instances
// TODO(future): Concurrent 2FA challenge handling for multi-system deployments
// TODO(future): Log export endpoint wiring (send audit log to server on demand)
// TODO(future): Reconnect WebSocket inside background isolate after Doze wake
