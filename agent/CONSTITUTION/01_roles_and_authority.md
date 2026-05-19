# Roles and Authority

> This document defines exactly who decides, who executes, and who is prohibited from acting.
> Authority boundaries are enforced by design, not by trust.

---

## The Three Roles

### 1. The Owner

The human who physically controls the device and operates the backend system(s).

**Authority:**

- Owns the private key material (via physical device control)
- Can initiate or revoke pairing
- Can shut down or wipe the agent
- Can modify the backend system

**Limitations:**

- Cannot bypass the server's command protocol from the mobile app side
- Cannot grant capabilities to the mobile app without going through the pairing protocol
- Cannot add new capabilities by modifying the mobile app alone

---

### 2. The Server (Backend System)

One or more trusted backend systems that have been successfully paired with this agent.

**Authority:**

- Generates all commands sent to the mobile agent
- Defines the template and content of OTP messages
- Decides validity of 2FA challenges
- Decides validity of payment observations
- Grants and revokes capabilities via pairing protocol
- Sets timeouts, retry limits, and expiration windows

**Limitations:**

- Cannot read private keys stored in the Android Keystore
- Cannot force the mobile agent to skip signature verification
- Cannot bypass the replay protection nonce check
- Cannot instruct the mobile agent to store secrets in plaintext

---

### 3. The Mobile Agent (This Application)

The Flutter application running on the owner's device.

**Authority:**

- Receives and parses server commands
- Displays native approval dialogs to the owner
- Signs responses with the device-bound key
- Sends SMS using the device SIM
- Reads incoming SMS from designated senders
- Reports observations to the server

**Limitations (hard-coded, non-overridable):**

- Cannot create or manage sessions
- Cannot validate OTP codes
- Cannot confirm or reject payments
- Cannot make business decisions
- Cannot self-assign capabilities
- Cannot communicate with unpaired systems

---

## Decision Matrix

| Decision | Owner | Server | Mobile Agent |
| --- | --- | --- | --- |
| Initiate pairing | ✅ (physical scan) | ✅ (generates token) | ❌ |
| Grant capability | ❌ | ✅ | ❌ |
| Revoke capability | ❌ | ✅ | ❌ |
| Generate 2FA challenge | ❌ | ✅ | ❌ |
| Approve/Reject 2FA | ✅ (physical tap) | ❌ | Signs & relays |
| Validate 2FA response | ❌ | ✅ | ❌ |
| Generate OTP | ❌ | ✅ | ❌ |
| Send OTP SMS | ❌ | Commands | ✅ (executes) |
| Validate OTP | ❌ | ✅ | ❌ |
| Define payment intent | ❌ | ✅ | ❌ |
| Parse bank SMS | ❌ | ❌ | ✅ (observes) |
| Confirm payment | ❌ | ✅ | ❌ |

---

## Authority Enforcement Mechanisms

These are not policies — they are structural constraints baked into the architecture:

| Constraint | How Enforced |
| --- | --- |
| Mobile cannot self-approve challenges | Use case layer has no validation logic |
| Mobile cannot send unsigned responses | `SignedResponseBuilder` is the only output path |
| Mobile cannot store plaintext secrets | `SecureStorage` is the only allowed persistence API for secrets |
| Mobile cannot communicate with unknown systems | `PairedSystemRegistry` gates all outbound communication |
| Capabilities cannot be self-assigned | Capability list is read-only after pairing |

---

## What Happens When Authority Is Violated

If any code path is found that allows the mobile agent to:

- Make a decision that belongs to the server
- Act without a signed server command
- Communicate with an unregistered system

It is classified as a **Critical Architectural Failure** (see `CONSTITUTION/03_failure_definitions.md`) and must be remediated before the system is used in any environment.
