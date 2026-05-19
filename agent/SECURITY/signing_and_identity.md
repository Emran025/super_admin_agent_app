# Signing and Identity

> This document defines how the mobile agent signs requests and how its identity is cryptographically verifiable.

---

## Device Identity Key

The agent's identity is a single asymmetric key pair generated during pairing and stored in the Android Keystore.

| Property | Value |
| --- | --- |
| Algorithm | EC P-256 (preferred) or RSA-2048 |
| Key Storage | Android Keystore (hardware-backed on supported devices) |
| Private Key Access | Never exported, never transmitted |
| Public Key Distribution | Sent to server once during pairing |

---

## Signing Protocol

Every outbound message from the agent carries a signature. The signing process:

### Input to Signing Function

```txt
message = canonical_json(payload)
nonce   = cryptographically_random_bytes(32)  // 256-bit
timestamp = ISO8601 UTC timestamp

signing_input = message + "\n" + nonce + "\n" + timestamp
```

### Output

```txt
signature = EC_SHA256_sign(private_key, signing_input)
signature_b64 = base64url_encode(signature)
```

### HTTP Headers

All signed requests include:

```txt
X-Agent-Id: <agent_id>
X-Agent-Public-Key-Id: <key_id>
X-Agent-Nonce: <nonce_b64>
X-Agent-Timestamp: <ISO8601>
X-Agent-Signature: <signature_b64>
```

---

## Server Verification Steps

Upon receiving a signed request, the server MUST:

1. Look up the public key for the provided `X-Agent-Id`
2. Verify the `X-Agent-Timestamp` is within ±30 seconds of server time
3. Verify `X-Agent-Nonce` has not been seen before (in a rolling window of at least 5 minutes)
4. Reconstruct the signing input from the canonical request body
5. Verify the `X-Agent-Signature` against the stored public key

If any step fails, the request is rejected with `401 Unauthorized`.

---

## Canonical JSON

To ensure consistent signing, the payload is serialized as canonical JSON before signing:

- Keys sorted alphabetically at every nesting level
- No trailing whitespace
- UTF-8 encoding
- No BOM

The agent uses the same canonical JSON library for all signing operations.

> `// TODO(arch): Select and document the canonical JSON library to use in Flutter`

---

## Key Rotation

> `// TODO(arch): Define key rotation policy — triggered by server command or time-based?`

Current state: No key rotation defined. The pairing key is the permanent device identity key.
When key rotation is defined, it must follow the change process in `CONSTITUTION/04_change_policy.md`.
