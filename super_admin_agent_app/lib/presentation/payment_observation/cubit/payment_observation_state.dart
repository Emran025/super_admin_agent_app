import 'package:equatable/equatable.dart';

/// All possible states of the payment observation workflow.
///
/// No state carries raw SMS body or parsed payer name — data minimization.
sealed class PaymentObservationState extends Equatable {
  const PaymentObservationState();
}

/// Initial state — no active session.
class PaymentObservationIdle extends PaymentObservationState {
  const PaymentObservationIdle();
  @override
  List<Object?> get props => [];
}

/// Fetching the observation session from the server.
class PaymentObservationLoading extends PaymentObservationState {
  const PaymentObservationLoading();
  @override
  List<Object?> get props => [];
}

/// Session is active — listening for incoming SMS.
class PaymentObservationActive extends PaymentObservationState {
  final String sessionId;
  const PaymentObservationActive(this.sessionId);
  @override
  List<Object?> get props => [sessionId];
}

/// Observation was reported to the server.
class PaymentObservationReported extends PaymentObservationState {
  final bool isMatch;
  const PaymentObservationReported({required this.isMatch});
  @override
  List<Object?> get props => [isMatch];
}

/// An error occurred during the observation workflow.
class PaymentObservationError extends PaymentObservationState {
  final String message;
  const PaymentObservationError(this.message);
  @override
  List<Object?> get props => [message];
}
