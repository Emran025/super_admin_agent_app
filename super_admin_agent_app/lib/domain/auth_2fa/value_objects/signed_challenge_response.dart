import 'package:equatable/equatable.dart';
import 'agent_decision.dart';

/// The signed result of a human decision on an auth challenge.
///
/// Can only be constructed with a non-empty [signature] — asserted at runtime.
/// Produced exclusively by [RecordUserDecisionUseCase].
class SignedChallengeResponse extends Equatable {
  final String challengeId;
  final AgentDecision decision;
  final DateTime respondedAt;
  final String nonce;
  final String signature;
  final String agentPublicKeyId;

  SignedChallengeResponse({
    required this.challengeId,
    required this.decision,
    required this.respondedAt,
    required this.nonce,
    required this.signature,
    required this.agentPublicKeyId,
  }) : assert(signature.isNotEmpty, 'Signature must not be empty');

  @override
  List<Object?> get props =>
      [challengeId, decision, respondedAt, nonce, signature];
}
