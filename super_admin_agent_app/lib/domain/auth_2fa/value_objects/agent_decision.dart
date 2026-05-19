/// The human decision on an auth challenge.
///
/// Exactly two values — no timeout-equals-reject, no auto-approve (Constraint 2.2).
enum AgentDecision { approve, reject }
