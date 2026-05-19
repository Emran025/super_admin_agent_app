import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/payment_observation/repositories/payment_observation_repository.dart';
import '../../../domain/payment_observation/use_cases/match_observation_to_intent_use_case.dart';
import '../../../domain/payment_observation/use_cases/process_incoming_sms_use_case.dart';
import '../../../domain/payment_observation/use_cases/register_observation_session_use_case.dart';
import '../../../domain/payment_observation/use_cases/report_observation_use_case.dart';
import '../../../shared/infrastructure/sms_receiver_service.dart';
import 'payment_observation_state.dart';

/// Orchestrates the payment observation workflow.
///
/// No business logic here — all rules live in use cases (AF-03).
/// No raw SMS body is ever held in state.
///
/// SMS subscription is cancelled when observation completes or on [close()].
class PaymentObservationCubit extends Cubit<PaymentObservationState> {
  final RegisterObservationSessionUseCase _registerUseCase;
  final ProcessIncomingSmsUseCase _processUseCase;
  final MatchObservationToIntentUseCase _matchUseCase;
  final ReportObservationUseCase _reportUseCase;
  final SmsReceiverService _smsReceiver;

  StreamSubscription<RawSmsEvent>? _smsSubscription;

  PaymentObservationCubit({
    required RegisterObservationSessionUseCase registerUseCase,
    required ProcessIncomingSmsUseCase processUseCase,
    required MatchObservationToIntentUseCase matchUseCase,
    required ReportObservationUseCase reportUseCase,
    required SmsReceiverService smsReceiver,
  })  : _registerUseCase = registerUseCase,
        _processUseCase = processUseCase,
        _matchUseCase = matchUseCase,
        _reportUseCase = reportUseCase,
        _smsReceiver = smsReceiver,
        super(const PaymentObservationIdle());

  /// Fetches the observation session, then begins listening for bank SMS.
  Future<void> startObservation({
    required String sessionId,
    required String systemId,
  }) async {
    emit(const PaymentObservationLoading());

    final result = await _registerUseCase.execute(
      sessionId: sessionId,
      systemId: systemId,
    );

    result.fold(
      (f) => emit(PaymentObservationError(_failureMsg(f))),
      (session) {
        emit(PaymentObservationActive(session.sessionId));

        _smsSubscription = _smsReceiver.incomingSms.listen((event) async {
          final observation = _processUseCase.execute(
            event: event,
            session: session,
          );

          if (observation == null) return; // Non-matching SMS — ignore.

          await _smsSubscription?.cancel();
          _smsSubscription = null;

          final matchResult = _matchUseCase.execute(
            observation: observation,
            session: session,
          );

          final reportResult = await _reportUseCase.execute(
            observation: observation,
            matchResult: matchResult,
            session: session,
          );

          reportResult.fold(
            (f) => emit(PaymentObservationError(_failureMsg(f))),
            (_) => emit(
              PaymentObservationReported(isMatch: matchResult.isMatch),
            ),
          );
        });
      },
    );
  }

  String _failureMsg(PaymentObservationFailure f) => switch (f) {
        SessionNotFoundFailure() => 'Payment session not found.',
        SessionNotActiveFailure() => 'Payment session is no longer active.',
        ReportSubmissionFailure(:final detail) =>
          'Report submission failed: $detail',
        _ => 'An unexpected error occurred.',
      };

  @override
  Future<void> close() async {
    await _smsSubscription?.cancel();
    return super.close();
  }
}
