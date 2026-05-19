# Replay and Revocation

---

## Replay Protection

Every signed request includes a `nonce` — a unique random value that can only be used once. This prevents an attacker who intercepts a valid signed request from replaying it later.

### Nonce Properties

| Property | Value |
| --- | --- |
| Size | 256 bits (32 bytes) |
| Encoding | Base64url |
| Uniqueness scope | Per agent-system pair |
| Generation | `CryptoRandomNonceGenerator` — uses `dart:math` `Random.secure()` |

### Server Enforcement

The server stores all seen nonces in a rolling window. The window size must be at least:

```txt
expiry_window = max_clock_drift * 2 + max_expected_request_latency
             = 30s + 30s + 10s = 70s (recommended minimum: 5 minutes)
```

Any request arriving with a previously seen nonce is rejected with `409 Conflict`.

### Mobile Agent Responsibility

The mobile agent generates a fresh nonce for every signed request. Nonces are generated immediately before signing, not cached or reused.

---

## Timestamp Drift Window

All signed requests include an `X-Agent-Timestamp`. The server rejects requests where:

```txt
|server_time - agent_timestamp| > 30 seconds
```

This limits the window for a successful replay attack even if nonce storage is compromised.

The mobile agent uses device system time. If the device clock is significantly off, requests will be rejected. The agent must surface this as a user-visible error (not a silent failure).

> `// TODO(arch): Define error UX for clock drift rejection — should the agent display a clock sync warning?`

---

## Revocation

### Scenario 1: Device Lost or Stolen

The owner accesses the server's admin interface and revokes the agent's `agent_id`. The server:

1. Marks the `agent_id` as revoked
2. Rejects all future requests from that `agent_id` with `403 Forbidden`
3. The revocation takes effect immediately for all subsequent requests

### Scenario 2: Capability Revocation

The server can revoke a specific capability without revoking the entire agent identity. The agent receives a signed capability-update command removing the capability from its granted list.

### Scenario 3: Agent-Initiated Unpair

The agent sends a signed unpair request. The server revokes the `agent_id`. Even if the request fails (device offline), the server can independently revoke via the admin interface.

### Scenario 4: Pairing Token Compromise

If a pairing token QR code is exposed before pairing completes, the owner must:

1. Immediately cancel the pairing token via the server admin interface
2. Generate a new pairing token
3. Complete pairing with the new token

The server marks canceled tokens as `REVOKED` — any registration attempt using them fails with `410 Gone`.
