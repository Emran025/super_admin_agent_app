import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/pairing/entities/linked_system.dart';
import '../../../domain/pairing/repositories/pairing_repository.dart';
import '../../../domain/pairing/use_cases/get_linked_systems_use_case.dart';
import '../../../domain/pairing/use_cases/link_system_use_case.dart';
import '../../../domain/pairing/use_cases/unlink_system_use_case.dart';

abstract class LinkedSystemsState extends Equatable {
  const LinkedSystemsState();

  @override
  List<Object?> get props => [];
}

class LinkedSystemsInitial extends LinkedSystemsState {}

class LinkedSystemsLoading extends LinkedSystemsState {}

class LinkedSystemsLoaded extends LinkedSystemsState {
  final List<LinkedSystem> systems;

  const LinkedSystemsLoaded(this.systems);

  @override
  List<Object?> get props => [systems];
}

class LinkedSystemsError extends LinkedSystemsState {
  final String message;

  const LinkedSystemsError(this.message);

  @override
  List<Object?> get props => [message];
}

class LinkedSystemsCubit extends Cubit<LinkedSystemsState> {
  final GetLinkedSystemsUseCase _getUseCase;
  final LinkSystemUseCase _linkUseCase;
  final UnlinkSystemUseCase _unlinkUseCase;

  LinkedSystemsCubit({
    required GetLinkedSystemsUseCase getUseCase,
    required LinkSystemUseCase linkUseCase,
    required UnlinkSystemUseCase unlinkUseCase,
  })  : _getUseCase = getUseCase,
        _linkUseCase = linkUseCase,
        _unlinkUseCase = unlinkUseCase,
        super(LinkedSystemsInitial());

  Future<void> loadSystems(String gatewaySystemId) async {
    emit(LinkedSystemsLoading());
    final result = await _getUseCase.execute(gatewaySystemId: gatewaySystemId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(const LinkedSystemsError('Failed to load linked systems')),
      (systems) => emit(LinkedSystemsLoaded(systems)),
    );
  }

  Future<String?> linkSystem({
    required String gatewaySystemId,
    required String systemId,
  }) async {
    final result = await _linkUseCase.execute(
      gatewaySystemId: gatewaySystemId,
      systemId: systemId,
    );
    if (isClosed) return null;
    return result.fold(
      (failure) {
        String msg = 'Failed to link system';
        if (failure is RegistrationFailure) {
          msg = failure.reason;
        } else if (failure is TokenInvalidFailure) {
          msg = failure.reason;
        }
        emit(LinkedSystemsError(msg));
        return msg;
      },
      (system) {
        if (state is LinkedSystemsLoaded) {
          final current = (state as LinkedSystemsLoaded).systems;
          emit(LinkedSystemsLoaded([...current, system]));
        } else {
          loadSystems(gatewaySystemId);
        }
        return null;
      },
    );
  }

  Future<void> unlinkSystem({
    required String gatewaySystemId,
    required String systemId,
  }) async {
    final result = await _unlinkUseCase.execute(
      gatewaySystemId: gatewaySystemId,
      systemId: systemId,
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(const LinkedSystemsError('Failed to unlink system')),
      (_) {
        if (state is LinkedSystemsLoaded) {
          final current = (state as LinkedSystemsLoaded).systems;
          emit(LinkedSystemsLoaded(
            current.where((s) => s.id != systemId).toList(),
          ));
        } else {
          loadSystems(gatewaySystemId);
        }
      },
    );
  }
}
