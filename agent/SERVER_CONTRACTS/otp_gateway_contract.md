# API Contract: SMS OTP Gateway

> All requests include standard agent auth headers (see `SERVER_CONTRACTS/global_expectations.md`).

---

## 1. Fetch OTP Dispatch Command

### Request

```yaml
GET /v1/otp-commands/{command_id}
```

### Response 200

```json
{
  "success": true,
  "data": {
    "command_id": "cmd_Abc123...",
    "system_id": "sys_abc123",
    "recipient_phone_number": "+967700000000",
    "message_body": "Your verification code is 847291. Valid for 5 minutes.",
    "sim_slot": "DEFAULT | SIM_1 | SIM_2",
    "issued_at": "2026-05-19T01:00:00Z",
    "status": "PENDING"
  },
  "error": null
}
```

> **Security Note**: The `message_body` is treated as a write-only delivery payload by the agent. It is passed to the SMS service immediately and never stored.

### Response 404

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "COMMAND_NOT_FOUND",
    "message": "No OTP command with the provided ID exists."
  }
}
```

---

## 2. Submit Delivery Report

### Request

```yaml
POST /v1/otp-commands/{command_id}/report
Content-Type: application/json
```

```json
{
  "command_id": "cmd_Abc123...",
  "status": "SENT | DELIVERED | FAILED_NO_SERVICE | FAILED_GENERIC",
  "reported_at": "2026-05-19T01:00:10Z",
  "nonce": "<base64url 32 bytes>",
  "agent_public_key_id": "<key_id>",
  "signature": "<base64url EC signature>"
}
```

### Response 200

```json
{
  "success": true,
  "data": {
    "command_id": "cmd_Abc123...",
    "acknowledged": true
  },
  "error": null
}
```

### Response 409 (Duplicate Report)

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "DUPLICATE_REPORT",
    "message": "A delivery report for this command has already been received."
  }
}
```

---

## Delivery Status Values

| Status | Meaning |
| --- | --- |
| `SENT` | SMS submitted to the cellular network (no delivery confirmation) |
| `DELIVERED` | Delivery receipt received from network (where supported) |
| `FAILED_NO_SERVICE` | Device had no cellular service at time of dispatch |
| `FAILED_GENERIC` | Any other failure reason |

---

## Sequence Flow

```txt
1. Server generates OTP, renders message_body, generates command_id, stores as PENDING
2. Server sends FCM data message: { capability: "CAPABILITY_OTP_GATEWAY", command_id: "...", system_id: "..." }
3. Agent receives push, extracts command_id
4. Agent calls GET /v1/otp-commands/{command_id}
5. Server responds with OtpDispatchCommand (includes pre-rendered message_body)
6. Agent passes message_body to SmsInfrastructureService (not stored, not logged)
7. SmsInfrastructureService sends SMS via Android SmsManager
8. Platform returns delivery status (SENT/DELIVERED/FAILED)
9. Agent constructs SmsDeliveryReport:
   - Sets status from platform result
   - Generates fresh nonce
   - Signs { command_id + status + reported_at + nonce }
10. Agent calls POST /v1/otp-commands/{command_id}/report
11. Server records delivery report, uses it for retry decisions
12. Agent writes audit log entry (command_id + status only; NO message_body)
```

---

## Error Handling Matrix

| Server Response | Agent Action |
| --- | --- |
| 200 (fetch) | Proceed to dispatch SMS |
| 200 (report) | Write SUCCESS audit entry |
| 401 | Write FAILURE audit entry, stop |
| 404 | Write FAILURE audit entry (COMMAND_NOT_FOUND), stop |
| 409 (report) | Write FAILURE audit entry (DUPLICATE), no retry |
| 5xx | Write FAILURE audit entry (SERVER_ERROR), report failure to owner |
