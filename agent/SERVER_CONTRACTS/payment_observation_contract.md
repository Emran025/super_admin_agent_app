# API Contract: Payment Observation

> All requests include standard agent auth headers (see `SERVER_CONTRACTS/global_expectations.md`).

---

## 1. Fetch Payment Observation Session

### Request

```txt
GET /v1/payment-sessions/{session_id}
```

### Response 200

```json
{
  "success": true,
  "data": {
    "session_id": "sess_Xyz789...",
    "system_id": "sys_abc123",
    "intent_id": "intent_Pay456...",
    "expected_sender_name": "Bank-XYZ",
    "parsing_template": "(?P<payer>[\\w\\s]+) sent (?P<currency>[A-Z]{3}) (?P<amount>[\\d,.]+)",
    "expected_payer_name": "John Doe",
    "expected_amount": "5000.00",
    "expected_currency": "YER",
    "expires_at": "2026-05-19T01:15:00Z",
    "status": "ACTIVE"
  },
  "error": null
}
```

> **Note**: `expected_payer_name` is optional (may be null). The agent uses it only for the `isMatch` field calculation.
> **Note**: `parsing_template` is a regex string owned and maintained by the server. The agent passes it to `SmsParsingService` without modification.

### Response 404

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "SESSION_NOT_FOUND",
    "message": "No observation session with the provided ID exists."
  }
}
```

### Response 410 (Expired or Closed)

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "SESSION_NOT_ACTIVE",
    "message": "The observation session has expired or is no longer active."
  }
}
```

---

## 2. Submit Observation Report

### Request

```txt
POST /v1/payment-sessions/{session_id}/report
Content-Type: application/json
```

```json
{
  "session_id": "sess_Xyz789...",
  "intent_id": "intent_Pay456...",
  "observation_id": "obs_LocalUuid...",
  "parsed_payer_name": "John Doe",
  "parsed_amount": "5000.00",
  "parsed_currency": "YER",
  "is_match": true,
  "reported_at": "2026-05-19T01:05:30Z",
  "nonce": "<base64url 32 bytes>",
  "agent_public_key_id": "<key_id>",
  "signature": "<base64url EC signature>"
}
```

> **Critical**: `is_match: true` is advisory. The server applies its own business logic to determine payment validity.
> **Parse Failure Case**: If parsing failed, send:
>
> ```json
> {
>   "parsed_payer_name": null,
>   "parsed_amount": null,
>   "parsed_currency": null,
>   "is_match": false,
>   ...
> }
> ```

### Response 200

```json
{
  "success": true,
  "data": {
    "session_id": "sess_Xyz789...",
    "intent_id": "intent_Pay456...",
    "observation_acknowledged": true
  },
  "error": null
}
```

### Response 409 (Duplicate)

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "DUPLICATE_REPORT",
    "message": "An observation report for this session has already been received."
  }
}
```

---

## Sequence Flow

```txt
1. Server creates payment intent (expected amount, payer, expiry)
2. Server generates session_id, stores as ACTIVE
3. Server sends FCM: { capability: "CAPABILITY_PAYMENT_OBSERVATION", command_id: "<session_id>", system_id: "..." }
4. Agent receives push, extracts session_id
5. Agent calls GET /v1/payment-sessions/{session_id}
6. Server responds with PaymentObservationSession (including parsing_template)
7. Agent registers session locally as ACTIVE
8. Agent begins monitoring incoming SMS for sender = expected_sender_name
9. Bank SMS arrives
10. Agent filters: sender matches expected_sender_name? → process. Otherwise → ignore.
11. Agent passes (rawSmsBody, parsingTemplate) to SmsParsingService
12. SmsParsingService extracts payer_name, amount, currency (or returns null on failure)
13. Agent compares extracted values against session expectations → sets is_match
14. Agent discards raw SMS body (never stored, never transmitted)
15. Agent constructs ObservationReport:
    - Sets parsed fields and is_match
    - Generates fresh nonce
    - Signs { session_id + intent_id + observation_id + parsed fields + is_match + reported_at + nonce }
16. Agent calls POST /v1/payment-sessions/{session_id}/report
17. Server receives report, applies own business logic, decides payment outcome
18. Agent writes audit log (session_id + intent_id + is_match + sha256(payerName))
```

---

## Error Handling Matrix

| Server Response | Agent Action |
| --- | --- |
| 200 (fetch) | Register session, begin SMS monitoring |
| 200 (report) | Write SUCCESS audit entry, stop monitoring |
| 401 | Write FAILURE audit entry, stop |
| 404 | Write FAILURE audit entry (SESSION_NOT_FOUND), stop |
| 409 (report) | Write FAILURE audit entry (DUPLICATE), stop |
| 410 (fetch) | Write FAILURE audit entry (SESSION_NOT_ACTIVE), stop |
| 5xx | Write FAILURE audit entry (SERVER_ERROR), surface to owner |
