import 'package:dartz/dartz.dart';
import '../entities/linked_system.dart';
import '../repositories/pairing_repository.dart';

class GetLinkedSystemsUseCase {
  final PairingRepository _repository;

  const GetLinkedSystemsUseCase({required PairingRepository repository})
      : _repository = repository;

  Future<Either<PairingFailure, List<LinkedSystem>>> execute({
    required String gatewaySystemId,
  }) {
    return _repository.getLinkedSystems(
      gatewaySystemId: gatewaySystemId,
    );
  }
}
