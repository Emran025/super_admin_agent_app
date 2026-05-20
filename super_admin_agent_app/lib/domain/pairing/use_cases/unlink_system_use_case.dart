import 'package:dartz/dartz.dart';
import '../repositories/pairing_repository.dart';

class UnlinkSystemUseCase {
  final PairingRepository _repository;

  const UnlinkSystemUseCase({required PairingRepository repository})
      : _repository = repository;

  Future<Either<PairingFailure, void>> execute({
    required String gatewaySystemId,
    required String systemId,
  }) {
    return _repository.unlinkExternalSystem(
      gatewaySystemId: gatewaySystemId,
      systemId: systemId,
    );
  }
}
