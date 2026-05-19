# Clean Architecture Rules

> Binding rules for this project. Not a theoretical overview.

---

## The Layer Model

```txt
┌────────────────────────────────────┐
│         PRESENTATION LAYER         │
│  Widgets, Cubits, Routes           │
│  lib/presentation/                 │
└──────────────┬─────────────────────┘
               │ depends on ↓
┌──────────────▼─────────────────────┐
│           DATA LAYER               │
│  Repo Impls, DTOs, Data Sources    │
│  lib/data/                         │
└──────────────┬─────────────────────┘
               │ implements interfaces from ↓
┌──────────────▼─────────────────────┐
│           DOMAIN LAYER             │
│  Entities, VOs, Use Cases, Repos   │
│  lib/domain/                       │
└────────────────────────────────────┘
```

**Dependency Rule**: Dependencies point inward only. Domain knows nothing about Data or Presentation.

---

## Domain Layer Rules

### Allowed Imports

- Other `lib/domain/` files
- Pure Dart packages: `equatable`, `dartz`, `meta`

### Forbidden Imports

- `package:flutter/*`
- `package:firebase_*`
- `package:dio/*`, `package:http/*`
- Any `lib/data/*` or `lib/presentation/*` file
- Any Android/iOS platform plugin

**Failure Code**: AF-01

### What Lives Here

- **Entities**: Classes with identity (`AuthChallenge`, `OtpDispatchCommand`, `PaymentObservationSession`)
- **Value Objects**: Immutable, identity-free (`AgentDecision`, `SignedChallengeResponse`, `SmsDeliveryReport`)
- **Repository Interfaces**: Abstract contracts (`AuthChallengeRepository`, `OtpGatewayRepository`)
- **Use Cases**: Single-responsibility, single public method (`execute` or `call`)
- **Service Interfaces**: `SigningService`, `SmsParsingService`, `AuditLogService`, `NonceGenerator`

---

## Data Layer Rules

### Allowed Imports

- `lib/domain/` interfaces
- Third-party: `dio`, `firebase_messaging`, `sqflite`, `flutter_secure_storage`

### Forbidden Imports

- `lib/presentation/*`

### What Lives Here

- **Repository Implementations**: Concrete implementations of domain interfaces
- **Remote Data Sources**: HTTP calls via Dio
- **Local Data Sources**: Encrypted storage, SQLite
- **DTOs**: JSON mapping classes (suffix: `Dto`)
- **Mappers**: `Dto → Entity` and `Entity → Dto` conversion

### Mapping Rule (Mandatory)

```txt
JSON → DTO → Entity     (inbound)
Entity → DTO → JSON     (outbound)
```

No domain entity is ever returned raw from a network response.

---

## Presentation Layer Rules

### Allowed Imports

- `lib/domain/` (use cases and entities only)
- `lib/data/` (DI wiring only, never direct data source calls)
- `package:flutter/*`
- State management: `package:flutter_bloc` (Cubit only) **OR** `package:riverpod` — not both

### Forbidden Imports

- Direct instantiation of repository implementations
- Direct HTTP calls
- Business logic (if/else that implements a business rule)

---

## Shared Infrastructure

```txt
lib/shared/
├── domain/           # SigningService, AuditLogService, NonceGenerator, SmsParsingService
├── data/             # SecureStorage, HttpClientFactory
└── infrastructure/   # AndroidKeystoreSigningService, SmsSenderService, SmsReceiverService
```

- Shared domain: same rules as domain layer
- Shared data: same rules as data layer
- Infrastructure: platform APIs allowed here only

---

## Flutter Project Folder Structure

