import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'di/app_module.dart';
import 'shared/data/sqlite_audit_log_service.dart';
import 'shared/domain/paired_system_registry.dart';
import 'shared/infrastructure/fcm_message_router.dart';

/// Background FCM handler — top-level function required by Firebase.
///
/// Must be annotated with @pragma('vm:entry-point') to survive tree-shaking
/// in release builds (Constraint 2.6).
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

Future<void> main() async {
  // 1. Flutter engine must be initialized before any plugin is used.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase must be initialized before any FCM or Firestore call.
  await Firebase.initializeApp();

  // 3. Register background handler before any messages can arrive.
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // 4. Initialize the append-only audit log database.
  await SqliteAuditLogService.init();

  // 5. Wire all shared and pairing services into the DI container.
  await setupDependencies();

  // 6. Load all paired systems into the in-memory registry.
  await getIt<PairedSystemRegistry>().reload();

  // 7. Register foreground FCM handler.
  FirebaseMessaging.onMessage.listen(
    (msg) => getIt<FcmMessageRouter>().route(msg),
  );

  // 8. Start the app.
  runApp(const SuperAdminAgentApp());
}

class SuperAdminAgentApp extends StatelessWidget {
  const SuperAdminAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Admin Agent',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'Phase 3: Infrastructure Ready',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
