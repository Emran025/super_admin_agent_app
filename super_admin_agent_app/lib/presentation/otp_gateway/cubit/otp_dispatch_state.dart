import 'package:equatable/equatable.dart';

/// All possible states of the OTP dispatch workflow.
///
/// No state carries [messageBody] — OTP content must not persist in UI state.
sealed class OtpDispatchState extends Equatable {
  const OtpDispatchState();
}

/// Initial state — ready for a new command.
class OtpIdle extends OtpDispatchState {
  const OtpIdle();
  @override
  List<Object?> get props => [];
}

/// Fetching the dispatch command from the server.
class OtpFetching extends OtpDispatchState {
  const OtpFetching();
  @override
  List<Object?> get props => [];
}

/// SMS dispatch is in progress.
class OtpDispatching extends OtpDispatchState {
  const OtpDispatching();
  @override
  List<Object?> get props => [];
}

/// SMS dispatched and delivery report submitted successfully.
class OtpDispatched extends OtpDispatchState {
  const OtpDispatched();
  @override
  List<Object?> get props => [];
}

/// An error occurred during the dispatch workflow.
class OtpError extends OtpDispatchState {
  final String message;
  const OtpError(this.message);
  @override
  List<Object?> get props => [message];
}
