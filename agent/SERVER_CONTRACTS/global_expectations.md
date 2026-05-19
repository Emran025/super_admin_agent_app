# Global Server Expectations

> Any server that pairs with this agent must meet these baseline requirements.
> These are not optional. A server that does not meet them cannot safely interact with the agent.

---

## Transport

- All communication is over HTTPS with valid TLS certificates
- No HTTP fallback
- Certificate pinning is RECOMMENDED for production deployments

> `// TODO(arch): Define certificate pinning strategy — static pin vs. trust-on-first-use vs. CA-bound`

---

## Authentication Model

Every request from the mobile agent is authenticated by its cryptographic signature (see `SECURITY/signing_and_identity.md`). The server must:

1. Maintain a public key registry keyed by `agent_id`
2. Verify every inbound request signature before processing
3. Reject unsigned requests with `401`
4. Reject requests from revoked `agent_id` values with `403`

---

## Request Format

All requests from the mobile agent use:

```txt
Content-Type: application/json
Accept: application/json
X-Agent-Id: <agent_id>
X-Agent-Public-Key-Id: <key_id>
X-Agent-Nonce: <nonce>
X-Agent-Timestamp: <ISO8601>
X-Agent-Signature: <base64url signature>
```

---

## Response Format

All server responses to the agent must follow this envelope:

```json
{
  "success": true | false,
  "data": { ... } | null,
  "error": {
    "code": "<ERROR_CODE>",
    "message": "<human-readable>"
  } | null
}
```

- `success: true` → `data` is present, `error` is null
- `success: false` → `error` is present, `data` is null

---

## HTTP Status Code Semantics

| Status | Meaning |
| --- | --- |
| `200 OK` | Request processed successfully |
| `400 Bad Request` | Malformed request (invalid JSON, missing fields) |
| `401 Unauthorized` | Signature invalid or missing |
| `403 Forbidden` | Agent revoked or capability not granted |
| `404 Not Found` | Resource does not exist |
| `409 Conflict` | Duplicate action (nonce seen, command already executed) |
| `410 Gone` | Resource existed but is expired or revoked |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Server fault; agent should log and report |

---

## Idempotency

Endpoints that receive agent reports (response submissions, delivery reports, observation reports) must be idempotent by `command_id` / `session_id`. Submitting the same report twice returns `409 Conflict` but does not cause side effects on the second call.

---

## Push Notification Contract

The push notification payload sent to the agent must:

- Contain ONLY the `command_id` or `challenge_id` — no business data
- Be processable even when the app is in the background
- Use the FCM data message format (not notification message) to ensure background delivery
- Include a `capability` field so the agent knows which domain handler to invoke

```json
{
  "data": {
    "capability": "CAPABILITY_2FA | CAPABILITY_OTP_GATEWAY | CAPABILITY_PAYMENT_OBSERVATION",
    "command_id": "<uuid>",
    "system_id": "<uuid>"
  }
}
```

---

## Rate Limiting

Servers should implement rate limiting per `agent_id`. Recommended limits:

| Endpoint Category | Limit |
| --- | --- |
| Challenge/command fetch | 60 requests/minute |
| Response submission | 30 requests/minute |
| Log export | 5 requests/hour |

The agent is not responsible for managing rate limits. It surfaces a `429` response as a user-visible error.
