# Formatting Rules

> Standards for all data produced by the mobile agent.

---

## JSON Formatting (Outbound API Payloads)

- **Canonical JSON**: Keys sorted alphabetically at every level
- **Encoding**: UTF-8, no BOM
- **Whitespace**: No trailing whitespace, no pretty-printing in production
- **Dates**: ISO 8601 UTC format: `YYYY-MM-DDTHH:MM:SSZ` (no milliseconds unless required)
- **Amounts**: String representation of decimal (e.g., `"5000.00"`) — never floating point
- **Booleans**: JSON native `true` / `false`, never `"true"` / `"false"` strings
- **Null fields**: Included explicitly as `null`, never omitted from required fields

---

## Phone Numbers

- Format: E.164 (`+967700000000`)
- No spaces, no dashes, no parentheses
- Validated at the data layer before any use; rejected if not E.164

---

## Amounts

- Stored and transmitted as `String` (decimal notation)
- Parsed to `Decimal` type within the domain (never `double` or `float`)
- Currency transmitted as 3-letter ISO 4217 code (e.g., `YER`, `USD`)

---

## Audit Log Entries

- JSON lines format (one JSON object per line, newline-delimited)
- All timestamps in ISO 8601 UTC
- `entry_id`: UUID v4
- `action_type`: UPPER_SNAKE_CASE enum value
- `outcome`: `SUCCESS` | `FAILURE` | `PARTIAL`

---

## Error Codes (Agent-Generated)

Agent-generated error codes (used in log entries and server-reported failures) follow this format:

```txt
DOMAIN_ERROR_DESCRIPTION
```

Examples:

- `AUTH_CHALLENGE_NOT_FOUND`
- `OTP_SMS_FAILED_NO_SERVICE`
- `PAYMENT_PARSE_FAILED`
- `SIGNING_FAILURE`
- `UNKNOWN_COMMAND_REJECTED`

Error codes are UPPER_SNAKE_CASE. No spaces, no special characters.

---

## UI Text

- Error messages shown to the owner use human-readable English (or localized equivalent)
- Error codes are shown alongside human-readable messages (for support purposes)
- No technical stack traces are displayed to the owner
- Amounts displayed to the owner use locale-appropriate formatting (e.g., `5,000.00 YER`)
- Phone numbers displayed to the owner show last 4 digits only (e.g., `+967 *** *** 0000`)

---

## Signatures

- Algorithm: EC-SHA256 (P-256 key)
- Encoding: Base64url (no padding, URL-safe alphabet)
- Never Base64 standard (use URL-safe variant)
- Transmitted in `X-Agent-Signature` HTTP header and in response body where required

---

## Nonces

- Size: 32 bytes (256 bits)
- Encoding: Base64url
- Generation: `Random.secure()` from `dart:math`
- Never reused across requests
