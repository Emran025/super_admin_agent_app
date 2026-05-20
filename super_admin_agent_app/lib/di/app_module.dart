import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../data/auth_2fa/repositories/auth_challenge_repository_impl.dart';
import '../data/otp_gateway/repositories/otp_gateway_repository_impl.dart';
import '../data/pairing/repositories/pairing_repository_impl.dart';
import '../data/payment_observation/repositories/payment_observation_repository_impl.dart';
import '../domain/auth_2fa/repositories/auth_challenge_repository.dart';
import '../domain/auth_2fa/use_cases/receive_auth_challenge_use_case.dart';
import '../domain/auth_2fa/use_cases/record_user_decision_use_case.dart';
import '../domain/auth_2fa/use_cases/submit_challenge_response_use_case.dart';
import '../domain/otp_gateway/repositories/otp_gateway_repository.dart';
import '../domain/otp_gateway/use_cases/execute_sms_dispatch_use_case.dart';
import '../domain/otp_gateway/use_cases/receive_dispatch_command_use_case.dart';
import '../domain/otp_gateway/use_cases/report_delivery_status_use_case.dart';
import '../domain/pairing/repositories/pairing_repository.dart';
import '../domain/pairing/use_cases/complete_pairing_use_case.dart';
import '../domain/pairing/use_cases/get_linked_systems_use_case.dart';
import '../domain/pairing/use_cases/link_system_use_case.dart';
import '../domain/pairing/use_cases/scan_pairing_token_use_case.dart';
import '../domain/pairing/use_cases/unlink_system_use_case.dart';
import '../domain/pairing/use_cases/unpair_system_use_case.dart';
import '../domain/payment_observation/repositories/payment_observation_repository.dart';
import '../domain/payment_observation/use_cases/match_observation_to_intent_use_case.dart';
import '../domain/payment_observation/use_cases/process_incoming_sms_use_case.dart';
import '../domain/payment_observation/use_cases/register_observation_session_use_case.dart';
import '../domain/payment_observation/use_cases/report_observation_use_case.dart';
import '../presentation/auth_2fa/cubit/auth_challenge_cubit.dart';
import '../presentation/dashboard/cubit/linked_systems_cubit.dart';
import '../presentation/otp_gateway/cubit/otp_dispatch_cubit.dart';
import '../presentation/pairing/cubit/pairing_cubit.dart';
import '../presentation/payment_observation/cubit/payment_observation_cubit.dart';
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
import '../shared/infrastructure/agent_websocket_service.dart';
import '../shared/infrastructure/android_keystore_signing_service.dart';
import '../shared/infrastructure/android_sms_sender_service.dart';
import '../shared/infrastructure/regex_sms_parsing_service.dart';
import '../shared/infrastructure/sms_receiver_service.dart';
import '../shared/infrastructure/ws_message_router.dart';

final GetIt getIt = GetIt.instance;

