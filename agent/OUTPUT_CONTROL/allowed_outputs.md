# Allowed Outputs

> This document defines every category of output the mobile agent is permitted to produce.
> "Output" means: data sent over a network, data written to storage, data displayed in the UI, or SMS sent via SIM.

---

## Category 1: Network Outputs (to Paired Servers Only)

All network outputs are signed. All go to paired servers only.

| Output | Endpoint | Contains |
| --- | --- | --- |
| Pairing registration | `POST /v1/pair` | Public key, device info, pairing token |
| FCM token registration | `POST /v1/devices/fcm` | FCM token |
| Challenge response | `POST /v1/challenges/{id}/respond` | Decision, signature, nonce, timestamp |
| OTP delivery report | `POST /v1/otp-commands/{id}/report` | Delivery status, signature, nonce |
| Payment observation report | `POST /v1/payment-sessions/{id}/report` | Parsed fields, is_match, signature, nonce |
| Audit log export | `POST /v1/logs/export` | Signed, serialized log entries |
| Unpair notification | `POST /v1/agents/{id}/unpair` | Signed unpair request |

---

## Category 2: SMS Outputs (via Device SIM)

| Output | Trigger | Contains |
| --- | --- | --- |
| OTP SMS | Valid `OtpDispatchCommand` | Pre-rendered `message_body` from server command only |

**Constraints**:

- Sent to the `recipient_phone_number` from the command
- No modifications to `message_body`
- No appended metadata

---

## Category 3: Local Storage Outputs (Encrypted)

| Written | Location | Contents |
| --- | --- | --- |
| Paired system config | `flutter_secure_storage` | system_id, agent_id, base URL, capabilities |
| Audit log entries | Encrypted SQLite | Action type, command_id, timestamp, outcome |
| Active session state | In-memory only (never persisted) | PaymentObservationSession while ACTIVE |

---

## Category 4: UI Outputs

| Displayed | Screen | Data Shown |
| --- | --- | --- |
| 2FA approval dialog | System-level dialog | context_label, expires_at, challenge_id |
| Pairing confirmation | Pairing page | system_label, capabilities list |
| Capability status | Dashboard | Capability names and current status |
| Error messages | Inline / overlay | Error code + human-readable message |
| Audit log summary | Owner-facing log view | action_type, timestamp, outcome (no raw SMS, no OTP) |

---

## Category 5: Notification Outputs

| Notification | Trigger | Content |
| --- | --- | --- |
| 2FA approval required | Push received | "Approval request from [system_label]" |
| OTP dispatched | Successful SMS send | "OTP sent to +xxx" (last 4 digits only) |
| Payment SMS received | Bank SMS observed | "Payment observation completed for [intent_id]" |
| Error notification | Any failure | "Action failed: [error_code]" |