```txt
lib/
├── domain/
│   ├── auth_2fa/
│   │   ├── entities/
│   │   │   ├── auth_challenge.dart
│   │   │   └── challenge_status.dart
│   │   ├── value_objects/
│   │   │   ├── agent_decision.dart
│   │   │   └── signed_challenge_response.dart
│   │   ├── repositories/
│   │   │   └── auth_challenge_repository.dart
│   │   └── use_cases/
│   │       ├── receive_auth_challenge_use_case.dart
│   │       ├── record_user_decision_use_case.dart
│   │       └── submit_challenge_response_use_case.dart
│   │
│   ├── otp_gateway/
│   │   ├── entities/
│   │   │   ├── otp_dispatch_command.dart
│   │   │   └── dispatch_status.dart
│   │   ├── value_objects/
│   │   │   └── sms_delivery_report.dart
│   │   ├── repositories/
│   │   │   └── otp_gateway_repository.dart
│   │   └── use_cases/
│   │       ├── receive_dispatch_command_use_case.dart
│   │       ├── execute_sms_dispatch_use_case.dart
│   │       └── report_delivery_status_use_case.dart
│   │
│   ├── payment_observation/
│   │   ├── entities/
│   │   │   ├── payment_observation_session.dart
│   │   │   ├── bank_sms_observation.dart
│   │   │   └── session_status.dart
│   │   ├── value_objects/
│   │   │   ├── parsed_payment_data.dart
│   │   │   └── observation_report.dart
│   │   ├── repositories/
│   │   │   └── payment_observation_repository.dart
│   │   └── use_cases/
│   │       ├── register_observation_session_use_case.dart
│   │       ├── process_incoming_sms_use_case.dart
│   │       ├── match_observation_to_intent_use_case.dart
│   │       └── report_observation_use_case.dart
│   │
│   └── pairing/
│       ├── entities/
│       │   ├── paired_system.dart
│       │   └── pairing_token.dart
│       ├── value_objects/
│       │   └── capability_grant.dart
│       ├── repositories/
│       │   └── pairing_repository.dart
│       └── use_cases/
│           ├── scan_pairing_token_use_case.dart
│           ├── complete_pairing_use_case.dart
│           └── unpair_system_use_case.dart
│
├── data/
│   ├── auth_2fa/
│   │   ├── dtos/
│   │   ├── remote/
│   │   └── repositories/
│   ├── otp_gateway/
│   │   ├── dtos/
│   │   ├── remote/
│   │   └── repositories/
│   ├── payment_observation/
│   │   ├── dtos/
│   │   ├── remote/
│   │   └── repositories/
│   └── pairing/
│       ├── dtos/
│       ├── remote/
│       ├── local/
│       └── repositories/
│
├── presentation/
│   ├── auth_2fa/
│   │   ├── cubit/
│   │   └── widgets/
│   ├── otp_gateway/
│   │   └── cubit/
│   ├── payment_observation/
│   │   └── cubit/
│   ├── pairing/
│   │   ├── cubit/
│   │   └── pages/
│   └── dashboard/
│       └── pages/
│
├── shared/
│   ├── domain/
│   ├── data/
│   └── infrastructure/
│
├── di/
│   ├── auth_2fa_module.dart
│   ├── otp_gateway_module.dart
│   ├── payment_observation_module.dart
│   ├── pairing_module.dart
│   └── app_module.dart
│
└── main.dart
```

---

## File Naming Conventions

| Type | Suffix | Example |
| --- | --- | --- |
| Entity | (none) | `auth_challenge.dart` |
| Value Object | (none) | `signed_challenge_response.dart` |
| Use Case | `_use_case` | `receive_auth_challenge_use_case.dart` |
| Repository Interface | `_repository` | `auth_challenge_repository.dart` |
| Repository Impl | `_repository_impl` | `auth_challenge_repository_impl.dart` |
| DTO | `_dto` | `auth_challenge_dto.dart` |
| Remote Source | `_remote_data_source` | `auth_challenge_remote_data_source.dart` |
| Local Source | `_local_data_source` | `auth_challenge_local_data_source.dart` |
| Cubit | `_cubit` | `auth_challenge_cubit.dart` |
| Cubit State | `_state` | `auth_challenge_state.dart` |
