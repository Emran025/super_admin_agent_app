import '../entities/bank_sms_observation.dart';
import '../entities/payment_observation_session.dart';
import '../entities/session_status.dart';
import '../../../shared/domain/sms_parsing_service.dart';

/// A raw incoming SMS event from the device's SMS broadcast receiver.
///
/// [body] is write-only — passed directly to [SmsParsingService.parse()]
/// and never referenced again after that call.
class RawSmsEvent {
  final String senderName;
  final String body;
  final DateTime receivedAt;

  const RawSmsEvent({
    required this.senderName,
    required this.body,
    required this.receivedAt,
  });
}

/// Validates and parses an incoming SMS against an active observation session.
///
/// Returns [null] (a non-event) when:
/// - The session is not active (Invariant 4)
/// - The SMS is not from the expected sender (Invariant 3)
///
/// Returns a [BankSmsObservation] with possibly-null parsed fields when:
/// - The sender matches but the template fails to parse (Invariant 6)
/// - The sender matches and the template succeeds
///
/// The raw [event.body] is NEVER assigned to a local variable — it is
/// passed directly as the argument to [SmsParsingService.parse()] (Invariant 1).
class ProcessIncomingSmsUseCase {
  final SmsParsingService _parsingService;
  final String Function() _generateId;

  ProcessIncomingSmsUseCase({
    required SmsParsingService parsingService,
    String Function()? generateId,
  })  : _parsingService = parsingService,
        _generateId = generateId ?? (() => DateTime.now().microsecondsSinceEpoch.toString());

  BankSmsObservation? execute({
    required RawSmsEvent event,
    required PaymentObservationSession session,
  }) {
    // Invariant 4: Only process SMS when session is active.
    if (session.status != SessionStatus.active) return null;

    // Invariant 3: Only process SMS from the expected bank sender.
    if (event.senderName.trim().toLowerCase() !=
        session.expectedSenderName.trim().toLowerCase()) {
      return null;
    }

    // Invariant 1: event.body is passed directly — no local variable assignment.
    final parsed = _parsingService.parse(
      rawSmsBody: event.body,
      parsingTemplate: session.parsingTemplate,
    );

    // After parse() returns, event.body is not referenced again.
    return BankSmsObservation(
      observationId: _generateId(),
      sessionId: session.sessionId,
      receivedAt: event.receivedAt,
      parsedPayerName: parsed.payerName,
      parsedAmount: parsed.amount,
      parsedCurrency: parsed.currency,
    );
  }
}
