# Audit and Logs

---

## Purpose

The audit log exists to answer: **"What did the agent do, when, and with what outcome?"**

It is not a debugging log. It is a compliance artifact.

---

## What Is Logged

Every action in `CONSTITUTION/02_allowed_vs_forbidden.md` that is listed as "allowed" produces a log entry when executed.

### Mandatory Fields (Every Entry)

| Field | Type | Description |
| --- | --- | --- |
| `entry_id` | UUID | Locally generated unique ID for this log entry |
| `action_type` | Enum | See Action Types below |
| `system_id` | String | Which paired system this action belongs to |
| `command_id` | String? | The server command ID that triggered this action (null for pairing events) |
| `timestamp` | ISO8601 UTC | When the action occurred |
| `outcome` | Enum | `SUCCESS`, `FAILURE`, `PARTIAL` |
| `failure_code` | String? | Error code if outcome is FAILURE |

### Action Types

| Action Type | Triggered By |
| --- | --- |
| `PAIRING_COMPLETED` | Successful pairing ceremony |
| `PAIRING_FAILED` | Failed pairing attempt |
| `UNPAIRING_COMPLETED` | Successful unpair |
| `CHALLENGE_RECEIVED` | 2FA challenge fetched |
| `CHALLENGE_RESPONDED` | Signed response submitted |
| `CHALLENGE_SUBMISSION_FAILED` | Response submission failed |
| `OTP_DISPATCH_RECEIVED` | OTP command fetched |
| `OTP_SMS_SENT` | SMS dispatched |
| `OTP_SMS_FAILED` | SMS dispatch failed |
| `OTP_REPORT_SUBMITTED` | Delivery report sent |
| `PAYMENT_SESSION_OPENED` | Observation session registered |
| `PAYMENT_SMS_OBSERVED` | Matching bank SMS received and parsed |
| `PAYMENT_PARSE_FAILED` | Bank SMS could not be parsed |
| `PAYMENT_REPORT_SUBMITTED` | Observation report sent |
| `UNKNOWN_COMMAND_REJECTED` | Unrecognized command received and rejected |

---

## What Is NEVER Logged

| Data | Reason |
| --- | --- |
| OTP message body | Contains OTP digits |
| Full bank SMS body | Contains sensitive financial data |
| Private key material | Never leaves Keystore |
| Pairing token | Single-use secret |
| Payer name (in full) | Privacy; log a hash |

For payer name in payment observations, log `sha256(payerName)` instead of the raw value.

---

## Log Storage

- Stored in SQLite using an append-only table (no UPDATE or DELETE operations allowed on log rows)
- Encrypted at rest using the Android Keystore (database encryption key stored in Keystore)
- Log entries are immutable once written

> `// TODO(arch): Evaluate sqflite_sqlcipher vs. drift with encryption for log storage`

---

## Log Reporting to Server

The server may request a log export via a signed command. The agent:

1. Serializes the requested log range
2. Signs the export
3. Transmits to the server
4. Does NOT delete local logs until the server explicitly confirms receipt

Log deletion without server confirmation is a policy violation (see `CONSTITUTION/02_allowed_vs_forbidden.md`, Section 3).

---

## Log Retention

> `// TODO(arch): Define local log retention period — 30 days? Until server confirms receipt?`

Current policy: Logs are retained indefinitely until the server issues a confirmed-receipt + delete authorization command.
