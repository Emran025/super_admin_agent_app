# Server Obligations: Payment Observation

---

## Server Must: Before Opening an Observation Session

1. **Create a payment intent** internally with expected payer name (optional), amount, currency, and expiry.
2. **Generate a unique `session_id`** and `intent_id`.
3. **Prepare the `parsingTemplate`** — a format string, regex, or schema that the agent's parsing service will use to extract fields from the bank SMS body.
4. **Send the observation session command** to the agent via push, containing only the `session_id`.

---

## Server Must: Session Detail Endpoint

When the agent calls `GET /payment-sessions/{session_id}`:

1. Verify the request signature.
2. Return the full `PaymentObservationSession` payload including the `parsingTemplate`.
3. If the session is expired or already matched, return current status — not `404`.

---

## Server Must: Observation Report Endpoint

When the agent calls `POST /payment-sessions/{session_id}/report`:

1. Verify the request signature and nonce.
2. Receive the `ObservationReport`.
3. Apply its own business logic to decide if the payment is valid (the `isMatch` flag is advisory only).
4. Return an acknowledgment.

---

## Server Must NOT

- Accept an observation report without a valid signature.
- Treat the `isMatch: true` flag as definitive payment confirmation.
- Include any financial account data in the session payload.
- Expect the mobile agent to confirm payment validity.
- Re-open a session that has already reached `MATCHED` or `EXPIRED` status.

---

## Server Guarantees

| Guarantee | Details |
| --- | --- |
| Parsing template ownership | The server defines and maintains all parsing templates |
| Business decision isolation | All payment confirmation logic lives on the server |
| Session uniqueness | `session_id` and `intent_id` are globally unique |
| Advisory match flag | `isMatch: true` from the agent is input to server logic, not a confirmation |
