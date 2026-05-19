import 'package:get_it/get_it.dart';

import '../../presentation/payment_observation/cubit/payment_observation_cubit.dart';
import 'ws_message_router.dart';

/// WebSocket handler for the [payment_observation] capability.
///
/// Retrieves a [PaymentObservationCubit] from DI and starts the observation
/// workflow. Runs silently — no UI is shown for payment observation.
class PaymentObservationWsHandler implements CapabilityCommandHandler {
  final GetIt _getIt;

  PaymentObservationWsHandler({GetIt? getIt})
      : _getIt = getIt ?? GetIt.instance;

  @override
  Future<void> handle({
    required String commandId,
    required String systemId,
  }) async {
    final cubit = _getIt<PaymentObservationCubit>();
    await cubit.startObservation(
      sessionId: commandId,
      systemId: systemId,
    );
  }
}
