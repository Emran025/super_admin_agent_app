import '../../../domain/auth_2fa/entities/auth_challenge.dart';
import '../../../domain/auth_2fa/entities/challenge_status.dart';

class AuthChallengeDto {
  final String challengeId;
  final String systemId;
  final String issuedAt;
  final String expiresAt;
  final String contextLabel;
  final String status;

  const AuthChallengeDto({
    required this.challengeId,
    required this.systemId,
    required this.issuedAt,
    required this.expiresAt,
    required this.contextLabel,
    required this.status,
  });

  factory AuthChallengeDto.fromJson(Map<String, dynamic> json) =>
      AuthChallengeDto(
        challengeId: json['challenge_id'] as String,
        systemId: json['system_id'] as String,
        issuedAt: json['issued_at'] as String,
        expiresAt: json['expires_at'] as String,
        contextLabel: json['challenged_username'] as String,
        status: (json['status'] as String?) ?? 'PENDING',
      );

  AuthChallenge toEntity() => AuthChallenge(
        challengeId: challengeId,
        systemId: systemId,
        issuedAt: DateTime.parse(issuedAt).toUtc(),
        expiresAt: DateTime.parse(expiresAt).toUtc(),
        contextLabel: contextLabel,
        status: _mapStatus(status),
      );

  static ChallengeStatus _mapStatus(String raw) => switch (raw.toUpperCase()) {
        'RESPONDED' => ChallengeStatus.responded,
        'EXPIRED' => ChallengeStatus.expiredRemote,
        'SUPERSEDED' => ChallengeStatus.superseded,
        _ => ChallengeStatus.pending,
      };
}
