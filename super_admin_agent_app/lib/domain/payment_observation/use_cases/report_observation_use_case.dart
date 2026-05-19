import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';

import '../entities/bank_sms_observation.dart';
import '../entities/payment_observation_session.dart';
import '../repositories/payment_observation_repository.dart';
import '../use_cases/match_observation_to_intent_use_case.dart';
import '../value_objects/observation_report.dart';
import '../../../shared/data/canonical_json.dart';
import '../../../shared/domain/audit_log_service.dart';
import '../../../shared/domain/nonce_generator.dart';
import '../../../shared/domain/signing_service.dart';

/// Signs and submits a payment observation report.
///
/// Audit log policy (Constraint 2.7):
/// - Payer name is logged as sha256(payerName)[0:12] — never the actual name.
/// - Raw SMS body never appears here (BankSmsObservation has no rawBody field).
///
/// Session expiry does not block submission — Invariant 7.
class ReportObservationUseCase {
  final PaymentObservationRepository _repository;
  final SigningService _signingService;
  final NonceGenerator _nonceGenerator;
  final AuditLogService _auditLogService;
  final _uuid = const Uuid();

  const ReportObservationUseCase({
    required PaymentObservationRepository repository,
    required SigningService signingService,
    required NonceGenerator nonceGenerator,
    required AuditLogService auditLogService,
  })  : _repository = repository,
        _signingService = signingService,
        _nonceGenerator = nonceGenerator,
        _auditLogService = auditLogService;

  Future<Either<PaymentObservationFailure, ObservationReport>> execute({
    required BankSmsObservation observation,
    required ObservationMatchResult matchResult,
    required PaymentObservationSession session,
  }) async {
    final reportedAt = DateTime.now().toUtc();
    final nonce = _nonceGenerator.generate();

    // Build canonical signing input.
    final jsonStr = CanonicalJson.encode({
      'intent_id': session.intentId,
      'is_match': matchResult.isMatch,
      'nonce': nonce,
      'observation_id': observation.observationId,
      'parsed_amount': observation.parsedAmount,
      'parsed_currency': observation.parsedCurrency,
      'parsed_payer_name': observation.parsedPayerName,
      'reported_at': reportedAt.toIso8601String(),
      'session_id': session.sessionId,
    });
    final signingInput = '$jsonStr\n$nonce\n${reportedAt.toIso8601String()}';

    final signResult = await _signingService.sign(signingInput);
    if (signResult.isLeft()) {
      return const Left(ReportSubmissionFailure('Signing failed'));
    }

    final signature = signResult.getOrElse(() => '');

    final report = ObservationReport(
      sessionId: session.sessionId,
      intentId: session.intentId,
      observationId: observation.observationId,
      isMatch: matchResult.isMatch,
      parsedPayerName: observation.parsedPayerName,
      parsedAmount: observation.parsedAmount,
      parsedCurrency: observation.parsedCurrency,
      reportedAt: reportedAt,
      nonce: nonce,
      signature: signature,
      agentPublicKeyId: _signingService.publicKeyId,
    );

    // Write pre-submission audit entry BEFORE network call (Constraint 2.7).
    // Payer name is hashed — never logged in plaintext.
    final payerHash = observation.parsedPayerName != null
        ? _hashPayerName(observation.parsedPayerName!)
        : null;

    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: AuditActionType.paymentSmsObserved,
      systemId: session.systemId,
      commandId: session.sessionId,
      timestamp: reportedAt,
      outcome: AuditOutcome.partial,
      failureCode: payerHash, // Truncated SHA-256 hash — not the actual name.
    ));

    // Submit report — even if session is expired (Invariant 7).
    final result = await _repository.submitReport(
      report: report,
      systemId: session.systemId,
    );

    await _auditLogService.log(AuditEntry(
      entryId: _uuid.v4(),
      actionType: AuditActionType.paymentReportSubmitted,
      systemId: session.systemId,
      commandId: session.sessionId,
      timestamp: DateTime.now().toUtc(),
      outcome: result.isRight() ? AuditOutcome.success : AuditOutcome.failure,
    ));

    return result.fold(
      (f) => Left(f),
      (_) => Right(report),
    );
  }

  /// SHA-256 hash of [name], truncated to 12 hex chars.
  /// Used for audit correlation without retaining personal data.
  String _hashPayerName(String name) {
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(utf8.encode(name)));
    return hash
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .substring(0, 12);
  }
}
