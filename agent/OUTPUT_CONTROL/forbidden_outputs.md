# Forbidden Outputs

> Any output not listed in `allowed_outputs.md` is forbidden by default.
> This document additionally enumerates specific high-risk forbidden outputs.

---

## Forbidden Network Outputs

| Forbidden Output | Reason |
| --- | --- |
| Any request to a URL not in PairedSystemRegistry | CF-03 — communication with unpaired systems |
| Any request without `X-Agent-Signature` header | CF-02 — unsigned response |
| Any request containing a private key or raw Keystore material | CF-01 — secret exposure |
| Any request containing a raw OTP SMS body | OTP value must never leave the device except via SIM |
| Any request containing the full bank SMS body | Sensitive financial data; only parsed fields are transmitted |
| Any analytics or telemetry request to third-party services | Third-party data exfiltration risk |

---

## Forbidden SMS Outputs

| Forbidden Output | Reason |
| --- | --- |
| SMS to any number not specified in a valid `OtpDispatchCommand` | No self-initiated SMS |
| SMS with a modified or agent-generated body | Message body must come verbatim from server command |
| SMS sent without a valid `command_id` | No capability activation without server command |
| SMS containing the recipient's full name in the body (agent-added) | Only the server-provided body may be sent |

---

## Forbidden Storage Outputs

| Forbidden Output | Reason |
| --- | --- |
| Any secret written to `SharedPreferences` | Plaintext storage violation — CF-01 |
| Any secret written to unencrypted SQLite | CF-01 |
| OTP message body written anywhere | OTP isolation |
| Full bank SMS body written anywhere | Financial data privacy |
| Raw parsed payer name written to audit log | Log sha256(payerName) only |
| Private key exported to any file or variable | Keys never leave Keystore |

---

## Forbidden UI Outputs

| Forbidden Output | Reason |
| --- | --- |
| Displaying raw cryptographic signatures | No value to owner; potential exfiltration surface |
| Displaying OTP digit values | OTP isolation |
| Displaying full bank SMS body | Financial data privacy |
| Displaying private key or key material | CF-01 |
| Displaying full payer name in audit log view | Privacy; display hash prefix only |
| Any "auto-approve" or countdown-approve UI | 2FA must require explicit owner tap |

---

## Forbidden Log Outputs

| Forbidden Output | Reason |
| --- | --- |
| OTP message body in any log level | OTP isolation |
| Full bank SMS body in any log level | Financial data |
| Private key material in any log level | CF-01 |
| Pairing token in any log level after use | Single-use secret |
| Stack traces containing secret data | Secrets in debug output |
