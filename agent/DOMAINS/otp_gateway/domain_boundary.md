# Domain Boundary: SMS OTP Gateway

## Domain Identity

| Property | Value |
| --- | --- |
| Domain Name | `otp_gateway` |
| Flutter Package Path | `lib/domain/otp_gateway/` |
| Capability ID | `CAPABILITY_OTP_GATEWAY` |

---

## What This Domain Owns

This domain is solely responsible for receiving an OTP dispatch command from the server and delivering the pre-rendered SMS to the designated recipient via the device SIM.

It owns:

- The `OtpDispatchCommand` entity
- The `SmsDeliveryReport` value object
- The `OtpGatewayRepository` interface
- All use cases related to receiving dispatch commands, sending SMS, and reporting delivery

---

## What This Domain Does NOT Own

- The OTP value itself (the server generates it; the app receives a pre-rendered template)
- OTP validation logic (server-only)
- Contact management logic (infrastructure concern)
- 2FA challenges or payment intents
- Any Flutter widget or Android/iOS API

---

## Domain Entry Points

| Use Case | Input | Output |
| --- | --- | --- |
| `ReceiveDispatchCommandUseCase` | `command_id: String` | `OtpDispatchCommand` |
| `ExecuteSmsDispatchUseCase` | `OtpDispatchCommand` | `SmsDeliveryReport` |
| `ReportDeliveryStatusUseCase` | `SmsDeliveryReport` | `ReportResult` |

---

## Domain Boundary Rules

### Inbound

- A `command_id` from the infrastructure layer (push notification handler)
- An SMS delivery status event from the platform SMS service (via infrastructure interface)

### Outbound

- An SMS sent via the device SIM (infrastructure action)
- A `SmsDeliveryReport` sent to the server
- An audit log entry

### What May NOT Cross the Boundary

- The raw OTP digit string (the domain only handles the pre-rendered message body)
- Any indication of OTP validity
- Any data from the 2FA or payment domains

---

## Critical Design Constraint: The App Does Not Know the OTP

The server renders the SMS message body before sending the dispatch command. The mobile agent receives a `messageBody` string and treats it as opaque content to be delivered.

**The domain never parses the message body. It never extracts, stores, or logs the OTP digits.**

This is not a performance optimization. It is a security boundary. If the app knew the OTP, it could be extracted from memory or logs.

> **Implementation Note**: The `messageBody` field in `OtpDispatchCommand` must be treated as a write-only delivery payload. It is passed directly to the SMS infrastructure service and then discarded from memory. It is NEVER written to persistent storage.

---

## Invariants

1. `OtpDispatchCommand` is invalid if it has no `command_id`, no `recipientPhoneNumber`, and no `messageBody`.
2. The `messageBody` is never logged, stored, or displayed in any UI.
3. A dispatch command that has already been executed (`status == DISPATCHED`) cannot be re-dispatched without a new command from the server.
4. Delivery failure does not trigger a retry in the app. The server must re-issue a new dispatch command.
5. The domain reports delivery status using platform-native delivery receipt codes, mapped to its own `SmsDeliveryStatus` enum.

---

## Entities and Value Objects

### Entity: `OtpDispatchCommand`

| Field | Type | Description |
| --- | --- | --- |
| `commandId` | `String` | Unique server-generated command ID |
| `systemId` | `String` | ID of the issuing paired system |
| `recipientPhoneNumber` | `String` | E.164 formatted phone number |
| `messageBody` | `String` | Pre-rendered SMS body (opaque; contains OTP) |
| `simSlot` | `SimSlot?` | Optional: which SIM to use (DEFAULT, SIM_1, SIM_2) |
| `issuedAt` | `DateTime` | When the command was issued |
| `status` | `DispatchStatus` | `PENDING`, `DISPATCHED`, `FAILED` |

### Value Object: `SmsDeliveryReport`

| Field | Type | Description |
| --- | --- | --- |
| `commandId` | `String` | Echo of the command ID |
| `status` | `SmsDeliveryStatus` | `SENT`, `DELIVERED`, `FAILED_NO_SERVICE`, `FAILED_GENERIC` |
| `reportedAt` | `DateTime` | Timestamp |
| `nonce` | `String` | Anti-replay nonce |
| `signature` | `String` | Device signature |

---

## TODO

- `// TODO(arch): Define behavior when device has dual SIM and simSlot is not specified`
- `// TODO(arch): Define maximum messageBody length — enforce at domain level or delegate to infrastructure?`
- `// TODO(arch): Contact creation is infrastructure-level; confirm whether OtpDispatchCommand should carry a displayName field`
