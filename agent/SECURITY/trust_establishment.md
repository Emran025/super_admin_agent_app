# Trust Establishment

> This document defines how a mobile device earns the right to act as an agent for a backend system.
> No trust is implicit. Every agent identity must be explicitly established.

---

## The Pairing Model

Trust is established through a one-time pairing ceremony. After pairing, the device holds a cryptographic identity that the server recognizes for all future interactions.

### Step 1: Server Generates Pairing Token

The server generates a short-lived pairing token containing:

```json
{
  "pairing_token_version": "1",
  "system_id": "<uuid>",
  "system_label": "<human-readable name>",
  "pairing_endpoint": "<https://...>",
  "token": "<signed_jwt_or_random_bytes>",
  "expires_at": "<ISO8601 UTC>",
  "capabilities": ["CAPABILITY_2FA", "CAPABILITY_OTP_GATEWAY", "CAPABILITY_PAYMENT_OBSERVATION"]
}
```

The token is encoded as a QR code and displayed on the server's admin interface.

### Step 2: Mobile Agent Scans QR

The mobile agent:

1. Scans the QR code using the device camera
2. Parses the pairing token payload
3. Validates the token is not expired
4. Presents a confirmation screen to the owner showing `system_label` and `capabilities`

### Step 3: Key Generation

Upon owner confirmation:

1. The agent generates an asymmetric key pair inside the **Android Keystore** (RSA-2048 or EC P-256)
2. The private key never leaves the Keystore — it is hardware-bound
3. The public key is extracted

### Step 4: Registration

The agent sends to the `pairing_endpoint`:

```json
{
  "pairing_token": "<token from QR>",
  "public_key": "<base64 DER-encoded public key>",
  "public_key_algorithm": "EC_P256",
  "device_info": {
    "os": "android",
    "os_version": "<version>",
    "app_version": "<version>"
  }
}
```

### Step 5: Server Acknowledgment

The server:

1. Validates the pairing token (not expired, not already used)
2. Stores the agent's public key associated with the `system_id`
3. Returns:

```json
{
  "agent_id": "<uuid>",
  "system_id": "<uuid>",
  "granted_capabilities": ["CAPABILITY_2FA", "CAPABILITY_OTP_GATEWAY"],
  "fcm_registration_required": true
}
```

### Step 6: Push Token Registration

If `fcm_registration_required: true`, the agent:

1. Registers with FCM to obtain a device push token
2. Sends the push token to the server's device registration endpoint (signed request)

---

## What the Mobile Agent Stores After Pairing (Encrypted)

| Item | Storage | Notes |
| --- | --- | --- |
| Private key | Android Keystore | Hardware-bound, never exported |
| `agent_id` | `flutter_secure_storage` | Used in request headers |
| `system_id` | `flutter_secure_storage` | Identifies which system this agent serves |
| `system_label` | `flutter_secure_storage` | For display only |
| `granted_capabilities` | `flutter_secure_storage` | Determines which DI modules are active |
| Server base URL | `flutter_secure_storage` | The `pairing_endpoint` base |
| Public key ID | `flutter_secure_storage` | Sent with each signed request |

---

## Pairing Token Security Requirements

| Property | Requirement |
| --- | --- |
| Entropy | Minimum 256 bits |
| Expiry | Maximum 10 minutes |
| One-time use | Server marks token as used after first successful registration |
| Transport | HTTPS only (QR is scanned locally; never transmitted over the network) |
| Signing | Token must be signed by the server's own key so the app can verify authenticity |

> `// TODO(arch): Define the server's public key distribution mechanism for QR token signature verification`

---

## Multi-System Support

The agent may be paired with multiple backend systems simultaneously. Each paired system has:

- Its own `agent_id` / `system_id` pair
- Its own capability set
- Its own server base URL
- Its own set of stored nonces (for replay protection per system)

The `PairedSystemRegistry` manages the list of all paired systems. All outbound requests include the `agent_id` specific to the target system.

---

## Unpairing

Unpairing is initiated by the owner and:

1. Deletes all stored data for that system from `flutter_secure_storage`
2. Sends a signed unpair notification to the server (best-effort; proceeds even if the server is unreachable)
3. Does NOT delete the private key if other systems still reference it

> `// TODO(arch): Define whether each paired system uses a separate key pair or a shared device key. Currently: shared device key, system-specific agent_id.`
