# Mobile Agent Invariants: Payment Observation

---

## Invariant 1: The Raw SMS Body Is Never Persisted

The raw SMS body string is used only within the scope of `ProcessIncomingSmsUseCase`. After parsing, it is discarded. It is never:

- Written to any storage medium
- Included in any audit log entry
- Transmitted to any server
- Displayed in any UI

**Enforced by**: `ProcessIncomingSmsUseCase` — accepts `rawSmsEvent.body` only as input to `SmsParsingService`. Does not retain a reference after the call returns.

---

## Invariant 2: The Agent Reports Observations, Not Confirmations

The `ObservationReport` uses the field `isMatch: bool`. This field means "the extracted data matches what the server told me to expect." It does NOT mean "the payment is confirmed."

No use case, entity, or value object in this domain contains a concept of "payment confirmed," "account credited," or "transaction approved."

**Enforced by**: Domain entity design — `ObservationReport` has no `isConfirmed`, `isApproved`, or `isPaid` field.

---

## Invariant 3: Only SMS from the Designated Sender Are Processed

The agent filters incoming SMS by the `expectedSenderName` field from the active `PaymentObservationSession`. SMS from any other sender are ignored entirely and not logged.

**Enforced by**: `ProcessIncomingSmsUseCase` — first operation is sender name check; returns `null` (no observation) if sender does not match.

---

## Invariant 4: Observation Requires an Active Session

The agent processes bank SMS only when an `ACTIVE` `PaymentObservationSession` exists. Outside an active session, all incoming SMS are ignored by the payment observation domain (other domains are unaffected).

**Enforced by**: `ProcessIncomingSmsUseCase` — requires a `PaymentObservationSession` with `status == SessionStatus.ACTIVE` as input.

---

## Invariant 5: Every Report Is Signed

`ObservationReport` is always signed with the device key and carries a fresh nonce before submission.

**Enforced by**: `ReportObservationUseCase` — uses `SigningService` before calling the repository.

---

## Invariant 6: Parse Failure Is Reported, Not Silenced

If the `SmsParsingService` fails to extract the required fields (returns null or partial data), the agent:

1. Records the parse failure in the audit log
2. Reports the failure to the server with `parsedPayerName: null`, `parsedAmount: null`, `isMatch: false`
3. Does not attempt to guess or fill in missing fields

**Enforced by**: `ProcessIncomingSmsUseCase` — null-safe handling, always produces an observation (possibly empty) rather than swallowing exceptions.

---

## Invariant 7: Session Expiry Does Not Block a Report

If a `BankSmsObservation` was created while the session was `ACTIVE` but the session has since expired before the report could be submitted, the agent still submits the report. The server decides what to do with a late report.

**Enforced by**: `ReportObservationUseCase` — does not check session status before submitting the report.
