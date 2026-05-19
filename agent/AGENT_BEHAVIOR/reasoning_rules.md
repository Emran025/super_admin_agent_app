# Reasoning Rules

> This document defines how the mobile agent "thinks" — the sequence of checks and evaluations it performs before taking any action.
> These rules exist so that any observer can predict the agent's behavior given an input.

---

## Rule 1: Capability Check Before Processing

Before processing any incoming command, the agent checks whether the required capability is in the granted capabilities list.

```
Incoming FCM message received
    ↓
Extract: capability, command_id, system_id
    ↓
Is system_id in PairedSystemRegistry? → NO → Reject + log UNKNOWN_COMMAND_REJECTED
    ↓ YES
Is capability in grantedCapabilities for system_id? → NO → Reject + log UNKNOWN_COMMAND_REJECTED
    ↓ YES
Proceed to capability handler
```

---

## Rule 2: Command Fetch Before Action

The agent never acts on data contained in a push notification. The push is only a trigger.

```
Push received with command_id
    ↓
Fetch full command from server (signed request)
    ↓
Command fetch failed? → Log FAILURE + stop (no partial action)
    ↓
Command status = PENDING? → Proceed
    ↓
Command status ≠ PENDING? → Log + discard (do not show UI, do not act)
```

---

## Rule 3: Validate Before Act

The agent validates the fetched command payload against its domain invariants before taking any action:

- All required fields are present and non-empty
- Types are correct (e.g., amount is parseable as Decimal)
- command_id matches what was in the push notification

If validation fails:
```
Log UNKNOWN_COMMAND_REJECTED with payload fingerprint (sha256 of payload)
Report rejection to server
Stop — do NOT proceed partially
```

---

## Rule 4: Sign Before Send

The agent never sends a response without signing it. The signing step is the last step before the network call, never before.

```
Build response payload
    ↓
Generate nonce
    ↓
Get current timestamp
    ↓
Compute canonical JSON of payload + nonce + timestamp
    ↓
Sign with Android Keystore key
    ↓
Add signature to headers
    ↓
Send to server
```

---

## Rule 5: Log Before Confirm

The audit log entry is written before the server receives the response. This ensures that if the network call fails, the log still records that the action was attempted.

```
Prepare response
    ↓
Write audit log entry (status = ATTEMPTING)
    ↓
Send to server
    ↓
Update audit log entry (status = SUCCESS | SUBMISSION_FAILED)
```

---

## Rule 6: Failure Is Terminal for a Command

When a command fails (bad signature from server, network error, validation failure), the agent:
1. Logs the failure
2. Reports the failure to the server (if possible)
3. Stops — does NOT retry automatically

Retry is a server-side decision. A new command_id must be issued for a retry.

---

## Rule 7: Unknown Fields Are Ignored, Not Rejected

If the server sends additional fields in a response or command that are not defined in the current contract, the agent ignores them silently. This enables forward compatibility when the server adds new fields.

Unknown top-level keys are not logged (they may contain sensitive data). Only the known fields are processed.

---

## Rule 8: Clock Drift Is an Error, Not a Warning

If the server rejects a request with a timestamp-related error (clock drift), the agent:
1. Logs the rejection
2. Surfaces a clock-sync error to the owner (visible, not silent)
3. Does NOT retry with a manipulated timestamp

The agent never adjusts its timestamp to bypass server validation.
