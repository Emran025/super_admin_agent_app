import 'package:dartz/dartz.dart';
import '../entities/dispatch_status.dart';
import '../entities/otp_dispatch_command.dart';
import '../repositories/otp_gateway_repository.dart';
import '../value_objects/sms_delivery_report.dart';
import '../../../shared/data/canonical_json.dart';
import '../../../shared/domain/nonce_generator.dart';
import '../../../shared/domain/signing_service.dart';

/// Domain interface for the SMS sender — implemented by [AndroidSmsSenderService].
///
/// Lives in the domain use case file so the domain defines the contract
/// while the platform provides the mechanism (Constraint 2.5).
/// Keeps the domain free of Flutter/platform imports (AF-01).
abstract class SmsSenderService {
  Future<SmsDeliveryStatus> send({
    required String recipientPhoneNumber,
    required String messageBody,
    required SimSlot simSlot,
  });
}

/// Sends the OTP SMS and produces a signed delivery report.
///
/// Enforces Invariant 1 (write-only message body): [command.messageBody]
/// is passed DIRECTLY to [SmsSenderService.send()] — no local variable,
/// no assignment to any field. After [send()] returns, the body is unreachable.
class ExecuteSmsDispatchUseCase {
  final SmsSenderService _smsSenderService;
  final SigningService _signingService;
  final NonceGenerator _nonceGenerator;

  const ExecuteSmsDispatchUseCase({
    required SmsSenderService smsSenderService,
    required SigningService signingService,
    required NonceGenerator nonceGenerator,
  })  : _smsSenderService = smsSenderService,
        _signingService = signingService,
        _nonceGenerator = nonceGenerator;

  Future<Either<OtpGatewayFailure, SmsDeliveryReport>> execute(
    OtpDispatchCommand command,
  ) async {
    // Constraint 2.3: idempotency guard — never re-send.
    if (command.status != DispatchStatus.pending) {
      return const Left(CommandAlreadyDispatchedFailure());
    }

    // Invariant 1: messageBody passed directly — no assignment to local var.
    final deliveryStatus = await _smsSenderService.send(
      recipientPhoneNumber: command.recipientPhoneNumber,
      messageBody: command.messageBody, // Write-only: used only here.
      simSlot: command.simSlot,
    );

    // After send() returns, command.messageBody is not referenced again.
    final reportedAt = DateTime.now().toUtc();
    final nonce = _nonceGenerator.generate();

    final signingInput = CanonicalJson.encode({
      'command_id': command.commandId,
      'nonce': nonce,
      'reported_at': reportedAt.toIso8601String(),
      'status': deliveryStatus.name,
    }) + '\n$nonce\n${reportedAt.toIso8601String()}';

    final signResult = await _signingService.sign(signingInput);

    return signResult.fold(
      (f) => Left(SmsDispatchFailure('Signing failed: ${f.runtimeType}')),
      (signature) => Right(
        SmsDeliveryReport(
          commandId: command.commandId,
          status: deliveryStatus,
          reportedAt: reportedAt,
          nonce: nonce,
          signature: signature,
          agentPublicKeyId: _signingService.publicKeyId,
        ),
      ),
    );
  }
}
