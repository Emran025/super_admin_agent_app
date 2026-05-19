import 'package:equatable/equatable.dart';
import 'challenge_status.dart';

class AuthChallenge extends Equatable {
  final String challengeId;
  final String systemId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String contextLabel;
  final ChallengeStatus status;

  const AuthChallenge({
    required this.challengeId,
    required this.systemId,
    required this.issuedAt,
    required this.expiresAt,
    required this.contextLabel,
    this.status = ChallengeStatus.pending,
  });

  AuthChallenge copyWith({ChallengeStatus? status}) => AuthChallenge(
        challengeId: challengeId,
        systemId: systemId,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        contextLabel: contextLabel,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [challengeId, systemId, status];
}
