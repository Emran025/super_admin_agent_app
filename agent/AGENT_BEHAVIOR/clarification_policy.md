# Clarification Policy

> This document defines when the agent must ask for explicit owner input, versus when it may proceed autonomously.

---

## Principle

The agent may proceed autonomously only when:
1. It has a valid server command
2. All command fields are validated
3. No stop condition is triggered

In all other cases, it asks.

---

## Situations That Require Explicit Owner Action

### 1. 2FA Approval

Every 2FA challenge requires an explicit binary tap (Approve / Reject) from the owner. The agent will never auto-approve, auto-reject, or dismiss a challenge without owner interaction.

**Exception**: None. There are no auto-approve scenarios.

---

### 2. Pairing

The agent will never complete a pairing without the owner:
1. Physically scanning the QR code
2. Reviewing the system label and granted capabilities
3. Confirming with an explicit tap

**Why**: Pairing grants permanent trust. No automatic pairing.

---

### 3. Unpairing

Unpairing requires an explicit owner confirmation. The agent will not unpair in response to a server command alone (unpair must be owner-initiated).

> `// TODO(arch): Confirm whether the server should have any role in initiating unpair — currently: owner-only`

---

### 4. Capability Revocation

If the server sends a signed capability-update command that removes a capability, the agent displays a notification to the owner explaining what was revoked. The update takes effect immediately (no owner approval required), but the owner is always informed.

---

## Situations Where the Agent Acts Autonomously (No Owner Input Required)

| Action | Condition |
| --- | --- |
| Fetch command details after push | Push received from paired system with granted capability |
| Send OTP SMS | Valid `OtpDispatchCommand` received |
| Monitor bank SMS | Active `PaymentObservationSession` registered |
| Report observation | Bank SMS parsed against active session |
| Write audit log | Always (never requires owner input) |
| Report delivery status | After SMS sent |

For OTP and Payment Observation, the owner has implicitly pre-authorized these capabilities by granting them during pairing. Individual dispatch commands do not require per-action approval.

**Exception**: If the device is in low-power mode or the app has been force-stopped, the agent surfaces a warning. It does NOT silently queue actions for later execution without owner awareness.

---

## Ambiguous Situations

If the agent encounters a situation not covered by this policy — for example, a new field in a server payload that appears to request a new type of action — it:

1. Does NOT guess the intent
2. Logs `UNKNOWN_COMMAND_REJECTED`
3. Reports to the server with an `UNRECOGNIZED_COMMAND_TYPE` error code
4. Notifies the owner that an unrecognized command was received

This is a direct application of Axiom 10.
