import 'package:get_it/get_it.dart';

import '../../presentation/otp_gateway/cubit/otp_dispatch_cubit.dart';
import 'fcm_message_router.dart';

/// FCM handler for the [otp_gateway] capability.
///
/// Retrieves a fresh [OtpDispatchCubit] from DI and orchestrates
/// the full fetch → dispatch → report sequence.
///
/// Runs silently — no UI is shown for OTP dispatch.
class OtpGatewayFcmHandler implements CapabilityCommandHandler {
  final GetIt _getIt;

  OtpGatewayFcmHandler({GetIt? getIt}) : _getIt = getIt ?? GetIt.instance;

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
