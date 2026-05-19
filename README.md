# Super Admin Agent

A highly secure, zero-trust mobile agent built in Flutter that establishes cryptographically verifiable relationships with backend systems to provide:

- **Push-Based 2FA**: Cryptographically signed two-factor authentication approvals.
- **SMS OTP Gateway**: Outbound dispatch of One-Time Passwords via local SMS.
- **Payment Observation**: Inbound monitoring and reporting of SMS payment notifications.

## Architecture

This project strictly adheres to **Clean Architecture** principles and a defined set of security axioms:

- Zero-trust domain boundaries.
- Cryptographically signed communication.
- Hardware-backed keystore integration.
- Immutable append-only SQLite audit logs.

## Project Structure

- `/agent` - Architectural definitions, constitutional rules, and domain boundaries.
- `/stages` - The phased AI implementation roadmap.
- `/super_admin_agent_app` - The Flutter application source code.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
