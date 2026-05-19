# Failure Definitions

> This document defines exactly what constitutes an architectural failure in this system.
> A failure is not a bug to be fixed later — it is a blocker that prevents the system from being used.

---

## Failure Classification

| Class | Description | Action Required |
| --- | --- | --- |
| **Critical** | Violates security model or trust hierarchy | Immediate halt. No production use until resolved. |
| **Architectural** | Violates Clean Architecture layering | Must be resolved before next release. |
| **Policy** | Violates a stated policy without security impact | Tracked as a debt item. Must be resolved within one version. |

---

## Critical Failures

### CF-01: Plaintext Secret Storage

**Definition**: Any secret (private key, pairing token, API credential, session token) is stored in a location readable without decryption.

**Examples**:

- Private key written to `SharedPreferences`
- Pairing token stored in SQLite without encryption
- Any secret appearing in a log file

**Consequence**: The system's cryptographic identity is compromised. The entire deployment must be considered untrusted.

---

### CF-02: Unsigned Server Response

**Definition**: The mobile agent sends a response to any server without signing it with the device-bound private key.

**Examples**:

- 2FA decision sent as a plain HTTP body without a `X-Agent-Signature` header
- OTP delivery status reported without a signature
- Payment observation reported without a signature

**Consequence**: The server cannot verify the response came from the legitimate agent. Replay and forgery attacks become possible.

---

### CF-03: Communication with Unpaired System

**Definition**: The mobile agent sends any data to a system not registered in the `PairedSystemRegistry`.

**Examples**:

- A hardcoded URL that bypasses the registry
- A "convenience" direct API call in a use case
- A third-party analytics SDK that exfiltrates data

**Consequence**: Data exfiltration risk. Complete compromise of confidentiality guarantees.

---

### CF-04: Self-Initiated Business Decision

**Definition**: The mobile agent makes any decision that the specification assigns to the server.

**Examples**:

- Approving a 2FA challenge automatically without user interaction
- Treating a received OTP as valid
- Deciding a payment observation constitutes payment confirmation

**Consequence**: The trust model is broken. The server's authority is bypassed.

---

### CF-05: Capability Used Without Server Command

**Definition**: A capability (2FA, OTP, Payment) is activated without a corresponding valid server command bearing a command ID.

**Examples**:

- Sending an OTP SMS because the app received a push notification without a verified command payload
- Monitoring bank SMS without an active payment observation session registered by the server

**Consequence**: The audit trail is broken. Actions cannot be attributed to a server-authorized event.

---

## Architectural Failures

### AF-01: Domain Layer Import of External Framework

**Definition**: Any file in `lib/domain/` contains an import from Flutter, Firebase, Android APIs, or any third-party library.

**Examples**:

- `import 'package:flutter/material.dart'` in a use case file
- `import 'package:firebase_messaging/firebase_messaging.dart'` in a domain entity

**Consequence**: The domain becomes untestable in isolation and tightly coupled to a specific platform.

---

### AF-02: Cross-Capability Business Logic Dependency

**Definition**: A use case or entity in one capability imports from or depends on the domain of another capability.

**Examples**:

- `OtpGatewayUseCase` importing `AuthChallenge` entity
- `PaymentObservationUseCase` using `OtpDispatchRequest`

**Consequence**: Capabilities are no longer independently replaceable or testable.

---

### AF-03: Presentation Layer Business Rule

**Definition**: Any widget, Cubit, or Riverpod provider contains conditional logic that implements a business rule.

**Examples**:

- A widget that decides whether to show an approval button based on challenge expiry
- A Cubit that validates OTP format before sending to use case

**Consequence**: Business logic is duplicated and cannot be tested without Flutter.

---

### AF-04: Repository Implementation in Domain Layer

**Definition**: A concrete implementation of a repository (network calls, database access) appears in the domain layer.

**Examples**:

- `AuthChallengeRepository` directly calling `http.get()`
- A use case that directly instantiates a `Dio` client

**Consequence**: Domain cannot be tested without network mocking. Dependency direction is inverted.

---

## Policy Failures

### PF-01: Missing Log Entry

**Definition**: An action listed in `CONSTITUTION/02_allowed_vs_forbidden.md` as "allowed" executes without producing a log entry.

---

### PF-02: Hardcoded System Reference

**Definition**: Any server URL, system name, or system-specific identifier appears as a string literal in source code.

---

### PF-03: Missing TODO Marker

**Definition**: A placeholder or incomplete implementation exists in source code without a `// TODO(arch):` marker referencing the relevant specification document.

---

## How to Report a Failure

1. Identify the failure class and code (e.g., AF-01)
2. Document the exact file path and line number
3. Do NOT deploy or release until Critical and Architectural failures are resolved
4. Log the resolution in the commit message with the failure code (e.g., `fix(arch): resolve AF-01 in auth domain`)
