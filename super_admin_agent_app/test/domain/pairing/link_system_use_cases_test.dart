import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/pairing/entities/linked_system.dart';
import 'package:super_admin_agent/domain/pairing/repositories/pairing_repository.dart';
import 'package:super_admin_agent/domain/pairing/use_cases/get_linked_systems_use_case.dart';
import 'package:super_admin_agent/domain/pairing/use_cases/link_system_use_case.dart';
import 'package:super_admin_agent/domain/pairing/use_cases/unlink_system_use_case.dart';

class MockPairingRepository extends Mock implements PairingRepository {}

void main() {
  late MockPairingRepository repository;
  late LinkSystemUseCase linkUseCase;
  late UnlinkSystemUseCase unlinkUseCase;
  late GetLinkedSystemsUseCase getUseCase;

  setUp(() {
    repository = MockPairingRepository();
    linkUseCase = LinkSystemUseCase(repository: repository);
    unlinkUseCase = UnlinkSystemUseCase(repository: repository);
    getUseCase = GetLinkedSystemsUseCase(repository: repository);
  });

  group('LinkSystemUseCase', () {
    const linkedSystem = LinkedSystem(
      id: 'sys-ext-1',
      name: 'External App',
      capabilities: ['otp'],
      isTest: true,
    );

    test('should delegate to repository and return LinkedSystem on success', () async {
      when(() => repository.linkExternalSystem(
            gatewaySystemId: 'gate-1',
            systemId: 'sys-ext-1',
          )).thenAnswer((_) async => const Right(linkedSystem));

      final result = await linkUseCase.execute(
        gatewaySystemId: 'gate-1',
        systemId: 'sys-ext-1',
      );

      expect(result, const Right(linkedSystem));
      verify(() => repository.linkExternalSystem(
            gatewaySystemId: 'gate-1',
            systemId: 'sys-ext-1',
          )).called(1);
    });

    test('should propagate failure when repository fails', () async {
      when(() => repository.linkExternalSystem(
            gatewaySystemId: 'gate-1',
            systemId: 'sys-ext-1',
          )).thenAnswer((_) async => const Left(RegistrationFailure('error')));

      final result = await linkUseCase.execute(
        gatewaySystemId: 'gate-1',
        systemId: 'sys-ext-1',
      );

      expect(result, const Left(RegistrationFailure('error')));
    });
  });

  group('UnlinkSystemUseCase', () {
    test('should delegate to repository and return Right(null) on success', () async {
      when(() => repository.unlinkExternalSystem(
            gatewaySystemId: 'gate-1',
            systemId: 'sys-ext-1',
          )).thenAnswer((_) async => const Right(null));

      final result = await unlinkUseCase.execute(
        gatewaySystemId: 'gate-1',
        systemId: 'sys-ext-1',
      );

      expect(result, const Right(null));
      verify(() => repository.unlinkExternalSystem(
            gatewaySystemId: 'gate-1',
            systemId: 'sys-ext-1',
          )).called(1);
    });
  });

  group('GetLinkedSystemsUseCase', () {
    const systemsList = [
      LinkedSystem(id: '1', name: 'App 1', capabilities: ['otp'], isTest: false),
    ];

    test('should delegate to repository and return list of LinkedSystem on success', () async {
      when(() => repository.getLinkedSystems(
            gatewaySystemId: 'gate-1',
          )).thenAnswer((_) async => const Right(systemsList));

      final result = await getUseCase.execute(gatewaySystemId: 'gate-1');

      expect(result, const Right(systemsList));
      verify(() => repository.getLinkedSystems(
            gatewaySystemId: 'gate-1',
          )).called(1);
    });
  });
}
