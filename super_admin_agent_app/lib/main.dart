import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'di/app_module.dart';
import 'domain/pairing/value_objects/capability_grant.dart';
import 'presentation/dashboard/pages/dashboard_page.dart';
import 'presentation/pairing/cubit/pairing_cubit.dart';
import 'presentation/pairing/pages/pairing_page.dart';
import 'shared/data/sqlite_audit_log_service.dart';
import 'shared/domain/paired_system_registry.dart';
import 'shared/infrastructure/auth_2fa_fcm_handler.dart';
import 'shared/infrastructure/fcm_message_router.dart';
import 'shared/infrastructure/otp_gateway_fcm_handler.dart';
import 'shared/infrastructure/payment_observation_fcm_handler.dart';

// ---------------------------------------------------------------------------
// Global navigator key
// ---------------------------------------------------------------------------

/// Required for pushing the 2FA approval dialog from [Auth2faFcmHandler],
/// which has no BuildContext (FCM arrives outside the widget tree).
///
/// TODO(phase-7): extract to a NavigationService abstraction to reduce coupling.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------------------------------
// Background FCM handler — top-level function required by Firebase
// ---------------------------------------------------------------------------

/// Must be annotated with @pragma('vm:entry-point') to survive tree-shaking.
///
/// DI is not available in the background isolate — full routing is wired
/// only for foreground messages via [FirebaseMessaging.onMessage].
///
/// TODO(phase-7): Wire background isolate DI if background processing required.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // TODO(phase-7): Route message via FcmMessageRouter in background isolate.
}

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  // 1. Flutter engine must be initialized before any plugin is used.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase must be initialized before any FCM call.
  await Firebase.initializeApp();

  // 3. Register background handler before any messages can arrive.
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // 4. Initialize the append-only audit log database.
  await SqliteAuditLogService.init();

  // 5. Wire all services into the DI container.
  await setupDependencies();

  // 6. Load all paired systems into the in-memory registry.
  await getIt<PairedSystemRegistry>().reload();

  // 7. Register all capability FCM handlers with the router.
  final router = getIt<FcmMessageRouter>();
  router.registerHandler(
    Capability.twoFa,
    Auth2faFcmHandler(navigatorKey: navigatorKey),
  );
  router.registerHandler(
    Capability.otpGateway,
    OtpGatewayFcmHandler(),
  );
  router.registerHandler(
    Capability.paymentObservation,
    PaymentObservationFcmHandler(),
  );

  // 8. Register foreground FCM handler.
  FirebaseMessaging.onMessage.listen(
    (msg) => getIt<FcmMessageRouter>().route(msg),
  );

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

      // Global navigator key — required for 2FA dialog from FCM handler.
      // TODO(phase-7): extract to NavigationService
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
        '/dashboard': (_) => BlocProvider(
              create: (_) => getIt<PairingCubit>(),
              child: const DashboardPage(),
            ),
      },
    );
  }

  /// Determines the starting page based on registry state at cold start.
  ///
  /// Presentation routing decision — not a business rule (Constraint 2.4).
  Widget _resolveInitialPage() {
    final registry = getIt<PairedSystemRegistry>();
    if (registry.all.isEmpty) {
      return BlocProvider(
        create: (_) => getIt<PairingCubit>(),
        child: const PairingPage(),
      );
    }
    return BlocProvider(
      create: (_) => getIt<PairingCubit>(),
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
// TODO(phase-7): Extract global navigator key to a NavigationService abstraction
// TODO(phase-7): Refactor AuthChallengeCubit DI to inject systemId at call time rather than placeholder
// TODO(future): Hardware Keystore key rotation policy
// TODO(future): Certificate pinning on Dio instances
// TODO(future): Concurrent 2FA challenge handling for multi-system deployments
// TODO(future): Log export endpoint wiring (send audit log to server on demand)
