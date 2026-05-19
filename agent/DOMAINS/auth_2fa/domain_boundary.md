# Domain Boundary: Push-Based 2FA Approval

## Domain Identity

| Property | Value |
| --- | --- |
| Domain Name | `auth_2fa` |
| Flutter Package Path | `lib/domain/auth_2fa/` |
| Capability ID | `CAPABILITY_2FA` |

---

## What This Domain Owns

This domain is solely responsible for the lifecycle of a single user-approval event triggered by a server-generated authentication challenge.

It owns:

- The `AuthChallenge` entity
- The `AgentDecision` value object
- The `SignedChallengeResponse` value object
- The `AuthChallengeRepository` interface
- All use cases related to receiving, displaying, and responding to challenges

---

## What This Domain Does NOT Own

This domain does not own, import, or depend on:

- OTP generation, dispatch, or delivery (→ `otp_gateway` domain)
- Payment intents or bank SMS parsing (→ `payment_observation` domain)
- Pairing and identity management (→ `pairing` shared service)
- Cryptographic signing implementation (→ `signing` infrastructure service)
- Push notification delivery (→ infrastructure layer)
- Any Flutter widget or platform API

---

## Domain Entry Points

External layers interact with this domain **only** through these use case interfaces:

| Use Case | Input | Output |
| --- | --- | --- |
| `ReceiveAuthChallengeUseCase` | `challenge_id: String` | `AuthChallenge` |
| `RecordUserDecisionUseCase` | `AuthChallenge`, `AgentDecision` | `SignedChallengeResponse` |
| `SubmitChallengeResponseUseCase` | `SignedChallengeResponse` | `SubmissionResult` |

No other entry points exist. Calling a repository directly from outside the domain is forbidden.

---

## Domain Boundary Rules

### Inbound (What may enter this domain)

- A `challenge_id` string from the infrastructure layer (push notification handler)
- An explicit `AgentDecision` (APPROVE or REJECT) from the presentation layer

### Outbound (What may leave this domain)

- A `SignedChallengeResponse` destined for the server
- A `SubmissionResult` (success or failure code) returned to the presentation layer
- A log entry for the audit service

### What May NOT cross the boundary

- Raw HTTP responses
- Firebase message objects
- Any Android/iOS platform type
- Any widget state

---

## Invariants (Always True)

1. An `AuthChallenge` without a valid `challenge_id` does not exist.
2. A `SignedChallengeResponse` is always constructed from an existing `AuthChallenge`, never independently.
3. `AgentDecision` has exactly two states: `APPROVE` and `REJECT`. No other state exists.
4. A challenge that has already been responded to cannot be responded to again (idempotency enforced by server; domain marks it locally as `RESPONDED`).
5. The domain never times out a challenge. Timeout enforcement is the server's responsibility.

---

## Entities and Value Objects

### Entity: `AuthChallenge`

| Field | Type | Description |
| --- | --- | --- |
| `challengeId` | `String` | Unique server-generated ID |
| `systemId` | `String` | ID of the issuing paired system |
| `issuedAt` | `DateTime` | When the server created this challenge |
| `expiresAt` | `DateTime` | Server-defined expiry (display only; not enforced by app) |
| `contextLabel` | `String` | Human-readable context (e.g., "Login from Chrome on Windows") |
| `status` | `ChallengeStatus` | `PENDING`, `RESPONDED`, `EXPIRED_REMOTE` |

### Value Object: `AgentDecision`

Enumeration: `APPROVE` | `REJECT`

### Value Object: `SignedChallengeResponse`

| Field | Type | Description |
| --- | --- | --- |
| `challengeId` | `String` | Echo of the original challenge ID |
| `decision` | `AgentDecision` | The user's decision |
| `respondedAt` | `DateTime` | Timestamp of signing |
| `nonce` | `String` | Anti-replay nonce |
| `signature` | `String` | Base64-encoded device signature |
| `agentPublicKeyId` | `String` | Identifies which key was used |

---

## Use Case Sequence (Text)

```txt
[Push arrives] → infrastructure layer extracts challenge_id
    ↓
ReceiveAuthChallengeUseCase(challenge_id)
    → calls AuthChallengeRepository.fetchChallenge(challenge_id)
    → returns AuthChallenge
    ↓
[Presentation layer displays dialog to user]
    ↓
RecordUserDecisionUseCase(challenge, decision)
    → validates challenge is still PENDING
    → builds SignedChallengeResponse using SigningService
    → returns SignedChallengeResponse
    ↓
SubmitChallengeResponseUseCase(signedResponse)
    → calls AuthChallengeRepository.submitResponse(signedResponse)
    → returns SubmissionResult
    → writes audit log entry
```

---

## TODO

- `// TODO(arch): Define retry behavior if submission fails — must be server-directed, not app-initiated`
- `// TODO(arch): Define behavior when push arrives for an already-RESPONDED challenge`
- `// TODO(arch): Confirm whether contextLabel is HTML-escaped server-side or must be sanitized here`
