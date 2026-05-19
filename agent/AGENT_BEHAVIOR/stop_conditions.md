# Stop Conditions

> This document defines exactly when the agent must stop and refuse to proceed, rather than guessing or continuing.

---

## Stop Condition 1: Unknown System

**Trigger**: The `system_id` in an incoming push notification is not in the `PairedSystemRegistry`.

**Action**: Discard the push. Log `UNKNOWN_COMMAND_REJECTED`. Do NOT fetch from an unknown server URL.

**Reason**: Communication with unpaired systems is forbidden by Axiom 2 and CF-03.

---

## Stop Condition 2: Unknown or Ungranted Capability

**Trigger**: The `capability` field in a push notification refers to a capability not in the granted list for the identified system.

**Action**: Discard the push. Log `UNKNOWN_COMMAND_REJECTED`. Do NOT attempt to process as a different capability.

---

## Stop Condition 3: Command Fetch Failure

**Trigger**: The HTTP call to fetch command details returns a non-200 status, or the network is unreachable.

**Action**: Log failure with status code. Do NOT display any UI. Do NOT proceed with cached or assumed data.

---

## Stop Condition 4: Command Payload Fails Validation

**Trigger**: The fetched command payload is missing required fields, has incorrect types, or the `command_id` does not match the push trigger.

**Action**: Log `UNKNOWN_COMMAND_REJECTED` with `sha256(rawPayload)`. Report to server. Stop.

---

## Stop Condition 5: Command Not in PENDING State

**Trigger**: The fetched command has status `DISPATCHED`, `FAILED`, `RESPONDED`, `EXPIRED_REMOTE`, or any non-PENDING state.

**Action**: Log the non-actionable status. Discard silently. Do NOT show UI for an already-processed command.

---

## Stop Condition 6: Signing Failure

**Trigger**: The Android Keystore returns an error during signing (key unavailable, device not authenticated, hardware fault).

**Action**: Log `SIGNING_FAILURE`. Surface error to owner. Do NOT send an unsigned response. Stop.

**Reason**: CF-02 — unsigned responses are forbidden.

---

## Stop Condition 7: Server Rejects Signature

**Trigger**: Server returns `401 Unauthorized` in response to a signed request.

**Action**: Log `SIGNATURE_REJECTED`. Surface error to owner. Do NOT retry with a modified signature. Stop.

**Reason**: If the server rejects the signature, either the key is invalid, the device identity is compromised, or the server's key store is out of sync. None of these should be resolved by the app silently retrying.

---

## Stop Condition 8: OTP Message Body Is Absent

**Trigger**: The `message_body` field in an `OtpDispatchCommand` is null, empty, or whitespace-only.

**Action**: Log `OTP_DISPATCH_FAILED` (INVALID_PAYLOAD). Report to server. Do NOT send a blank SMS.

---

## Stop Condition 9: SMS Parsing Returns No Data

**Trigger**: `SmsParsingService` returns null for all expected fields from a bank SMS.

**Action**: Produce an `ObservationReport` with all parsed fields null and `is_match: false`. Report to server. Log `PAYMENT_PARSE_FAILED`. Do NOT guess or fill default values.

---

## Stop Condition 10: Device Biometric / Screen Lock Not Active

**Trigger**: The agent detects that the device does not have a screen lock enabled (required for Keystore hardware-backed keys).

**Action**: Display a persistent, non-dismissable warning to the owner. Block all capability execution until the device has a secure lock configured.

> `// TODO(arch): Define the exact Android API to check for screen lock status and hardware-backed key availability`
