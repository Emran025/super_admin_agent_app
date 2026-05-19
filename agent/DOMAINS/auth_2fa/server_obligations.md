# Server Obligations: Push-Based 2FA

> This document defines what the server MUST do, MUST NOT do, and MUST guarantee for the 2FA domain to function correctly.
> If the server does not fulfill these obligations, the mobile agent's behavior is undefined.

---

## Server Must: Before Sending Push

1. **Generate a cryptographically random `challenge_id`** (minimum 128-bit entropy, URL-safe base64 encoded).
2. **Store the challenge** in its own persistence layer with:
   - `challenge_id`
   - Issuing user/session context
   - `issued_at` timestamp (UTC)
   - `expires_at` timestamp (UTC, server-defined, recommended: 120 seconds)
   - Status: `PENDING`
3. **Set a timeout job** to mark the challenge as `EXPIRED` if no response is received before `expires_at`.
4. **Construct the push notification payload** containing only the `challenge_id`. The push payload must NOT contain the challenge details.
5. **Send the push notification** to the registered device token for the paired agent.

---

## Server Must: Challenge Detail Endpoint

When the mobile agent calls `GET /challenges/{challenge_id}`:

1. Verify the request is signed by the registered agent public key.
2. Verify the challenge exists and belongs to the requesting agent's `system_id`.
3. Return the challenge details (see `SERVER_CONTRACTS/auth_2fa_contract.md`).
4. If the challenge is already `EXPIRED` or `RESPONDED`, return the current status — do NOT return `404`.

---

## Server Must: Response Endpoint

When the mobile agent calls `POST /challenges/{challenge_id}/respond`:

1. Verify the request signature using the stored agent public key.
2. Verify the `nonce` has not been seen before (replay protection).
3. Verify `responded_at` is within an acceptable clock drift window (recommended: ±30 seconds).
4. Verify the challenge is still in `PENDING` status.
5. Record the decision.
6. Update challenge status to `RESPONDED`.
7. Proceed with the downstream business logic (e.g., authorize the login session).

---

## Server Must NOT

- Include OTP values, account data, or payment information in challenge payloads.
- Send more than one `PENDING` challenge per agent at a time (recommended; implementation policy at server discretion).
- Reuse a `challenge_id` for any reason.
- Accept a response after the challenge has `EXPIRED`.
- Accept a response with a previously seen nonce.
- Trust a response without a valid signature.

---

## Server Guarantees

| Guarantee | Details |
| --- | --- |
| `challenge_id` uniqueness | Globally unique per deployment |
| Expiry enforcement | Server marks expired challenges; app only displays the expiry for UX |
| Nonce storage | Server stores used nonces for at least the duration of the expiry window + clock drift buffer |
| Status transitions | `PENDING` → `RESPONDED` or `PENDING` → `EXPIRED` (never back to `PENDING`) |
| Push payload minimalism | Push payload contains `challenge_id` only — no sensitive content in FCM/APNS payload |

---

## Failure Modes the Server Must Handle

| Failure | Expected Server Behavior |
| --- | --- |
| Agent sends duplicate response | Reject with `409 Conflict` |
| Agent sends response for expired challenge | Reject with `410 Gone` |
| Agent sends response with bad signature | Reject with `401 Unauthorized` |
| Agent sends response with seen nonce | Reject with `409 Conflict` |
| Push notification not delivered | Server's responsibility to implement a fallback (e.g., polling endpoint) |
| Agent offline during challenge | Challenge expires server-side; server handles downstream consequence |
