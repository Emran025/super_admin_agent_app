# Mobile Agent Invariants: Push-Based 2FA

> These are behavioral guarantees the mobile agent provides unconditionally, regardless of server state or network conditions.
> They are enforced structurally in the domain and data layers, not by runtime checks in the presentation layer.

---

## Invariant 1: No Challenge Is Processed Without a Valid `challenge_id`

The mobile agent will never attempt to display an approval dialog or produce a signed response unless a `challenge_id` string has been received and a corresponding `AuthChallenge` has been successfully fetched from the server.

**Enforced by**: `ReceiveAuthChallengeUseCase` — throws `InvalidChallengeException` if fetch fails.

---

## Invariant 2: Only Binary Decisions Exist

The agent will never produce a response that is neither APPROVE nor REJECT. There is no "maybe," "timeout," or "defer" decision state on the mobile side.

If the user dismisses the dialog without tapping a button, the challenge remains in `PENDING` state on the device until the server marks it `EXPIRED`. No response is sent.

**Enforced by**: `AgentDecision` value object — sealed enum with exactly two values.

---

## Invariant 3: Every Response Is Signed

The agent will never call `SubmitChallengeResponseUseCase` with an unsigned payload. The `SignedChallengeResponse` cannot be constructed without a valid signature from the `SigningService`.

**Enforced by**: `SignedChallengeResponse` constructor requires a non-empty `signature` string. The `SigningService` interface is the only way to produce it.

---

## Invariant 4: Every Response Carries a Fresh Nonce

The agent will never reuse a nonce. A new cryptographically random nonce is generated per signing operation.

**Enforced by**: `NonceGenerator` service, called inside `RecordUserDecisionUseCase`. The nonce is not user-configurable.

---

## Invariant 5: A Responded Challenge Cannot Be Responded To Again

Once a challenge has been marked `RESPONDED` locally, the agent will not present it to the user again and will not produce another signed response for it.

**Enforced by**: `RecordUserDecisionUseCase` — checks `challenge.status == ChallengeStatus.PENDING` before proceeding. Throws `ChallengeAlreadyRespondedException` otherwise.

---

## Invariant 6: The Presentation Layer Receives Only Safe Data

The mobile agent's UI receives only:

- `contextLabel` (human-readable string from the server, displayed as-is)
- `expiresAt` (used to render a countdown)
- `challengeId` (displayed for user reference only, not actionable)

The UI does not receive:

- The private key
- The signature
- The nonce
- Any raw server response object

**Enforced by**: Use case return types — presentation layer receives domain entities, never DTOs or raw API objects.

---

## Invariant 7: One Active Challenge at a Time

The agent will only hold one challenge in `PENDING` state at a time. If a second challenge arrives while one is pending, the behavior is:

- Display the new challenge
- Mark the first as `SUPERSEDED` locally
- Do NOT send any response for the superseded challenge (server will handle expiry)

> `// TODO(arch): Confirm with server team whether multiple concurrent challenges should be supported. Currently capped at 1.`

---

## Invariant 8: Audit Log Entry Is Written Before Response Is Submitted

The local audit log entry for the challenge response is written **before** the network call to submit the response. If the submission fails, the log entry remains with status `SUBMISSION_FAILED`.

**Enforced by**: `SubmitChallengeResponseUseCase` — writes log entry as first action, then performs network submission.
