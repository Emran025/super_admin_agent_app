import 'package:dartz/dartz.dart';
import '../../../domain/auth_2fa/entities/auth_challenge.dart';
import '../../../domain/auth_2fa/repositories/auth_challenge_repository.dart';
import '../../../domain/auth_2fa/value_objects/signed_challenge_response.dart';
import '../remote/auth_challenge_remote_data_source.dart';

class AuthChallengeRepositoryImpl implements AuthChallengeRepository {
  final AuthChallengeRemoteDataSource _remote;

  const AuthChallengeRepositoryImpl({required AuthChallengeRemoteDataSource remote})
      : _remote = remote;

  @override
  Future<Either<AuthChallengeFailure, AuthChallenge>> fetchChallenge({
    required String challengeId,
    required String systemId,
  }) async {
    try {
      final challenge = await _remote.fetchChallenge(challengeId);
      return Right(challenge);
    } on AuthChallengeFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ChallengeNotActionableFailure(e.toString()));
    }
  }

  @override
  Future<Either<AuthChallengeFailure, void>> submitResponse({
    required SignedChallengeResponse response,
    required String systemId,
  }) async {
    try {
      await _remote.submitResponse(response);
      return const Right(null);
    } on AuthChallengeFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ChallengeSubmissionFailure(e.toString()));
    }
  }
}
