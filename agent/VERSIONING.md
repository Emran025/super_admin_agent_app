# Versioning & Modification Policy

## Current Version

| Field | Value |
| --- | --- |
| Specification Version | 0.1.0 |
| Status | Draft — Pending Owner Approval |
| Created | 2026-05-19 |
| Last Modified | 2026-05-19 |
| Modified By | Chief Software Architect |

---

## Version Scheme

This specification follows **Semantic Versioning (SemVer)**:

```txt
MAJOR.MINOR.PATCH
```

| Increment | Meaning | Requires |
| --- | --- | --- |
| **MAJOR** | Breaking change to agent identity, trust model, or capability boundaries | Full constitutional review + owner approval |
| **MINOR** | New capability, new contract, or new domain added | Architectural review + change policy followed |
| **PATCH** | Clarification, typo fix, editorial improvement | Author self-review + commit log entry |

---

## Document Stability Levels

Each document carries an implicit stability level:

| Level | Documents | Change Frequency |
| --- | --- | --- |
| **Frozen** | `AGENT_CHARTER.md`, `CONSTITUTION/00_axioms.md` | Rarely, only with MAJOR bump |
| **Stable** | All `CONSTITUTION/` files, `ARCHITECTURE/` | Requires MINOR bump |
| **Evolving** | `DOMAINS/`, `SERVER_CONTRACTS/`, `SECURITY/` | May change with MINOR bump |
| **Living** | `AGENT_BEHAVIOR/`, `OUTPUT_CONTROL/` | May change with PATCH |

---

## Changelog

### 0.1.0 — 2026-05-19

- Initial specification drafted
- Three capabilities defined: 2FA, OTP Gateway, Payment Observation
- Clean Architecture rules established
- Security model defined
- Server contracts drafted
- All domain boundaries specified

---

## How to Propose a Change

See `CONSTITUTION/04_change_policy.md` for the full change process.

Summary:

1. Open a change proposal
2. Identify the impacted documents and their stability level
3. Run through the approval chain appropriate for the version bump level
4. Update this `VERSIONING.md` changelog after approval
5. Tag the git commit with the new version

---

## What NEVER Changes Without MAJOR Bump

- The agent's identity as a dumb executor (not a decision-maker)
- The trust hierarchy (Owner → Server → Agent)
- The prohibition on plaintext secret storage
- The prohibition on session creation or password handling
- The Clean Architecture layering constraints
- The cryptographic signing requirement for all server responses

Modifying any of the above without a MAJOR version bump is a **policy violation**.
