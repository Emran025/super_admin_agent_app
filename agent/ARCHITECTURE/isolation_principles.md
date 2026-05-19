# Isolation Principles

> This document defines how domains are kept isolated from each other, and how platform concerns are kept out of the domain layer.

---

## Why Isolation Matters

If two capabilities share business logic, they become:

- Impossible to replace independently
- Harder to test in isolation
- A single point of failure for unrelated features
- A maintenance hazard (changing OTP breaks 2FA)

Isolation is not an aesthetic preference. It is a load-bearing constraint.

---

## Principle 1: Domain Packages Are Sibling Packages

Each capability domain is treated as if it were a separate Dart package. In practice they live in the same Flutter project, but the import discipline is identical to having package boundaries.

**Enforcement**: A linting rule (or CI check) validates that no file under `lib/domain/auth_2fa/` imports any file under `lib/domain/otp_gateway/` or `lib/domain/payment_observation/`, and vice versa.

> `// TODO(arch): Set up a custom lint rule or CI grep check to enforce cross-domain import prohibition`

---

## Principle 2: Shared Concerns Live in Shared, Not in a Domain

If two domains need the same thing, it goes in `lib/shared/domain/`, not in either domain.

**Examples**:

- `SigningService` — needed by all three domains → `lib/shared/domain/signing_service.dart`
- `AuditLogService` — needed by all three domains → `lib/shared/domain/audit_log_service.dart`
- `NonceGenerator` — needed by all three domains → `lib/shared/domain/nonce_generator.dart`

**Anti-pattern** (forbidden):

- Defining `SigningService` in `auth_2fa` and importing it in `otp_gateway`

---

## Principle 3: Platform APIs Are Isolated at the Infrastructure Boundary

Android and iOS APIs (`SmsManager`, `KeyStore`, `BroadcastReceiver`, `FirebaseMessaging`) are never referenced above `lib/shared/infrastructure/`.

The infrastructure layer maps platform events into domain-neutral types before passing them up:

```txt
Android BroadcastReceiver (SmsMessage)
    ↓  infrastructure maps it
RawSmsEvent (plain Dart class)
    ↓  domain receives it
ProcessIncomingSmsUseCase.execute(rawSmsEvent)
```

This means the domain and all its use cases can be tested on any platform (including a pure Dart test runner) with no Android SDK dependency.

---

## Principle 4: Each Capability Has Its Own Repository Contract

No two capabilities share a repository interface. Each capability defines exactly the data access operations it needs and nothing more.

| Repository | Belongs To | Used Only By |
| --- | --- | --- |
| `AuthChallengeRepository` | `auth_2fa` domain | `auth_2fa` use cases |
| `OtpGatewayRepository` | `otp_gateway` domain | `otp_gateway` use cases |
| `PaymentObservationRepository` | `payment_observation` domain | `payment_observation` use cases |
| `PairingRepository` | `pairing` domain | `pairing` use cases |

---

## Principle 5: Each Capability Has Its Own DI Module

Dependency injection for each capability is scoped to its own module file:

```txt
lib/di/auth_2fa_module.dart          → registers only auth_2fa bindings
lib/di/otp_gateway_module.dart       → registers only otp_gateway bindings
lib/di/payment_observation_module.dart → registers only payment_observation bindings
lib/di/pairing_module.dart           → registers only pairing bindings
lib/di/app_module.dart               → registers shared infrastructure bindings
```

If a capability is disabled (not granted during pairing), its DI module is not initialized.

---

## Principle 6: Capability Activation Is Gated by Pairing

The `PairedSystemRegistry` holds the list of granted capabilities for each paired system. Before any use case for a capability is invoked, the capability activation check is performed at the infrastructure/presentation boundary.

**What this means in practice**:

- If the paired system did not grant `CAPABILITY_OTP_GATEWAY`, no OTP use case is ever invoked
- The `OtpGatewayRepository` is never even instantiated
- The OTP DI module is not loaded

> `// TODO(arch): Decide whether capability gating happens in the DI module initialization or in the push notification handler`

---

## Principle 7: Error Propagation Does Not Cross Domain Boundaries

Each domain defines its own exception types. These exceptions never propagate from one domain to another.

| Domain | Exception Namespace |
| --- | --- |
| `auth_2fa` | `AuthDomainException` and subclasses |
| `otp_gateway` | `OtpDomainException` and subclasses |
| `payment_observation` | `PaymentDomainException` and subclasses |
| `pairing` | `PairingDomainException` and subclasses |

The presentation layer receives typed failures via `Either<Failure, Result>` (using `dartz`), not raw exceptions.
