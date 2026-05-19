import 'package:equatable/equatable.dart';
import '../../../domain/pairing/entities/paired_system.dart';
import '../../../domain/pairing/entities/pairing_token.dart';

/// All possible states of the pairing flow.
sealed class PairingState extends Equatable {
  const PairingState();
}

/// Initial state — nothing has happened yet.
class PairingIdle extends PairingState {
  const PairingIdle();

  @override
  List<Object?> get props => [];
}

/// The QR camera scanner is active.
class PairingScanning extends PairingState {
  const PairingScanning();

  @override
  List<Object?> get props => [];
}

/// A valid QR token was scanned — waiting for owner confirmation.
class PairingTokenScanned extends PairingState {
  final PairingToken token;

  const PairingTokenScanned(this.token);

  @override
  List<Object?> get props => [token];
}

/// Pairing ceremony is in progress (network call underway).
class PairingInProgress extends PairingState {
  const PairingInProgress();

  @override
  List<Object?> get props => [];
}

/// Pairing completed successfully.
class PairingSuccess extends PairingState {
  final PairedSystem system;

  const PairingSuccess(this.system);

  @override
  List<Object?> get props => [system];
}

/// Pairing failed — [message] is a user-facing error description.
class PairingError extends PairingState {
  final String message;

  const PairingError(this.message);

  @override
  List<Object?> get props => [message];
}
