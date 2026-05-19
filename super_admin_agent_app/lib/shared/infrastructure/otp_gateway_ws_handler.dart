import 'package:get_it/get_it.dart';

import '../../presentation/otp_gateway/cubit/otp_dispatch_cubit.dart';
import 'ws_message_router.dart';

/// WebSocket handler for the [otp_gateway] capability.
///
/// Retrieves a fresh [OtpDispatchCubit] from DI and orchestrates
/// the full fetch → dispatch → report sequence.
///
/// Runs silently — no UI is shown for OTP dispatch.
class OtpGatewayWsHandler implements CapabilityCommandHandler {
  final GetIt _getIt;

  OtpGatewayWsHandler({GetIt? getIt}) : _getIt = getIt ?? GetIt.instance;

  @override
  Future<void> handle({
    required String commandId,
    required String systemId,
  }) async {
    final cubit = _getIt<OtpDispatchCubit>();
    await cubit.handleCommand(
      commandId: commandId,
      systemId: systemId,
    );
  }
}
