import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import '../../../domain/otp_gateway/repositories/otp_gateway_repository.dart';
import '../../../domain/otp_gateway/use_cases/execute_sms_dispatch_use_case.dart';
import '../../../domain/otp_gateway/use_cases/receive_dispatch_command_use_case.dart';
import '../../../domain/otp_gateway/use_cases/report_delivery_status_use_case.dart';
import 'otp_dispatch_state.dart';

/// Orchestrates the OTP SMS dispatch workflow.
///
/// No business logic here — all rules live in use cases (AF-03).
/// No reference to [messageBody] is held in state or local variables
/// beyond the use case call boundary.
class OtpDispatchCubit extends Cubit<OtpDispatchState> {
  final ReceiveDispatchCommandUseCase _receiveUseCase;
  final ExecuteSmsDispatchUseCase _executeUseCase;
  final ReportDeliveryStatusUseCase _reportUseCase;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true));

  OtpDispatchCubit({
    required ReceiveDispatchCommandUseCase receiveUseCase,
    required ExecuteSmsDispatchUseCase executeUseCase,
    required ReportDeliveryStatusUseCase reportUseCase,
  })  : _receiveUseCase = receiveUseCase,
        _executeUseCase = executeUseCase,
        _reportUseCase = reportUseCase,
        super(const OtpIdle());

  /// Orchestrates: fetch command → send SMS → report delivery.
  ///
  /// The [messageBody] is consumed entirely within [executeUseCase] and
  /// never surfaces in any state emitted by this cubit.
  Future<void> handleCommand({
    required String commandId,
    required String systemId,
  }) async {
    _log.d('[OTP] OtpDispatchCubit.handleCommand started for commandId: $commandId');
    emit(const OtpFetching());

    final fetchResult = await _receiveUseCase.execute(
      commandId: commandId,
      systemId: systemId,
    );
    _log.d('[OTP] OtpDispatchCubit fetchResult: $fetchResult');

    await fetchResult.fold(
      (f) async => emit(OtpError(_otpFailureMsg(f))),
      (command) async {
        emit(const OtpDispatching());
        _log.d('[OTP] OtpDispatchCubit executing SMS dispatch...');

        final executeResult = await _executeUseCase.execute(command);
        _log.d('[OTP] OtpDispatchCubit executeResult: $executeResult');

        await executeResult.fold(
          (f) async {
             _log.d('[OTP] OtpDispatchCubit executeResult failed: $f');
             emit(OtpError(_otpFailureMsg(f)));
          },
          (report) async {
            final reportResult = await _reportUseCase.execute(
              report: report,
              systemId: systemId,
            );
            reportResult.fold(
              (f) => emit(OtpError(_otpFailureMsg(f))),
              (_) => emit(const OtpDispatched()),
            );
          },
        );
      },
    );
  }

  String _otpFailureMsg(OtpGatewayFailure f) => switch (f) {
        CommandNotFoundFailure() => 'OTP command not found.',
        CommandAlreadyDispatchedFailure() => 'Command already dispatched.',
        SmsDispatchFailure(:final detail) => 'SMS dispatch failed: $detail',
        ReportSubmissionFailure(:final detail) =>
          'Report submission failed: $detail',
        _ => 'An unexpected error occurred.',
      };
}