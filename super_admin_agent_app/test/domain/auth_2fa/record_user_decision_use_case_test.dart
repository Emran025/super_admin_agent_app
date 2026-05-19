import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/auth_2fa/entities/auth_challenge.dart';
import 'package:super_admin_agent/domain/auth_2fa/entities/challenge_status.dart';
import 'package:super_admin_agent/domain/auth_2fa/repositories/auth_challenge_repository.dart';
import 'package:super_admin_agent/domain/auth_2fa/use_cases/record_user_decision_use_case.dart';
import 'package:super_admin_agent/domain/auth_2fa/value_objects/agent_decision.dart';
import 'package:super_admin_agent/shared/domain/nonce_generator.dart';
import 'package:super_admin_agent/shared/domain/signing_service.dart';

class MockSigningService extends Mock implements SigningService {}
class MockNonceGenerator extends Mock implements NonceGenerator {}

void main() {
  late MockSigningService signingService;
  late MockNonceGenerator nonceGenerator;
  late RecordUserDecisionUseCase useCase;

  setUp(() {
    signingService = MockSigningService();
    nonceGenerator = MockNonceGenerator();
    useCase = RecordUserDecisionUseCase(
      signingService: signingService,
      nonceGenerator: nonceGenerator,
    );

    when(() => signingService.publicKeyId).thenReturn('key-1');
  });

  AuthChallenge createChallenge(ChallengeStatus status) => AuthChallenge(
        challengeId: 'chal-1',
        systemId: 'sys-1',
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        contextLabel: 'Test Login',
        status: status,
      );

  test('non-pending challenge returns ChallengeAlreadyRespondedException without signing', () async {
    final result = await useCase.execute(
      challenge: createChallenge(ChallengeStatus.responded),
      decision: AgentDecision.approve,
    );

    expect(result, const Left(ChallengeAlreadyRespondedException()));
    verifyNever(() => nonceGenerator.generate());
    verifyNever(() => signingService.sign(any()));
  });

  test('pending challenge generates fresh nonce and signs canonical input', () async {
    when(() => nonceGenerator.generate()).thenReturn('nonce-abc');
    when(() => signingService.sign(any())).thenAnswer((_) async => const Right('sig-123'));

    final result = await useCase.execute(
      challenge: createChallenge(ChallengeStatus.pending),
      decision: AgentDecision.reject,
    );

    expect(result.isRight(), isTrue);
    final response = result.getOrElse(() => throw Exception('Expected right'));
    
    expect(response.signature, 'sig-123');
    expect(response.nonce, 'nonce-abc');
    expect(response.decision, AgentDecision.reject);
    
    // Verify nonce was generated exactly once per call
    verify(() => nonceGenerator.generate()).called(1);
    
    // Capture and verify signing input format (JSON + nonce + timestamp)
    final captured = verify(() => signingService.sign(captureAny())).captured;
    final signingInput = captured.first as String;
    expect(signingInput, contains('nonce-abc'));
    expect(signingInput, contains('"decision":"reject"'));
  });

  test('two consecutive calls generate different nonces (Invariant 4)', () async {
    when(() => nonceGenerator.generate()).thenReturn('nonce-1');
    when(() => signingService.sign(any())).thenAnswer((_) async => const Right('sig'));

    final res1 = await useCase.execute(
      challenge: createChallenge(ChallengeStatus.pending),
      decision: AgentDecision.approve,
    );

    when(() => nonceGenerator.generate()).thenReturn('nonce-2');
    
    final res2 = await useCase.execute(
      challenge: createChallenge(ChallengeStatus.pending),
      decision: AgentDecision.approve,
    );

    expect(res1.getOrElse(() => throw Exception()).nonce, 'nonce-1');
    expect(res2.getOrElse(() => throw Exception()).nonce, 'nonce-2');
    verify(() => nonceGenerator.generate()).called(2);
  });
}
