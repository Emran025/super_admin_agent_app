import 'package:dartz/dartz.dart';
import '../entities/auth_challenge.dart';
import '../entities/challenge_status.dart';
import '../repositories/auth_challenge_repository.dart';
import '../value_objects/agent_decision.dart';
import '../value_objects/signed_challenge_response.dart';
import '../../../shared/data/canonical_json.dart';
import '../../../shared/domain/nonce_generator.dart';
import '../../../shared/domain/signing_service.dart';

/// Converts a human decision into a cryptographically signed response.
///
/// A fresh nonce is generated per call — never cached or reused (Constraint 2.5).
/// Signing input is canonical JSON (Constraint 2.6).
/// A non-pending challenge is rejected without touching [SigningService] (Constraint 2.4).
class RecordUserDecisionUseCase {
  final SigningService _signingService;
  final NonceGenerator _nonceGenerator;

  const RecordUserDecisionUseCase({
    required SigningService signingService,
    required NonceGenerator nonceGenerator,
  })  : _signingService = signingService,
        _nonceGenerator = nonceGenerator;

  Future<Either<AuthChallengeFailure, SignedChallengeResponse>> execute({
    required AuthChallenge challenge,
    required AgentDecision decision,
  }) async {
    // Constraint 2.4: non-pending challenges are rejected before any signing.
    if (challenge.status != ChallengeStatus.pending) {
      return const Left(ChallengeAlreadyRespondedException());
    }

    final respondedAt = DateTime.now().toUtc();
    final nonce = _nonceGenerator.generate(); // Fresh per call — Constraint 2.5.

    // Constraint 2.6: canonical signing input.
    final signingInput = CanonicalJson.encode({
      'challenge_id': challenge.challengeId,
      'decision': decision.name,
      'nonce': nonce,
      'responded_at': respondedAt.toIso8601String(),
    }) + '\n$nonce\n${respondedAt.toIso8601String()}';

    final signResult = await _signingService.sign(signingInput);

    return signResult.fold(
      (failure) => Left(
        ChallengeSubmissionFailure('Signing failed: ${failure.runtimeType}'),
      ),
      (signature) => Right(
        SignedChallengeResponse(
          challengeId: challenge.challengeId,
          decision: decision,
          respondedAt: respondedAt,
          nonce: nonce,
          signature: signature,
          agentPublicKeyId: _signingService.publicKeyId,
        ),
      ),
    );
  }
}
