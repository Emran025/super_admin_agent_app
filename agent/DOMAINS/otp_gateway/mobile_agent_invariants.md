# Mobile Agent Invariants: SMS OTP Gateway

---

## Invariant 1: The Message Body Is Never Stored

The `messageBody` field of `OtpDispatchCommand` is passed directly to the SMS infrastructure service. It is never:

- Written to any database (SQLite, SharedPreferences, Keystore)
- Written to the audit log (the log records the `command_id` and `status` only)
- Displayed in any UI component
- Included in any network response beyond the delivery report (which contains status, not body)

**Enforced by**: `ExecuteSmsDispatchUseCase` — passes `messageBody` directly to `SmsInfrastructureService` and does not retain a reference.

---

## Invariant 2: Delivery Failure Does Not Trigger Retry

If the SMS fails to send, the agent:

1. Records a `SmsDeliveryStatus.FAILED_*` report
2. Reports the failure to the server
3. Stops

The agent does NOT retry. The server decides if a new dispatch command should be issued.

**Enforced by**: `ExecuteSmsDispatchUseCase` — single attempt, report result regardless of outcome.

---

## Invariant 3: Every Dispatch Is Attributed to a Command ID

The agent will never send an SMS without an associated `command_id`. There are no "manual send" or "background retry" paths.

**Enforced by**: `OtpDispatchCommand` entity is the only input to `ExecuteSmsDispatchUseCase`.

---

## Invariant 4: A Command Can Only Be Dispatched Once

Once a command reaches `DISPATCHED` or `FAILED` status locally, it cannot be re-executed by the same command ID.

**Enforced by**: `ExecuteSmsDispatchUseCase` — checks `command.status == DispatchStatus.PENDING` before proceeding.

---

## Invariant 5: Delivery Report Is Always Signed

The `SmsDeliveryReport` sent to the server always carries a device signature and a fresh nonce.

**Enforced by**: `ReportDeliveryStatusUseCase` — uses `SigningService` before calling the repository.
