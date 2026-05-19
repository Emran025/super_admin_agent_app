import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../data/pairing/repositories/pairing_repository_impl.dart';
import '../domain/pairing/repositories/pairing_repository.dart';
import '../domain/pairing/use_cases/complete_pairing_use_case.dart';
import '../domain/pairing/use_cases/scan_pairing_token_use_case.dart';
import '../domain/pairing/use_cases/unpair_system_use_case.dart';
import '../presentation/pairing/cubit/pairing_cubit.dart';
import '../shared/data/canonical_json.dart';
import '../shared/data/crypto_nonce_generator.dart';
import '../shared/data/http_client_factory.dart';
import '../shared/data/paired_system_registry_impl.dart';
import '../shared/data/secure_storage_service_impl.dart';
import '../shared/data/sqlite_audit_log_service.dart';
import '../shared/domain/audit_log_service.dart';
import '../shared/domain/nonce_generator.dart';
import '../shared/domain/paired_system_registry.dart';
import '../shared/domain/secure_storage_service.dart';
import '../shared/domain/signing_service.dart';
import '../shared/domain/sms_parsing_service.dart';
import '../shared/infrastructure/android_keystore_signing_service.dart';
import '../shared/infrastructure/fcm_message_router.dart';
import '../shared/infrastructure/regex_sms_parsing_service.dart';

final GetIt getIt = GetIt.instance;

/// Wires all services into the DI container.
///
/// Registration order matters — dependencies must be registered before
/// their dependents. Called once from [main()] after Firebase and
/// [SqliteAuditLogService] are initialized.
///
/// Capability modules are stubbed with TODO markers; Phases 4–6 fill them in.
Future<void> setupDependencies() async {
  // 1. Secure storage — everything that needs secrets depends on this.
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageServiceImpl(),
  );

  // 2. Signing service — uses secure storage for key material.
  getIt.registerLazySingleton<SigningService>(
    () => AndroidKeystoreSigningService(
      secureStorage: getIt<SecureStorageService>(),
    ),
  );

  // 3. Nonce generator — stateless, const instance.
  getIt.registerLazySingleton<NonceGenerator>(
    () => const CryptoNonceGenerator(),
  );

  // 4. Audit log service — singleton, already initialized.
  getIt.registerLazySingleton<AuditLogService>(
    () => SqliteAuditLogService.instance,
  );

  // 5. SMS parsing service — stateless, const instance.
  getIt.registerLazySingleton<SmsParsingService>(
    () => const RegexSmsParsingService(),
  );

  // 6. Pairing repository — uses plain unauthenticated Dio (intentional).
  getIt.registerLazySingleton<PairingRepository>(
    () => PairingRepositoryImpl(
      secureStorage: getIt<SecureStorageService>(),
      dio: Dio(), // Unauthenticated — only for pairing ceremony.
    ),
  );

  // 7. Paired system registry — loads from storage on reload().
  getIt.registerLazySingleton<PairedSystemRegistry>(
    () => PairedSystemRegistryImpl(
      pairingRepository: getIt<PairingRepository>(),
    ),
  );

  // 8. HTTP client factory — authenticated Dio instances only.
  getIt.registerLazySingleton<HttpClientFactory>(
    () => HttpClientFactory(
      signingService: getIt<SigningService>(),
      nonceGenerator: getIt<NonceGenerator>(),
      registry: getIt<PairedSystemRegistry>(),
    ),
  );

  // 9. FCM message router — all capability handlers register themselves here.
  getIt.registerLazySingleton<FcmMessageRouter>(
    () => FcmMessageRouter(
      registry: getIt<PairedSystemRegistry>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );

  // 10. Pairing use cases and cubit.
  getIt.registerFactory<ScanPairingTokenUseCase>(
    () => ScanPairingTokenUseCase(repository: getIt<PairingRepository>()),
  );
  getIt.registerFactory<CompletePairingUseCase>(
    () => CompletePairingUseCase(
      repository: getIt<PairingRepository>(),
      signingService: getIt<SigningService>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );
  getIt.registerFactory<UnpairSystemUseCase>(
    () => UnpairSystemUseCase(
      repository: getIt<PairingRepository>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );
  getIt.registerFactory<PairingCubit>(
    () => PairingCubit(
      scanUseCase: getIt<ScanPairingTokenUseCase>(),
      completeUseCase: getIt<CompletePairingUseCase>(),
      unpairUseCase: getIt<UnpairSystemUseCase>(),
      registry: getIt<PairedSystemRegistry>(),
    ),
  );

  // TODO(phase-4): Register 2FA module bindings.
  // TODO(phase-5): Register OTP Gateway module bindings.
  // TODO(phase-6): Register Payment Observation module bindings.
}

// Suppress unused import warning — CanonicalJson is a shared utility
// available to all capability phases via this module.
// ignore: unused_element
const _canonicalJsonAvailable = CanonicalJson;
