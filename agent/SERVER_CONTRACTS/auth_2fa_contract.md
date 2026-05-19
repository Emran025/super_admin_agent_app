# API Contract: Push-Based 2FA

> All requests include standard agent auth headers (see `SERVER_CONTRACTS/global_expectations.md`).

---

## 1. Fetch Challenge Details

### Request

```txt
GET /v1/challenges/{challenge_id}
```

Headers: Standard agent auth headers

### Response 200

```json
{
  "success": true,
  "data": {
    "challenge_id": "ch_Xk9mN...",
    "system_id": "sys_abc123",
    "issued_at": "2026-05-19T01:00:00Z",
    "expires_at": "2026-05-19T01:02:00Z",
    "context_label": "Login from Chrome on Windows 11",
    "status": "PENDING"
  },
  "error": null
}
```

### Response 410 (Expired or Already Responded)

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "CHALLENGE_NOT_ACTIONABLE",
    "message": "Challenge is expired or already responded to."
  }
}
```

### Response 404

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "CHALLENGE_NOT_FOUND",
    "message": "No challenge with the provided ID exists."
  }
}
```

---

## 2. Submit Challenge Response

### Request

```txt
POST /v1/challenges/{challenge_id}/respond
Content-Type: application/json
```

```json
{
  "challenge_id": "ch_Xk9mN...",
  "decision": "APPROVE | REJECT",
  "responded_at": "2026-05-19T01:00:45Z",
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
    "challenge_id": "ch_Xk9mN...",
    "recorded_decision": "APPROVE",
    "server_received_at": "2026-05-19T01:00:46Z"
  },
  "error": null
}
```

### Response 409 (Already Responded / Duplicate Nonce)

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "DUPLICATE_RESPONSE",
    "message": "This challenge has already been responded to, or the nonce was previously used."
  }
}
```

### Response 410 (Expired)

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "CHALLENGE_EXPIRED",
    "message": "The challenge window has closed."
  }
}
```

### Response 401 (Bad Signature)

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "SIGNATURE_INVALID",
    "message": "The request signature could not be verified."
  }
}
```

---

## Sequence Flow

```txt
1. Server generates challenge_id, stores it as PENDING, sets expiry
2. Server sends FCM data message: { capability: "CAPABILITY_2FA", command_id: "<challenge_id>", system_id: "..." }
3. Agent receives push, extracts challenge_id
4. Agent calls GET /v1/challenges/{challenge_id}
5. Server responds with AuthChallenge payload
6. Agent displays approval dialog to owner
7. Owner taps Approve or Reject
8. Agent constructs SignedChallengeResponse:
   - Sets decision = APPROVE | REJECT
   - Generates fresh nonce
   - Signs { challenge_id + decision + responded_at + nonce }
9. Agent calls POST /v1/challenges/{challenge_id}/respond
10. Server verifies signature, nonce, timestamp, challenge status
11. Server records decision, updates status to RESPONDED
12. Server applies downstream business logic (e.g., authorizes session)
13. Agent writes audit log entry
14. Agent shows confirmation to owner
```

---

## Error Handling Matrix

| Server Response | Agent Action |
| --- | --- |
| 200 (fetch) | Display challenge to owner |
| 200 (respond) | Write SUCCESS audit entry, show confirmation |
| 401 | Write FAILURE audit entry, show error |
| 409 | Write FAILURE audit entry (DUPLICATE), no retry |
| 410 (fetch) | Silently discard, do not show dialog |
| 410 (respond) | Write FAILURE audit entry (EXPIRED), no retry |
| 5xx | Write FAILURE audit entry (SERVER_ERROR), surface to owner |
