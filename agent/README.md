# Super Admin Mobile Agent

## What Is This?

This is the **Trusted Mobile Agent** — a private, owner-controlled mobile application that acts as a secure, hardware-bound execution arm for one or more backend systems.

It is **not a consumer application**.
It is **not published on any app store**.
It runs exclusively on a **fully trusted, physically controlled device** with elevated system permissions.

---

## Identity

| Property | Value |
| --- | --- |
| Type | Private Trusted Mobile Agent |
| Distribution | Sideloaded (owner-controlled device only) |
| Trust Model | Device-bound cryptographic identity |
| Decision Authority | Server (never mobile) |
| Architecture | Clean Architecture (strict) |

---

## What This Agent Does

The agent provides exactly **three isolated capabilities**, each operating independently:

| Capability | Role |
| --- | --- |
| **Push-Based 2FA Approval** | Displays approval dialogs for server-generated auth challenges. Signs and returns the user decision. |
| **SMS OTP Gateway** | Receives OTP dispatch instructions from a server and sends SMS using the device SIM. |
| **Payment Observation via Bank SMS** | Monitors incoming bank SMS messages, extracts payer/amount data, and reports findings to the server. |

---

## What This Agent Is NOT Responsible For

This section is **non-negotiable**. Violations are architectural failures.

### ❌ This agent does NOT

- Create sessions or manage authentication state
- Handle passwords or credentials of any kind
- Validate OTP codes
- Confirm, credit, or reject payments
- Make any business decisions
- Store secrets in plaintext
- Operate without a paired server system
- Contain hardcoded system references

### ❌ This agent does NOT replace

- The backend server (decision-maker)
- A proper API gateway
- A dedicated HSM or secure enclave service
- A fraud detection system

---

## Relationship to the Server

```txt
Server ──(commands)──▶ Mobile Agent ──(observations + signed responses)──▶ Server
```

The mobile agent is a **dumb executor and secure signer**.

- **Commands** flow from server to mobile.
- **Observations and signed responses** flow from mobile to server.
- The mobile agent **never initiates business logic**.

---

## How to Navigate This Repository

| Path | Purpose |
| --- | --- |
| `AGENT_CHARTER.md` | Why this agent exists |
| `CONSTITUTION/` | Non-negotiable principles, roles, constraints |
| `DOMAINS/` | Per-capability boundary definitions |
| `ARCHITECTURE/` | Clean Architecture rules and dependency model |
| `SECURITY/` | Trust establishment, signing, replay protection |
| `SERVER_CONTRACTS/` | API contracts between mobile agent and backends |
| `AGENT_BEHAVIOR/` | Reasoning rules, stop conditions, clarification policy |
| `OUTPUT_CONTROL/` | What the agent may and may not output |
| `VERSIONING.md` | Version and modification policy |

---

## Reading Order (First-Time)

1. `AGENT_CHARTER.md`
2. `CONSTITUTION/00_axioms.md`
3. `CONSTITUTION/01_roles_and_authority.md`
4. `CONSTITUTION/02_allowed_vs_forbidden.md`
5. `ARCHITECTURE/clean_architecture_rules.md`
6. `SECURITY/trust_establishment.md`
7. Domain boundaries for each capability

---

_Last reviewed: See `VERSIONING.md`_
