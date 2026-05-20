import 'package:dartz/dartz.dart';
import '../entities/linked_system.dart';
import '../repositories/pairing_repository.dart';

class LinkSystemUseCase {
  final PairingRepository _repository;

  const LinkSystemUseCase({required PairingRepository repository})
      : _repository = repository;

  Future<Either<PairingFailure, LinkedSystem>> execute({
    required String gatewaySystemId,
    required String systemId,
  }) {
    return _repository.linkExternalSystem(
      gatewaySystemId: gatewaySystemId,
      systemId: systemId,
    );
  }
}
