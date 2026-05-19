import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/otp_gateway/entities/dispatch_status.dart';
import 'package:super_admin_agent/domain/otp_gateway/entities/otp_dispatch_command.dart';
import 'package:super_admin_agent/domain/otp_gateway/repositories/otp_gateway_repository.dart';
import 'package:super_admin_agent/domain/otp_gateway/use_cases/execute_sms_dispatch_use_case.dart';
import 'package:super_admin_agent/domain/otp_gateway/value_objects/sms_delivery_report.dart';
import 'package:super_admin_agent/shared/domain/nonce_generator.dart';
import 'package:super_admin_agent/shared/domain/signing_service.dart';

class MockSmsSenderService extends Mock implements SmsSenderService {}
class MockSigningService extends Mock implements SigningService {}
class MockNonceGenerator extends Mock implements NonceGenerator {}

void main() {
  setUpAll(() {
    registerFallbackValue(SimSlot.defaultSlot);
  });

  late MockSmsSenderService smsSenderService;
  late MockSigningService signingService;
  late MockNonceGenerator nonceGenerator;
  late ExecuteSmsDispatchUseCase useCase;

  setUp(() {
    smsSenderService = MockSmsSenderService();
    signingService = MockSigningService();
    nonceGenerator = MockNonceGenerator();
    useCase = ExecuteSmsDispatchUseCase(
      smsSenderService: smsSenderService,
      signingService: signingService,
      nonceGenerator: nonceGenerator,
    );

    when(() => signingService.publicKeyId).thenReturn('key-1');
  });

  OtpDispatchCommand createCommand(DispatchStatus status) => OtpDispatchCommand(
        commandId: 'cmd-1',
        systemId: 'sys-1',
        recipientPhoneNumber: '+1234567890',
        messageBody: 'Your OTP is 123456',
        issuedAt: DateTime.now(),
        simSlot: SimSlot.defaultSlot,
        status: status,
      );

  test('non-pending command returns CommandAlreadyDispatchedFailure without sending SMS', () async {
    final result = await useCase.execute(createCommand(DispatchStatus.dispatched));

    expect(result, const Left(CommandAlreadyDispatchedFailure()));
    verifyNever(() => smsSenderService.send(
          recipientPhoneNumber: '+1234567890',
          messageBody: 'Your OTP is 123456',
          simSlot: SimSlot.defaultSlot,
        ));
  });

  test('pending command sends SMS and returns signed report', () async {
    when(() => smsSenderService.send(
          recipientPhoneNumber: '+1234567890',
          messageBody: 'Your OTP is 123456',
          simSlot: SimSlot.defaultSlot,
        )).thenAnswer((_) async => SmsDeliveryStatus.sent);
    when(() => nonceGenerator.generate()).thenReturn('nonce-1');
    when(() => signingService.sign(any())).thenAnswer((_) async => const Right('sig-1'));

    final result = await useCase.execute(createCommand(DispatchStatus.pending));

    expect(result.isRight(), isTrue);
    final report = result.getOrElse(() => throw Exception());
    
    expect(report.signature, 'sig-1');
    expect(report.status, SmsDeliveryStatus.sent);

    verify(() => smsSenderService.send(
          recipientPhoneNumber: '+1234567890',
          messageBody: 'Your OTP is 123456',
          simSlot: SimSlot.defaultSlot,
        )).called(1);
  });
}
