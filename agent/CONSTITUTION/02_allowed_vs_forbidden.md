# Allowed vs. Forbidden

> This document is an **explicit enumeration** of what the mobile agent is permitted and prohibited from doing.
> "Not listed as allowed" implies "forbidden by default."

---

## Section 1: Allowed Actions

### 1.1 Pairing & Identity

- ✅ Scan a QR code containing a server-generated pairing token
- ✅ Generate an asymmetric key pair in the Android Keystore
- ✅ Send the public key to the server during pairing
- ✅ Receive and store (encrypted) the system ID and capability list
- ✅ Display current pairing status to the owner
- ✅ Initiate an unpairing process at the owner's request

### 1.2 Push-Based 2FA

- ✅ Receive push notifications containing a `challenge_id`
- ✅ Fetch the challenge details from the paired server
- ✅ Display a native-level approval dialog (Approve / Reject)
- ✅ Collect a binary user decision (approve or reject)
- ✅ Sign the decision with the device-bound private key
- ✅ Send the signed response to the server
- ✅ Log the decision with timestamp and challenge ID

### 1.3 SMS OTP Gateway

- ✅ Receive an OTP dispatch command from the server
- ✅ Read the pre-rendered SMS template from the command payload
- ✅ Create a contact on the device if it does not already exist (optional, configurable)
- ✅ Send the SMS using the device's default SIM
- ✅ Report delivery status (sent / failed) back to the server
- ✅ Log the dispatch with timestamp and recipient hash

### 1.4 Payment Observation

- ✅ Listen for incoming SMS messages from a designated sender name (configured per paired system)
- ✅ Parse the SMS body using a server-provided regex or parsing template
- ✅ Extract payer name and amount fields
- ✅ Match the extracted data against a pending payment intent ID provided in the command
- ✅ Report the extracted data and match result to the server
- ✅ Log the observation with timestamp and intent ID

### 1.5 Audit & Logging

- ✅ Maintain a local append-only audit log
- ✅ Include action type, timestamp, outcome, and command ID in every log entry
- ✅ Report failed operations to the server with error codes

---

## Section 2: Forbidden Actions

### 2.1 Authentication & Sessions

- ❌ Creating user sessions
- ❌ Storing passwords, PINs, or passphrases (other than device-level biometric unlock)
- ❌ Acting as an authentication server
- ❌ Generating login tokens
- ❌ Accepting login credentials from any source

### 2.2 Business Logic

- ❌ Deciding whether a 2FA challenge is legitimate
- ❌ Validating OTP codes
- ❌ Deciding whether a payment is valid
- ❌ Crediting or debiting any account
- ❌ Applying expiry rules to challenges (server-enforced only)
- ❌ Retrying a rejected challenge on the user's behalf

### 2.3 Data Handling

- ❌ Storing any secret in SharedPreferences, SQLite, or any unencrypted storage
- ❌ Logging OTP values
- ❌ Logging full bank SMS body (log fingerprint/hash only)
- ❌ Transmitting raw SMS content to any system other than the designated paired server
- ❌ Caching server responses beyond the lifetime of a command

### 2.4 System Communication

- ❌ Communicating with any server not in the `PairedSystemRegistry`
- ❌ Using hardcoded URLs or IP addresses
- ❌ Bypassing TLS certificate validation
- ❌ Sending unsigned requests to the server

### 2.5 Capability Management

- ❌ Self-assigning capabilities not granted during pairing
- ❌ Activating a capability without a valid server command
- ❌ Sharing data between capabilities (e.g., using OTP domain in 2FA use case)

### 2.6 Output

- ❌ Displaying raw cryptographic keys to the user
- ❌ Displaying the full content of a bank SMS to any UI component
- ❌ Exporting or sharing the local audit log without server authorization
- ❌ Generating any output that contains an OTP value

---

## Section 3: Conditional Actions

These actions are allowed **only under the stated conditions**:

| Action | Condition |
| --- | --- |
| Delete the local audit log | Only after server acknowledges receipt of a full log export |
| Re-pair with a new system | Only after owner initiates and scans a new pairing QR |
| Update capability list | Only upon receiving a valid signed capability-update command from the server |
| Retry a failed OTP SMS | Only if the server explicitly re-sends the dispatch command |

---

## Section 4: The Default Rule

> **If an action is not explicitly listed as allowed, it is forbidden.**

No implicit permissions. No "common sense" exceptions. No convenience shortcuts.

If a new action is needed, it must be added to the Allowed section via the change process in `CONSTITUTION/04_change_policy.md`.
