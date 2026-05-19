import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:super_admin_agent/domain/pairing/entities/paired_system.dart';
import 'package:super_admin_agent/shared/domain/audit_log_service.dart';
import 'package:super_admin_agent/shared/domain/paired_system_registry.dart';
import 'package:super_admin_agent/shared/infrastructure/ws_message_router.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------

class MockPairedSystemRegistry extends Mock implements PairedSystemRegistry {}

class MockAuditLogService extends Mock implements AuditLogService {}

class MockCapabilityCommandHandler extends Mock
    implements CapabilityCommandHandler {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PairedSystem _system({List<String> capabilities = const ['two_fa']}) =>
    PairedSystem(
      agentId: 'agent-1',
      systemId: 'sys-1',
      systemLabel: 'Test System',
      baseUrl: 'https://server.example.com',
      grantedCapabilities: capabilities,
      pairedAt: DateTime.now(),
    );

class _FakeAuditEntry extends Fake implements AuditEntry {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPairedSystemRegistry registry;
  late MockAuditLogService auditLog;
  late MockCapabilityCommandHandler handler;
  late WsMessageRouter router;

  setUpAll(() {
    // Mocktail requires fallback values for custom types used with any().
    registerFallbackValue(_FakeAuditEntry());
  });

  setUp(() {
    registry = MockPairedSystemRegistry();
    auditLog = MockAuditLogService();
    handler = MockCapabilityCommandHandler();
    router = WsMessageRouter(
      registry: registry,
      auditLogService: auditLog,
    );

    // Default: audit log accepts anything.
    when(() => auditLog.log(any())).thenAnswer((_) async => const Right(null));
    // Default: handler does nothing.
    when(() => handler.handle(
          commandId: any(named: 'commandId'),
          systemId: any(named: 'systemId'),
        )).thenAnswer((_) async {});
  });

  group('WsMessageRouter stop conditions', () {
    test('missing capability field → handler never called, audit log written',
        () async {
      await router.route({
        'command_id': 'cmd-1',
        'system_id': 'sys-1',
        // 'capability' is missing
      });

      verifyNever(() => handler.handle(
            commandId: any(named: 'commandId'),
            systemId: any(named: 'systemId'),
          ));
      verify(() => auditLog.log(any())).called(1);
    });

    test('unknown system_id → handler never called (CF-03)', () async {
      when(() => registry.findBySystemId('unknown-sys')).thenReturn(null);

      await router.route({
        'capability': 'two_fa',
        'command_id': 'cmd-1',
        'system_id': 'unknown-sys',
      });

      verifyNever(() => handler.handle(
            commandId: any(named: 'commandId'),
            systemId: any(named: 'systemId'),
          ));
      verify(() => auditLog.log(any())).called(1);
    });

    test('capability not granted to system → handler never called (CF-05)',
        () async {
      when(() => registry.findBySystemId('sys-1'))
          .thenReturn(_system(capabilities: ['otp_gateway']));

      await router.route({
        'capability': 'two_fa', // not in grantedCapabilities
        'command_id': 'cmd-1',
        'system_id': 'sys-1',
      });

      verifyNever(() => handler.handle(
            commandId: any(named: 'commandId'),
            systemId: any(named: 'systemId'),
          ));
      verify(() => auditLog.log(any())).called(1);
    });

    test('no handler registered for capability → handler never called (Axiom 10)',
        () async {
      when(() => registry.findBySystemId('sys-1'))
          .thenReturn(_system(capabilities: ['two_fa']));
      // No handler registered for 'two_fa'.

      await router.route({
        'capability': 'two_fa',
        'command_id': 'cmd-1',
        'system_id': 'sys-1',
      });

      verifyNever(() => handler.handle(
            commandId: any(named: 'commandId'),
            systemId: any(named: 'systemId'),
          ));
      verify(() => auditLog.log(any())).called(1);
    });

    test('valid message → handler called exactly once with correct ids',
        () async {
      when(() => registry.findBySystemId('sys-1'))
          .thenReturn(_system(capabilities: ['two_fa']));

      router.registerHandler('two_fa', handler);

      await router.route({
        'capability': 'two_fa',
        'command_id': 'cmd-abc',
        'system_id': 'sys-1',
      });

      verify(() => handler.handle(
            commandId: 'cmd-abc',
            systemId: 'sys-1',
          )).called(1);
      verifyNever(() => auditLog.log(any()));
    });
  });
}
