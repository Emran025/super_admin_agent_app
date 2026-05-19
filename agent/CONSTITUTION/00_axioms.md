# Axioms — Non-Negotiable Principles

> **These axioms are the foundation of the entire system.**
> They cannot be overridden by feature requests, performance concerns, or implementation convenience.
> Any design that violates an axiom is, by definition, a failed design.

---

## Axiom 1: The Mobile Agent Is Not a Decision-Maker

The mobile agent **executes** commands. It **reports** observations. It **signs** responses.

It does **not**:

- Evaluate whether an action is safe
- Override a server decision
- Approve or reject transactions
- Apply business rules

If a decision needs to be made, it is made by the server. Always.

**Corollary**: If a feature requires the mobile app to "know" whether something is valid, that feature is designed incorrectly.

---

## Axiom 2: Trust Is Established, Not Assumed

No mobile device is trusted by default. Trust is established through an explicit cryptographic pairing process initiated by the server.

- Before pairing: the app has no capabilities, no system ID, no allowed actions.
- After pairing: the app holds a device-bound identity key and a list of explicitly granted capabilities.

**Corollary**: Capabilities cannot be self-assigned. They are granted by the server during pairing and can be revoked at any time.

---

## Axiom 3: Ownership Is Singular and Physical

There is exactly one owner: the human who physically controls the device and the backend system(s).

There is no multi-tenancy. There is no delegation chain beyond Owner → Server → Agent. There are no "admin accounts" within the mobile app.

**Corollary**: Any feature that introduces the concept of "mobile app users" or "roles within the app" violates this axiom.

---

## Axiom 4: Scope Is Fixed Per Capability

Each capability (2FA, OTP Gateway, Payment Observation) is fully isolated. They share:

- Infrastructure utilities (signing, networking, storage encryption)

They do NOT share:

- Business logic
- Use cases
- Domain entities
- Repository contracts

Adding shared business logic between capabilities is a **scope violation**.

---

## Axiom 5: Secrets Are Never Plaintext

The following must never appear in plaintext in any storage location:

- Private keys
- Pairing tokens (after use)
- Session tokens
- API credentials

All secrets are stored using the Android Keystore (or platform equivalent). All transit is over TLS.

**Corollary**: Logging a secret, even in a debug build, is a security failure.

---

## Axiom 6: All Server Responses Are Signed

Every response the mobile agent sends to any server must be:

1. Constructed from a verifiable server command (with a command ID)
2. Signed with the device-bound private key
3. Include a timestamp and nonce for replay protection

Sending an unsigned response is a **protocol violation** and must be rejected by the server.

---

## Axiom 7: Clean Architecture Is Non-Negotiable

The layering rules are:

```mermaid
graph LR;
    Domain &nbsp; &nbsp; &nbsp; --> &nbsp; &nbsp; Data &nbsp; &nbsp; &nbsp; --> &nbsp; &nbsp; Presentation;
```

- Domain knows nothing outside itself.
- Data implements domain interfaces; it may use external libraries.
- Presentation knows domain and data; it handles UI only.

**Corollary**: Any import of a Flutter widget, Firebase SDK, or Android API into the Domain layer is an architectural failure.

---

## Axiom 8: Auditability Is a First-Class Concern

Every action taken by the mobile agent must be:

- Logged locally with a timestamp, action type, and outcome
- Reported to the server as part of the response
- Stored in a tamper-evident format (append-only local log)

Silent actions (actions with no log entry) are prohibited.

---

## Axiom 9: The System Supports Multiple Backends Without Code Change

The mobile agent must be able to pair with any number of backend systems without:

- Changing source code
- Rebuilding the app
- Hardcoding system-specific logic

All system-specific configuration is received during pairing and stored securely.

**Corollary**: Any hardcoded URL, system name, or API key in the source code is a violation.

---

## Axiom 10: Uncertainty Stops Execution

If the agent receives a command it does not recognize, or a payload that fails validation, it must:

1. Reject the command
2. Log the rejection with the full payload fingerprint
3. Report the rejection to the server
4. NOT attempt to guess the intent or proceed partially

Partial execution of an unrecognized command is more dangerous than no execution.
