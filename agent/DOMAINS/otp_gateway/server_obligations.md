# Server Obligations: SMS OTP Gateway

---

## Server Must: Before Sending Dispatch Command

1. **Generate the OTP** internally (minimum 6 digits, cryptographically random).
2. **Store the OTP** in its own persistence layer with expiry, tied to the target user's pending action.
3. **Render the full SMS message body** using its own template engine. The rendered body is what the mobile agent will send verbatim.
4. **Generate a unique `command_id`** (minimum 128-bit entropy).
5. **Send the dispatch command** to the mobile agent via push notification containing only the `command_id`.

---

## Server Must: Dispatch Command Detail Endpoint

When the agent calls `GET /otp-commands/{command_id}`:

1. Verify the request signature.
2. Return the `OtpDispatchCommand` payload (see `SERVER_CONTRACTS/otp_gateway_contract.md`).
3. If the command has already been executed, return its current status — not `404`.

---

## Server Must: Delivery Report Endpoint

When the agent calls `POST /otp-commands/{command_id}/report`:

1. Verify the request signature.
2. Verify the nonce for replay protection.
3. Record the delivery report.
4. Use the report to inform internal retry logic if needed.

---

## Server Must NOT

- Send the OTP value in the push notification payload.
- Send the OTP value in a field separate from the rendered `messageBody`.
- Expect the mobile agent to validate or re-send OTPs autonomously.
- Accept delivery reports without a valid signature.
- Reuse a `command_id`.

---

## Server Guarantees

| Guarantee | Details |
| --- | --- |
| OTP isolation | OTP value never transmitted to mobile; only the pre-rendered message body is |
| Template ownership | All message templates are defined and rendered server-side |
| Retry control | Only the server decides if a new dispatch is needed; never the app |
| Expiry enforcement | OTP expiry is enforced by the server, not the app |
