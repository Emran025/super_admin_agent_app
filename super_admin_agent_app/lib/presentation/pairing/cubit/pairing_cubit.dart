import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/pairing/use_cases/complete_pairing_use_case.dart';
import '../../../domain/pairing/use_cases/scan_pairing_token_use_case.dart';
import '../../../domain/pairing/use_cases/unpair_system_use_case.dart';
import '../../../domain/pairing/entities/pairing_token.dart';
import '../../../domain/pairing/repositories/pairing_repository.dart';
import '../../../shared/domain/paired_system_registry.dart';
import 'pairing_state.dart';

/// Coordinates the pairing UI flow.
///
/// No business logic lives here — this Cubit calls use cases and translates
/// [Either] results into state emissions (Constraint AF-03 / Axiom).
///
/// All decisions (expiry, capability validation, audit logging) are made
/// in the use cases and domain layer.
class PairingCubit extends Cubit<PairingState> {
  final ScanPairingTokenUseCase _scanUseCase;
  final CompletePairingUseCase _completeUseCase;
  final UnpairSystemUseCase _unpairUseCase;
  final PairedSystemRegistry _registry;

  // Holds the scanned token between [onQrScanned] and [confirmPairing].
  PairingToken? _pendingToken;

  PairingCubit({
    required ScanPairingTokenUseCase scanUseCase,
    required CompletePairingUseCase completeUseCase,
    required UnpairSystemUseCase unpairUseCase,
    required PairedSystemRegistry registry,
  })  : _scanUseCase = scanUseCase,
        _completeUseCase = completeUseCase,
        _unpairUseCase = unpairUseCase,
        _registry = registry,
        super(const PairingIdle());

  /// Activates the QR scanner UI.
  void startScanning() => emit(const PairingScanning());

  /// Cancels the scanning state and returns to idle.
  void cancelScanning() => emit(const PairingIdle());

  /// Called when the camera captures a QR frame.
  ///
  /// Validates and parses the raw value — emits [PairingTokenScanned] on
  /// success, [PairingError] on failure. No network call here.
  void onQrScanned(String rawValue) {
    final result = _scanUseCase.execute(rawValue);
    result.fold(
      (failure) => emit(PairingError(_pairingFailureToMessage(failure))),
      (token) {
        _pendingToken = token;
        emit(PairingTokenScanned(token));
      },
    );
  }

  /// Called when the owner confirms the scanned system details.
  ///
  /// Runs the full pairing ceremony via [CompletePairingUseCase].
  Future<void> confirmPairing() async {
    final token = _pendingToken;
    if (token == null) {
      emit(const PairingError('No scanned token to confirm.'));
      return;
    }

    emit(const PairingInProgress());

    final result = await _completeUseCase.execute(token);
    result.fold(
      (failure) => emit(PairingError(_pairingFailureToMessage(failure))),
      (system) {
        _registry.register(system);
        _pendingToken = null;
        emit(PairingSuccess(system));
      },
    );
  }

  /// Removes the paired system with [systemId].
  Future<void> unpair(String systemId) async {
    final result = await _unpairUseCase.execute(systemId);
    result.fold(
      (failure) => emit(PairingError(_pairingFailureToMessage(failure))),
      (_) {
        _registry.unregister(systemId);
        emit(const PairingIdle());
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _pairingFailureToMessage(PairingFailure failure) {
    return switch (failure) {
      TokenExpiredFailure() =>
        'The QR code has expired. Ask the server administrator for a new one.',
      TokenInvalidFailure(:final reason) =>
        'Invalid QR code: $reason',
      RegistrationFailure(:final reason) =>
        'Server registration failed: $reason',
      StorePairedSystemFailure() =>
        'Failed to save pairing data on device.',
      _ => 'An unexpected error occurred.',
    };
  }
}
