import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_admin_agent/data/otp_gateway/repositories/otp_gateway_repository_impl.dart';
import 'package:super_admin_agent/shared/data/http_client_factory.dart';

class MockHttpClientFactory extends Mock implements HttpClientFactory {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockHttpClientFactory clientFactory;
  late MockDio dio;
  late OtpGatewayRepositoryImpl repository;

  setUp(() {
    clientFactory = MockHttpClientFactory();
    dio = MockDio();
    repository = OtpGatewayRepositoryImpl(clientFactory: clientFactory);

    when(() => clientFactory.forSystem(any())).thenReturn(dio);
  });

  group('OtpGatewayRepositoryImpl cache override', () {
    test('fetches command and overrides messageBody if cache hit, then clears cache', () async {
      const commandId = 'cmd-1';
      const systemId = 'sys-1';
      const plaintextOtpMessage = 'Hi! Your verification code is: 123456';
      
      // Stub the GET response from the server (which returns the template message)
      when(() => dio.get<Map<String, dynamic>>('/api/v1/otp-commands/$commandId'))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: ''),
                statusCode: 200,
                data: {
                  'command_id': commandId,
                  'system_id': systemId,
                  'recipient_phone_number': '+1234567890',
                  'message_body': 'Your verification code was delivered via the secure agent channel.',
                  'issued_at': '2026-05-19T22:00:00Z',
                  'sim_slot': 'defaultSlot',
                },
              ));

      // Cache the actual plaintext message body
      repository.cacheMessageBody(commandId, plaintextOtpMessage);

      // Call fetchCommand
      final result = await repository.fetchCommand(
        commandId: commandId,
        systemId: systemId,
      );

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not fail'),
        (command) {
          expect(command.commandId, commandId);
          expect(command.recipientPhoneNumber, '+1234567890');
          // Message body must be the overridden plaintext OTP, not the template
          expect(command.messageBody, plaintextOtpMessage);
        },
      );

      // A subsequent fetchCommand should NOT have the cached body anymore (since it's removed on fetch)
      final secondResult = await repository.fetchCommand(
        commandId: commandId,
        systemId: systemId,
      );

      expect(secondResult.isRight(), true);
      secondResult.fold(
        (failure) => fail('Should not fail'),
        (command) {
          // Should return the server's template body
          expect(command.messageBody, 'Your verification code was delivered via the secure agent channel.');
        },
      );
    });
  });
}
