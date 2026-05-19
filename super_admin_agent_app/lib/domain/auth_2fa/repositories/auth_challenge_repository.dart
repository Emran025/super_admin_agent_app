import 'package:dartz/dartz.dart';
import '../entities/auth_challenge.dart';
import '../value_objects/signed_challenge_response.dart';

abstract class AuthChallengeFailure { const AuthChallengeFailure(); }
class ChallengeNotFoundFailure extends AuthChallengeFailure { const ChallengeNotFoundFailure(); }
class ChallengeNotActionableFailure extends AuthChallengeFailure {
  final String reason;
  const ChallengeNotActionableFailure(this.reason);
}
class ChallengeSubmissionFailure extends AuthChallengeFailure {
  final String detail;
  const ChallengeSubmissionFailure(this.detail);
}
class ChallengeAlreadyRespondedException extends AuthChallengeFailure {
  const ChallengeAlreadyRespondedException();
}

abstract class AuthChallengeRepository {
  Future<Either<AuthChallengeFailure, AuthChallenge>> fetchChallenge({
    required String challengeId,
    required String systemId,
  });

  Future<Either<AuthChallengeFailure, void>> submitResponse({
    required SignedChallengeResponse response,
    required String systemId,
  });
}
