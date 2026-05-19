import 'package:dio/dio.dart';
import '../../../domain/auth_2fa/entities/auth_challenge.dart';
import '../../../domain/auth_2fa/repositories/auth_challenge_repository.dart';
import '../../../domain/auth_2fa/value_objects/signed_challenge_response.dart';
import '../dtos/auth_challenge_dto.dart';

class AuthChallengeRemoteDataSource {
  final Dio _dio;

  const AuthChallengeRemoteDataSource({required Dio dio}) : _dio = dio;

  Future<AuthChallenge> fetchChallenge(String challengeId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/challenges/$challengeId',
      );
      return AuthChallengeDto.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      if (e.response?.statusCode == 410) {
        throw const ChallengeNotActionableFailure('Challenge gone (410)');
      }
      if (e.response?.statusCode == 404) {
        throw const ChallengeNotFoundFailure();
      }
      rethrow;
    }
  }

  Future<void> submitResponse(SignedChallengeResponse response) async {
    try {
      await _dio.post<void>(
        '/v1/challenges/${response.challengeId}/respond',
        data: {
          'decision': response.decision.name,
          'responded_at': response.respondedAt.toIso8601String(),
          'nonce': response.nonce,
          'agent_public_key_id': response.agentPublicKeyId,
          'signature': response.signature,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const ChallengeAlreadyRespondedException();
      }
      if (e.response?.statusCode == 401) {
        throw const ChallengeSubmissionFailure('signature_rejected');
      }
      rethrow;
    }
  }
}
