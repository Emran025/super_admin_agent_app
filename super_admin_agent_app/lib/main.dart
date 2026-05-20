import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'di/app_module.dart';
import 'presentation/dashboard/cubit/linked_systems_cubit.dart';
import 'presentation/dashboard/pages/dashboard_page.dart';
import 'presentation/pairing/cubit/pairing_cubit.dart';
import 'presentation/pairing/pages/link_system_page.dart';
import 'presentation/pairing/pages/pairing_page.dart';
import 'shared/data/sqlite_audit_log_service.dart';
import 'shared/domain/paired_system_registry.dart';
import 'shared/infrastructure/agent_websocket_service.dart';
import 'shared/infrastructure/auth_2fa_ws_handler.dart';
import 'shared/infrastructure/otp_gateway_ws_handler.dart';
import 'shared/infrastructure/payment_observation_ws_handler.dart';
import 'shared/infrastructure/permission_handler_service.dart';
import 'shared/infrastructure/ws_message_router.dart';

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

  // 2. Request runtime permissions.
  //    This must happen before starting the foreground service so that notification
  //    permissions (required on Android 13+) are requested/granted first.
  await const PermissionHandlerService().requestAll();

  // 3. Initialise the Android Foreground Service.
  //    This keeps the process alive through Doze mode, ensuring the WebSocket
  //    connection is never killed by the OS in the background.
  await AgentForegroundService.init();

  // 4. Initialize the append-only audit log database.
  await SqliteAuditLogService.init();

  // 5. Wire all services into the DI container.
  await setupDependencies();

  // 6. Load all paired systems into the in-memory registry.
  await getIt<PairedSystemRegistry>().reload();

  // 7. Register all capability WebSocket handlers with the router.
  final router = getIt<WsMessageRouter>();
  router.registerHandler(
    CapabilityId.twoFa,
    Auth2faWsHandler(navigatorKey: navigatorKey),
  );
  router.registerHandler(
    CapabilityId.otpGateway,
    OtpGatewayWsHandler(),
  );
  router.registerHandler(
    CapabilityId.paymentObservation,
    PaymentObservationWsHandler(),
  );

  // 8. Open the persistent WebSocket connection to the Reverb server.
  //    This replaces Firebase Cloud Messaging as the command delivery channel.
  await getIt<AgentWebSocketService>().connect();

  // 9. Start the app.
  runApp(const SuperAdminAgentApp());
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
