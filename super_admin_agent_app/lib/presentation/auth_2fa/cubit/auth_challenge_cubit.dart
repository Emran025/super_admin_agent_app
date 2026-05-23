import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/auth_2fa/repositories/auth_challenge_repository.dart';
import '../../../domain/auth_2fa/use_cases/receive_auth_challenge_use_case.dart';
import '../../../domain/auth_2fa/use_cases/record_user_decision_use_case.dart';
import '../../../domain/auth_2fa/use_cases/submit_challenge_response_use_case.dart';
import '../../../domain/auth_2fa/value_objects/agent_decision.dart';
import 'auth_challenge_state.dart';

/// Orchestrates the 2FA challenge UI flow.
///
/// No business logic here — all decisions live in use cases (AF-03).
/// No expiry evaluation, no content checking, no retry logic.
class AuthChallengeCubit extends Cubit<AuthChallengeState> {
  final ReceiveAuthChallengeUseCase _receiveUseCase;
  final RecordUserDecisionUseCase _recordUseCase;
  final SubmitChallengeResponseUseCase _submitUseCase;

  AuthChallengeCubit({
    required ReceiveAuthChallengeUseCase receiveUseCase,
    required RecordUserDecisionUseCase recordUseCase,
    required SubmitChallengeResponseUseCase submitUseCase,
  })  : _receiveUseCase = receiveUseCase,
        _recordUseCase = recordUseCase,
        _submitUseCase = submitUseCase,
        super(const AuthChallengeIdle());

  Future<void> loadChallenge({
    required String challengeId,
    required String systemId,
    String? externalSystemId,
  }) async {
    emit(const AuthChallengeFetching());
    final result = await _receiveUseCase.execute(
      challengeId: challengeId,
      systemId: systemId,
    );
    result.fold(
      (f) => emit(AuthChallengeError(_authFailureMsg(f))),
      (challenge) => emit(AuthChallengeReady(challenge)),
    );
  }

  Future<void> submitDecision(AgentDecision decision) async {
    final current = state;
    if (current is! AuthChallengeReady) return;

    emit(const AuthChallengeSubmitting());

    final recordResult = await _recordUseCase.execute(
      challenge: current.challenge,
      decision: decision,
    );

    await recordResult.fold(
      (f) async => emit(AuthChallengeError(_authFailureMsg(f))),
      (response) async {
        final submitResult = await _submitUseCase.execute(
          response: response,
          systemId: current.challenge.systemId,
        );
        submitResult.fold(
          (f) => emit(AuthChallengeError(_authFailureMsg(f))),
          (_) => emit(const AuthChallengeSubmitted()),
        );
      },
    );
  }

  String _authFailureMsg(AuthChallengeFailure f) => switch (f) {
        ChallengeNotFoundFailure() => 'Challenge not found.',
        ChallengeNotActionableFailure(:final reason) => 'Challenge not actionable: $reason',
        ChallengeSubmissionFailure(:final detail) => 'Submission failed: $detail',
        ChallengeAlreadyRespondedException() => 'Challenge already responded.',
        _ => 'An error occurred.',
      };
}