/// Wires all services into the DI container.
///
/// Registration order matters — dependencies must be registered before
/// their dependents. Called once from [main()] after [SqliteAuditLogService]
/// and [AgentForegroundService] are initialized.
Future<void> setupDependencies() async {
  // 1. Secure storage — foundation for all secrets.
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageServiceImpl(),
  );

  // 2. Signing service — uses secure storage for key material.
  getIt.registerLazySingleton<SigningService>(
    () => AndroidKeystoreSigningService(
      secureStorage: getIt<SecureStorageService>(),
    ),
  );

  // 3. Nonce generator — stateless, const.
  getIt.registerLazySingleton<NonceGenerator>(
    () => const CryptoNonceGenerator(),
  );

  // 4. Audit log service — singleton, already initialized via SqliteAuditLogService.init().
  getIt.registerLazySingleton<AuditLogService>(
    () => SqliteAuditLogService.instance,
  );

  // 5. SMS parsing service — stateless, const.
  getIt.registerLazySingleton<SmsParsingService>(
    () => const RegexSmsParsingService(),
  );

  // 6. Pairing repository — plain unauthenticated Dio (only acceptable raw Dio usage).
  getIt.registerLazySingleton<PairingRepository>(
    () => PairingRepositoryImpl(
      secureStorage: getIt<SecureStorageService>(),
      dio: Dio(), // Unauthenticated — only for pairing ceremony. Justified in spec §4.
    ),
  );

  // 7. Paired system registry — in-memory singleton, reloaded at startup.
  getIt.registerLazySingleton<PairedSystemRegistry>(
    () => PairedSystemRegistryImpl(
      pairingRepository: getIt<PairingRepository>(),
    ),
  );

  // 8. HTTP client factory — authenticated Dio per system, the only signing path.
  getIt.registerLazySingleton<HttpClientFactory>(
    () => HttpClientFactory(
      signingService: getIt<SigningService>(),
      nonceGenerator: getIt<NonceGenerator>(),
      registry: getIt<PairedSystemRegistry>(),
    ),
  );

  // 9. WebSocket message router — all capability handlers register here.
  //    Replaces the former FcmMessageRouter. Routing logic is structurally identical.
  getIt.registerLazySingleton<WsMessageRouter>(
    () => WsMessageRouter(
      registry: getIt<PairedSystemRegistry>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );

  // 10. Agent WebSocket service — maintains persistent connection to Reverb.
  //     Replaces Firebase Cloud Messaging as the command delivery channel.
  //     HttpClientFactory is injected so _fetchChannelAuth can make ECDSA-signed
  //     requests to the broadcasting auth endpoint.
  getIt.registerLazySingleton<AgentWebSocketService>(
    () => AgentWebSocketService(
      router: getIt<WsMessageRouter>(),
      registry: getIt<PairedSystemRegistry>(),
      secureStorage: getIt<SecureStorageService>(),
      clientFactory: getIt<HttpClientFactory>(),
    ),
  );

  // 11. Pairing use cases and cubit.
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
  getIt.registerFactory<GetLinkedSystemsUseCase>(
    () => GetLinkedSystemsUseCase(repository: getIt<PairingRepository>()),
  );
  getIt.registerFactory<LinkSystemUseCase>(
    () => LinkSystemUseCase(repository: getIt<PairingRepository>()),
  );
  getIt.registerFactory<UnlinkSystemUseCase>(
    () => UnlinkSystemUseCase(repository: getIt<PairingRepository>()),
  );
  getIt.registerFactory<LinkedSystemsCubit>(
    () => LinkedSystemsCubit(
      getUseCase: getIt<GetLinkedSystemsUseCase>(),
      linkUseCase: getIt<LinkSystemUseCase>(),
      unlinkUseCase: getIt<UnlinkSystemUseCase>(),
    ),
  );

  // 12. Phase 4 — 2FA capability bindings.
  getIt.registerLazySingleton<AuthChallengeRepository>(
    () => AuthChallengeRepositoryImpl(
      clientFactory: getIt<HttpClientFactory>(),
    ),
  );
  getIt.registerLazySingleton<ReceiveAuthChallengeUseCase>(
    () => ReceiveAuthChallengeUseCase(
      repository: getIt<AuthChallengeRepository>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );
  getIt.registerLazySingleton<RecordUserDecisionUseCase>(
    () => RecordUserDecisionUseCase(
      signingService: getIt<SigningService>(),
      nonceGenerator: getIt<NonceGenerator>(),
    ),
  );
  getIt.registerLazySingleton<SubmitChallengeResponseUseCase>(
    () => SubmitChallengeResponseUseCase(
      repository: getIt<AuthChallengeRepository>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );
  getIt.registerFactory<AuthChallengeCubit>(
    () => AuthChallengeCubit(
      receiveUseCase: getIt<ReceiveAuthChallengeUseCase>(),
      recordUseCase: getIt<RecordUserDecisionUseCase>(),
      submitUseCase: getIt<SubmitChallengeResponseUseCase>(),
    ),
  );

  // 13. Phase 5 — OTP Gateway capability bindings.
  getIt.registerLazySingleton<OtpGatewayRepository>(
    () => OtpGatewayRepositoryImpl(
      clientFactory: getIt<HttpClientFactory>(),
    ),
  );
  getIt.registerLazySingleton<ReceiveDispatchCommandUseCase>(
    () => ReceiveDispatchCommandUseCase(
      repository: getIt<OtpGatewayRepository>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );
  getIt.registerLazySingleton<ExecuteSmsDispatchUseCase>(
    () => ExecuteSmsDispatchUseCase(
      smsSenderService: const AndroidSmsSenderService(),
      signingService: getIt<SigningService>(),
      nonceGenerator: getIt<NonceGenerator>(),
    ),
  );
  getIt.registerLazySingleton<ReportDeliveryStatusUseCase>(
    () => ReportDeliveryStatusUseCase(
      repository: getIt<OtpGatewayRepository>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );
  getIt.registerFactory<OtpDispatchCubit>(
    () => OtpDispatchCubit(
      receiveUseCase: getIt<ReceiveDispatchCommandUseCase>(),
      executeUseCase: getIt<ExecuteSmsDispatchUseCase>(),
      reportUseCase: getIt<ReportDeliveryStatusUseCase>(),
    ),
  );

  // 14. Phase 6 — Payment Observation capability bindings.
  getIt.registerLazySingleton<PaymentObservationRepository>(
    () => PaymentObservationRepositoryImpl(
      clientFactory: getIt<HttpClientFactory>(),
    ),
  );
  getIt.registerLazySingleton<RegisterObservationSessionUseCase>(
    () => RegisterObservationSessionUseCase(
      repository: getIt<PaymentObservationRepository>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );
  getIt.registerLazySingleton<ProcessIncomingSmsUseCase>(
    () => ProcessIncomingSmsUseCase(
      parsingService: getIt<SmsParsingService>(),
    ),
  );
  getIt.registerLazySingleton<MatchObservationToIntentUseCase>(
    () => const MatchObservationToIntentUseCase(),
  );
  getIt.registerLazySingleton<ReportObservationUseCase>(
    () => ReportObservationUseCase(
      repository: getIt<PaymentObservationRepository>(),
      signingService: getIt<SigningService>(),
      nonceGenerator: getIt<NonceGenerator>(),
      auditLogService: getIt<AuditLogService>(),
    ),
  );
  getIt.registerFactory<PaymentObservationCubit>(
    () => PaymentObservationCubit(
      registerUseCase: getIt<RegisterObservationSessionUseCase>(),
      processUseCase: getIt<ProcessIncomingSmsUseCase>(),
      matchUseCase: getIt<MatchObservationToIntentUseCase>(),
      reportUseCase: getIt<ReportObservationUseCase>(),
      smsReceiver: SmsReceiverService.instance,
    ),
  );
}

// Suppress unused import warning — CanonicalJson is a shared utility
// available to all capability phases via this module.
// ignore: unused_element
const _canonicalJsonAvailable = CanonicalJson;
