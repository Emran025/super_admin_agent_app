import 'package:dartz/dartz.dart';

// ---------------------------------------------------------------------------
// Failures
// ---------------------------------------------------------------------------

abstract class AuditLogFailure {
  const AuditLogFailure();
}

class AuditLogWriteFailure extends AuditLogFailure {
  final Object? cause;
  const AuditLogWriteFailure({this.cause});
}

class AuditLogReadFailure extends AuditLogFailure {
  final Object? cause;
  const AuditLogReadFailure({this.cause});
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// All permitted action types in the audit log.
///
/// This closed set is a structural constraint: a field that does not appear
/// here cannot be logged (Constraint 2.7).
enum AuditActionType {
  pairingCompleted,
  pairingFailed,
  unpairingCompleted,
  challengeReceived,
  challengeResponded,
  challengeSubmissionFailed,
  otpDispatchReceived,
  otpSmsSent,
  otpSmsFailed,
  otpReportSubmitted,
  paymentSessionOpened,
  paymentSmsObserved,
  paymentParseFailed,
  paymentReportSubmitted,
  unknownCommandRejected,
  signingFailure,
}

enum AuditOutcome { success, failure, partial }

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

/// An immutable, append-only audit record.
///
/// Structural constraint: there is no [messageBody], [smsBody], or
/// [rawContent] field — by design. You cannot log what the schema cannot hold.
class AuditEntry {
  final String entryId;
  final AuditActionType actionType;
  final String systemId;
  final String? commandId;
  final DateTime timestamp;
  final AuditOutcome outcome;
  final String? failureCode;

  const AuditEntry({
    required this.entryId,
    required this.actionType,
    required this.systemId,
    this.commandId,
    required this.timestamp,
    required this.outcome,
    this.failureCode,
  });
}

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

/// Append-only audit log service.
///
/// The underlying store enforces append-only at the database engine level
/// via a BEFORE UPDATE trigger — not by convention.
abstract class AuditLogService {
  /// Appends a new [entry] to the audit log.
  /// Every call produces a new row — duplicates are allowed by design.
  Future<Either<AuditLogFailure, void>> log(AuditEntry entry);

  /// Returns all audit log entries in insertion order.
  Future<Either<AuditLogFailure, List<AuditEntry>>> queryAll();

  /// Returns all audit log entries for a specific [systemId].
  Future<Either<AuditLogFailure, List<AuditEntry>>> queryBySystem(
    String systemId,
  );
}
