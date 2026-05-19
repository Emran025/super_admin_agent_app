import 'package:equatable/equatable.dart';
import '../../../domain/auth_2fa/entities/auth_challenge.dart';

sealed class AuthChallengeState extends Equatable { const AuthChallengeState(); }

class AuthChallengeIdle extends AuthChallengeState {
  const AuthChallengeIdle();
  @override List<Object?> get props => [];
}

class AuthChallengeFetching extends AuthChallengeState {
  const AuthChallengeFetching();
  @override List<Object?> get props => [];
}

class AuthChallengeReady extends AuthChallengeState {
  final AuthChallenge challenge;
  const AuthChallengeReady(this.challenge);
  @override List<Object?> get props => [challenge];
}

class AuthChallengeSubmitting extends AuthChallengeState {
  const AuthChallengeSubmitting();
  @override List<Object?> get props => [];
}

class AuthChallengeSubmitted extends AuthChallengeState {
  const AuthChallengeSubmitted();
  @override List<Object?> get props => [];
}

class AuthChallengeError extends AuthChallengeState {
  final String message;
  const AuthChallengeError(this.message);
  @override List<Object?> get props => [message];
}
