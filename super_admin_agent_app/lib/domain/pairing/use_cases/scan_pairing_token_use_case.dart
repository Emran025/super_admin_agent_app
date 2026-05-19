import 'package:dartz/dartz.dart';
import '../entities/pairing_token.dart';
import '../repositories/pairing_repository.dart';

/// Validates and parses a raw QR code value into a [PairingToken].
///
/// Guard: returns [Left(TokenInvalidFailure)] immediately if [rawQrValue]
/// is empty — the repository is never called in this case.
class ScanPairingTokenUseCase {
  final PairingRepository _repository;

  const ScanPairingTokenUseCase({required PairingRepository repository})
      : _repository = repository;

  /// Execute the scan validation.
  ///
  /// Returns [Left(TokenInvalidFailure)] if [rawQrValue] is blank.
  /// Otherwise delegates to [PairingRepository.parsePairingToken].
  Either<PairingFailure, PairingToken> execute(String rawQrValue) {
    if (rawQrValue.trim().isEmpty) {
      return const Left(TokenInvalidFailure('QR value is empty'));
    }
    return _repository.parsePairingToken(rawQrValue);
  }
}
