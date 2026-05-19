# Domain Boundary: Payment Observation via Bank SMS

## Domain Identity

| Property | Value |
| --- | --- |
| Domain Name | `payment_observation` |
| Flutter Package Path | `lib/domain/payment_observation/` |
| Capability ID | `CAPABILITY_PAYMENT_OBSERVATION` |

---

## What This Domain Owns

This domain is solely responsible for monitoring incoming SMS messages from a designated bank sender, parsing relevant fields, and reporting observations to the server.

It owns:

- The `PaymentObservationSession` entity
- The `BankSmsObservation` entity
- The `ParsedPaymentData` value object
- The `ObservationReport` value object
- The `PaymentObservationRepository` interface
- All use cases for receiving sessions, parsing SMS, matching intents, and reporting

---

## What This Domain Does NOT Own

- Payment confirmation logic (server-only)
- Credit/debit operations (server-only)
- OTP dispatch or 2FA challenges
- The bank's SMS format (received as a parsing template from the server)
- The full SMS body after parsing (discarded post-parse)

---

## Domain Entry Points

| Use Case | Input | Output |
| --- | --- | --- |
| `RegisterObservationSessionUseCase` | `session_id: String` | `PaymentObservationSession` |
| `ProcessIncomingSmsUseCase` | `rawSmsEvent: RawSmsEvent`, `activeSession: PaymentObservationSession` | `BankSmsObservation?` |
| `MatchObservationToIntentUseCase` | `BankSmsObservation`, `PaymentObservationSession` | `ObservationMatchResult` |
| `ReportObservationUseCase` | `ObservationReport` | `ReportResult` |

---

## Critical Design Constraint: Mobile NEVER Confirms Payment

The mobile agent produces an `ObservationReport` that contains:

- Extracted payer name
- Extracted amount
- Whether it matched the expected intent (field: `isMatch: bool`)

**The `isMatch` field is informational only.** It tells the server "the extracted values match what you told me to expect." The server decides whether to actually confirm the payment.

The mobile agent has no concept of "payment confirmed," "payment rejected," or "account credited."

---

## What Gets Parsed vs. What Gets Stored

| Data | Parsed? | Stored? | Logged? | Reported? |
| --- | --- | --- | --- | --- |
| Full raw SMS body | ✅ | ❌ Never | ❌ Never | ❌ Never |
| Payer name | ✅ | ✅ In session memory only | Hash only | ✅ |
| Amount | ✅ | ✅ In session memory only | ✅ | ✅ |
| Sender name | ✅ (for filtering) | ❌ | ❌ | ❌ |
| Unrecognized SMS fields | ❌ | ❌ | ❌ | ❌ |

**The full raw SMS body is never persisted or transmitted.**

---

## Domain Boundary Rules

### Inbound

- A `session_id` from the infrastructure layer when the server opens an observation session
- A `RawSmsEvent` from the infrastructure SMS receiver (contains sender, body, timestamp)

### Outbound

- An `ObservationReport` sent to the server
- An audit log entry (action type + intent_id + match result hash)

### What May NOT Cross the Boundary

- The raw SMS body
- Any OTP or 2FA data
- Any Android `SmsMessage` object (must be mapped to `RawSmsEvent` at infrastructure boundary)

---

## Entities and Value Objects

### Entity: `PaymentObservationSession`

| Field | Type | Description |
| --- | --- | --- |
| `sessionId` | `String` | Server-generated session ID |
| `systemId` | `String` | ID of the issuing paired system |
| `intentId` | `String` | Payment intent ID on the server |
| `expectedSenderName` | `String` | Bank sender name to filter SMS (e.g., "Bank-XYZ") |
| `parsingTemplate` | `String` | Regex or template string for extracting fields |
| `expectedPayerName` | `String?` | Optional: name to match against |
| `expectedAmount` | `Decimal` | Amount to match against |
| `expectedCurrency` | `String` | 3-letter ISO currency code |
| `expiresAt` | `DateTime` | Server-defined observation window end |
| `status` | `SessionStatus` | `ACTIVE`, `MATCHED`, `EXPIRED`, `REPORTED` |

### Entity: `BankSmsObservation`

| Field | Type | Description |
| --- | --- | --- |
| `observationId` | `String` | Locally generated UUID |
| `sessionId` | `String` | Parent session ID |
| `receivedAt` | `DateTime` | When the SMS arrived |
| `parsedPayerName` | `String?` | Extracted payer name |
| `parsedAmount` | `Decimal?` | Extracted amount |
| `parsedCurrency` | `String?` | Extracted currency |

### Value Object: `ObservationReport`

| Field | Type | Description |
| --- | --- | --- |
| `sessionId` | `String` | |
| `intentId` | `String` | |
| `observationId` | `String` | |
| `parsedPayerName` | `String?` | |
| `parsedAmount` | `Decimal?` | |
| `parsedCurrency` | `String?` | |
| `isMatch` | `bool` | Whether extracted data matches expected |
| `reportedAt` | `DateTime` | |
| `nonce` | `String` | |
| `signature` | `String` | |

---

## Parsing Template Design

The `parsingTemplate` is provided by the server. The domain uses it as input to a `SmsParsingService` interface. The interface is defined in the domain; the implementation is in the data layer.

This means:

- The parsing algorithm can be changed (regex → ML → NLP) without touching the domain.
- The domain only knows about `ParsedPaymentData` (structured output), not parsing mechanics.

> `// TODO(arch): Define the parsing template format — regex string, JSON schema, or a versioned template protocol`

---

## TODO

- `// TODO(arch): Define behavior when multiple SMS arrive during one observation session`
- `// TODO(arch): Define behavior when parsedAmount cannot be converted to Decimal (malformed SMS)`
- `// TODO(arch): Define how observation session expiry interacts with an SMS that arrives exactly at expiry boundary`
