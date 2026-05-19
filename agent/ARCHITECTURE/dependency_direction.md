# Dependency Direction Rules

> This document defines which directions dependencies are allowed to flow, and which are prohibited.
> These rules enforce the Clean Architecture Dependency Rule in practice.

---

## The Fundamental Rule

> **Source code dependencies may only point inward — from outer layers to inner layers.**

```txt
Presentation → Domain       ✅ Allowed
Data         → Domain       ✅ Allowed
Domain       → Domain       ✅ Allowed (within same module)
Domain       → Data         ❌ FORBIDDEN
Domain       → Presentation ❌ FORBIDDEN
Data         → Presentation ❌ FORBIDDEN
Presentation → Data         ✅ Allowed ONLY in DI wiring (lib/di/)
```

---

## Inter-Domain Dependencies

Domains are siblings. They do not depend on each other's internals.

```txt
auth_2fa     → otp_gateway          ❌ FORBIDDEN
auth_2fa     → payment_observation  ❌ FORBIDDEN
otp_gateway  → auth_2fa             ❌ FORBIDDEN
otp_gateway  → payment_observation  ❌ FORBIDDEN
payment_obs  → auth_2fa             ❌ FORBIDDEN
payment_obs  → otp_gateway          ❌ FORBIDDEN
```

All domains may depend on `lib/shared/domain/` (shared interfaces).

**Failure Code**: AF-02

---

## Allowed Dependency Graph (Complete)

```txt
lib/main.dart
    └── lib/di/app_module.dart
            └── lib/di/*_module.dart
                    ├── lib/data/**/repositories/*_repository_impl.dart
                    │       ├── lib/domain/**/repositories/*_repository.dart  (interface)
                    │       ├── lib/data/**/remote/*_remote_data_source.dart
                    │       └── lib/data/**/local/*_local_data_source.dart
                    └── lib/presentation/**/cubit/*_cubit.dart
                            └── lib/domain/**/use_cases/*_use_case.dart
                                    ├── lib/domain/**/entities/*.dart
                                    ├── lib/domain/**/value_objects/*.dart
                                    └── lib/shared/domain/*.dart  (interfaces)
```

---

## Dependency Inversion Points

These are the places where the Dependency Inversion Principle is actively applied:

| Interface (Domain) | Implementation (Data/Infrastructure) | Wired in |
| --- | --- | --- |
| `AuthChallengeRepository` | `AuthChallengeRepositoryImpl` | `lib/di/auth_2fa_module.dart` |
| `OtpGatewayRepository` | `OtpGatewayRepositoryImpl` | `lib/di/otp_gateway_module.dart` |
| `PaymentObservationRepository` | `PaymentObservationRepositoryImpl` | `lib/di/payment_observation_module.dart` |
| `PairingRepository` | `PairingRepositoryImpl` | `lib/di/pairing_module.dart` |
| `SigningService` | `AndroidKeystoreSigningService` | `lib/di/app_module.dart` |
| `AuditLogService` | `SqliteAuditLogService` | `lib/di/app_module.dart` |
| `NonceGenerator` | `CryptoRandomNonceGenerator` | `lib/di/app_module.dart` |
| `SmsParsingService` | `RegexSmsParsingService` | `lib/di/payment_observation_module.dart` |

---

## What "Wired in DI" Means

The only place a concrete class is allowed to know about another concrete class is in `lib/di/`. Everywhere else, classes communicate through interfaces.

```dart
// ✅ CORRECT — in lib/di/auth_2fa_module.dart
getIt.registerLazySingleton<AuthChallengeRepository>(
  () => AuthChallengeRepositoryImpl(
    remoteDataSource: getIt<AuthChallengeRemoteDataSource>(),
    signingService: getIt<SigningService>(),
    auditLogService: getIt<AuditLogService>(),
  ),
);

// ❌ WRONG — anywhere outside lib/di/
final repo = AuthChallengeRepositoryImpl(/* ... */);
```

---

## Third-Party Package Dependency Directions

| Package | Allowed In | Forbidden In |
| --- | --- | --- |
| `dio` | `lib/data/` | `lib/domain/`, `lib/presentation/` |
| `firebase_messaging` | `lib/shared/infrastructure/`, `lib/data/` | `lib/domain/` |
| `flutter_secure_storage` | `lib/shared/data/` | `lib/domain/` |
| `flutter_bloc` | `lib/presentation/` | `lib/domain/`, `lib/data/` |
| `sqflite` | `lib/shared/data/` | `lib/domain/`, `lib/presentation/` |
| `equatable` | `lib/domain/`, `lib/data/` | N/A |
| `dartz` | `lib/domain/` | `lib/presentation/` (use dedicated error types instead) |
| `get_it` | `lib/di/` | All other layers |
