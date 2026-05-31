import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:super_admin_agent/domain/otp_gateway/repositories/otp_gateway_repository.dart';

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
    Map<String, dynamic>? payload,
  }) async {
    debugPrint('🐛 [OTP] OtpGatewayWsHandler.handle received command: $commandId');
    final messageBody = payload?['message_body'] as String?;
    if (messageBody != null && messageBody.isNotEmpty) {
      _getIt<OtpGatewayRepository>().cacheMessageBody(commandId, messageBody);
    }
    final customerName = payload?['customer_name'] as String?;
    final systemName = payload?['system_name'] as String?;
    if (customerName != null || systemName != null) {
      _getIt<OtpGatewayRepository>().cacheCustomerAndSystem(
        commandId,
        customerName ?? 'Customer',
        systemName ?? 'SuperAdmin',
      );
    }

    final cubit = _getIt<OtpDispatchCubit>();
    await cubit.handleCommand(
      commandId: commandId,
      systemId: systemId,
    );
  }
}
