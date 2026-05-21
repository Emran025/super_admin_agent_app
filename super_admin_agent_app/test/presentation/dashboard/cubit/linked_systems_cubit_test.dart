import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/pairing/entities/linked_system.dart';
import 'package:super_admin_agent/domain/pairing/repositories/pairing_repository.dart';
import 'package:super_admin_agent/domain/pairing/use_cases/get_linked_systems_use_case.dart';
import 'package:super_admin_agent/domain/pairing/use_cases/link_system_use_case.dart';
import 'package:super_admin_agent/domain/pairing/use_cases/unlink_system_use_case.dart';
import 'package:super_admin_agent/presentation/dashboard/cubit/linked_systems_cubit.dart';

class MockGetLinkedSystemsUseCase extends Mock implements GetLinkedSystemsUseCase {}
class MockLinkSystemUseCase extends Mock implements LinkSystemUseCase {}
class MockUnlinkSystemUseCase extends Mock implements UnlinkSystemUseCase {}

void main() {
  late MockGetLinkedSystemsUseCase getUseCase;
  late MockLinkSystemUseCase linkUseCase;
  late MockUnlinkSystemUseCase unlinkUseCase;
  late LinkedSystemsCubit cubit;

  const linkedSystem = LinkedSystem(
    id: 'sys-ext-1',
    name: 'External App',
    capabilities: ['otp'],
    isTest: true,
  );

  setUp(() {
    getUseCase = MockGetLinkedSystemsUseCase();
    linkUseCase = MockLinkSystemUseCase();
    unlinkUseCase = MockUnlinkSystemUseCase();
    cubit = LinkedSystemsCubit(
      getUseCase: getUseCase,
      linkUseCase: linkUseCase,
      unlinkUseCase: unlinkUseCase,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('LinkedSystemsCubit', () {
    test('initial state is LinkedSystemsInitial', () {
      expect(cubit.state, equals(LinkedSystemsInitial()));
    });

    test('loadSystems emits [Loading, Loaded] when successful', () async {
      when(() => getUseCase.execute(gatewaySystemId: 'gate-1'))
          .thenAnswer((_) async => const Right([linkedSystem]));

      final expected = [
        LinkedSystemsLoading(),
        const LinkedSystemsLoaded([linkedSystem]),
      ];

      expectLater(cubit.stream, emitsInOrder(expected));

      await cubit.loadSystems('gate-1');
      verify(() => getUseCase.execute(gatewaySystemId: 'gate-1')).called(1);
    });

    test('loadSystems emits [Loading, Error] when it fails', () async {
      when(() => getUseCase.execute(gatewaySystemId: 'gate-1'))
          .thenAnswer((_) async => const Left(RegistrationFailure('error')));

      final expected = [
        LinkedSystemsLoading(),
        const LinkedSystemsError('Failed to load linked systems'),
      ];

      expectLater(cubit.stream, emitsInOrder(expected));

      await cubit.loadSystems('gate-1');
    });

    test('linkSystem updates loaded systems on success', () async {
      when(() => linkUseCase.execute(
            gatewaySystemId: 'gate-1',
            systemId: 'sys-ext-1',
          )).thenAnswer((_) async => const Right(linkedSystem));

      // Seed state
      cubit.emit(const LinkedSystemsLoaded([]));

      final expected = [
        const LinkedSystemsLoaded([linkedSystem]),
      ];

      expectLater(cubit.stream, emitsInOrder(expected));

      final result = await cubit.linkSystem(
        gatewaySystemId: 'gate-1',
        systemId: 'sys-ext-1',
      );
      expect(result, isNull);
    });

    test('unlinkSystem removes unlinked system from loaded state on success', () async {
      when(() => unlinkUseCase.execute(
            gatewaySystemId: 'gate-1',
            systemId: 'sys-ext-1',
          )).thenAnswer((_) async => const Right(null));

      // Seed state
      cubit.emit(const LinkedSystemsLoaded([linkedSystem]));

      final expected = [
        const LinkedSystemsLoaded([]),
      ];

      expectLater(cubit.stream, emitsInOrder(expected));

      await cubit.unlinkSystem(
        gatewaySystemId: 'gate-1',
        systemId: 'sys-ext-1',
      );
    });
  });
}
