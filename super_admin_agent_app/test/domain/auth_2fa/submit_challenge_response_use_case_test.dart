import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/auth_2fa/repositories/auth_challenge_repository.dart';
import 'package:super_admin_agent/domain/auth_2fa/use_cases/submit_challenge_response_use_case.dart';
import 'package:super_admin_agent/domain/auth_2fa/value_objects/agent_decision.dart';
import 'package:super_admin_agent/domain/auth_2fa/value_objects/signed_challenge_response.dart';
import 'package:super_admin_agent/shared/domain/audit_log_service.dart';

class MockAuthChallengeRepository extends Mock implements AuthChallengeRepository {}
class MockAuditLogService extends Mock implements AuditLogService {}
class _FakeAuditEntry extends Fake implements AuditEntry {}
class _FakeSignedChallengeResponse extends Fake implements SignedChallengeResponse {}

void main() {
  late MockAuthChallengeRepository repository;
  late MockAuditLogService auditLogService;
  late SubmitChallengeResponseUseCase useCase;

  setUpAll(() {
    registerFallbackValue(_FakeAuditEntry());
    registerFallbackValue(_FakeSignedChallengeResponse());
  });

  setUp(() {
    repository = MockAuthChallengeRepository();
    auditLogService = MockAuditLogService();
    useCase = SubmitChallengeResponseUseCase(
      repository: repository,
      auditLogService: auditLogService,
    );

    when(() => auditLogService.log(any())).thenAnswer((_) async => const Right(null));
  });

  final testResponse = SignedChallengeResponse(
    challengeId: 'chal-1',
    decision: AgentDecision.approve,
    respondedAt: DateTime.now(),
    nonce: 'n',
    signature: 's',
    agentPublicKeyId: 'k',
  );

  test('audit log partial entry is written BEFORE repository call', () async {
    when(() => repository.submitResponse(response: any(named: 'response'), systemId: any(named: 'systemId')))
        .thenAnswer((_) async => const Right(null));

    await useCase.execute(response: testResponse, systemId: 'sys-1');

    final captured = verify(() => auditLogService.log(captureAny())).captured;
    expect(captured.length, 2);

    final firstEntry = captured.first as AuditEntry;
    expect(firstEntry.outcome, AuditOutcome.partial);
    expect(firstEntry.actionType, AuditActionType.challengeResponded);

    final secondEntry = captured.last as AuditEntry;
    expect(secondEntry.outcome, AuditOutcome.success);
  });

  test('on repository failure, second audit entry records failure', () async {
    when(() => repository.submitResponse(response: any(named: 'response'), systemId: any(named: 'systemId')))
        .thenAnswer((_) async => const Left(ChallengeSubmissionFailure('err')));

    final result = await useCase.execute(response: testResponse, systemId: 'sys-1');
    expect(result.isLeft(), isTrue);

    final captured = verify(() => auditLogService.log(captureAny())).captured;
    expect(captured.length, 2);

    final secondEntry = captured.last as AuditEntry;
    expect(secondEntry.outcome, AuditOutcome.failure);
    expect(secondEntry.actionType, AuditActionType.challengeSubmissionFailed);
    expect(secondEntry.failureCode, 'SUBMISSION_FAILED');
  });
}
