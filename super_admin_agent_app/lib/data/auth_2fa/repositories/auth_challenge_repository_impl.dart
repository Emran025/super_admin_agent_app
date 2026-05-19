import 'package:dartz/dartz.dart';

import '../../../domain/auth_2fa/entities/auth_challenge.dart';
import '../../../domain/auth_2fa/repositories/auth_challenge_repository.dart';
import '../../../domain/auth_2fa/value_objects/signed_challenge_response.dart';
import '../../../shared/data/http_client_factory.dart';
import '../remote/auth_challenge_remote_data_source.dart';

/// Implements [AuthChallengeRepository].
///
/// Creates a system-specific [AuthChallengeRemoteDataSource] per call using
/// [HttpClientFactory.forSystem()]. This ensures each request carries the
/// correct [agentId] and signature for the right system.
class AuthChallengeRepositoryImpl implements AuthChallengeRepository {
  final HttpClientFactory _clientFactory;

  const AuthChallengeRepositoryImpl({required HttpClientFactory clientFactory})
      : _clientFactory = clientFactory;

  @override
  Future<Either<AuthChallengeFailure, AuthChallenge>> fetchChallenge({
    required String challengeId,
    required String systemId,
  }) async {
    try {
      final source = AuthChallengeRemoteDataSource(
        dio: _clientFactory.forSystem(systemId),
      );
      final challenge = await source.fetchChallenge(challengeId);
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
      final source = AuthChallengeRemoteDataSource(
        dio: _clientFactory.forSystem(systemId),
      );
      await source.submitResponse(response);
      return const Right(null);
    } on AuthChallengeFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ChallengeSubmissionFailure(e.toString()));
    }
  }
}
