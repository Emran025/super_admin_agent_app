import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';

import '../domain/audit_log_service.dart';
import '../domain/paired_system_registry.dart';

// ---------------------------------------------------------------------------
// Capability ID constants — mirror Capability value object from Phase 2
// ---------------------------------------------------------------------------

/// String constants for the capability identifiers the FCM router recognises.
///
/// Values must match [Capability.twoFa], [Capability.otpGateway],
/// [Capability.paymentObservation] in [lib/domain/pairing/value_objects/].
abstract class CapabilityId {
  static const String twoFa = 'two_fa';
  static const String otpGateway = 'otp_gateway';
  static const String paymentObservation = 'payment_observation';
}

// ---------------------------------------------------------------------------
// Handler interface
// ---------------------------------------------------------------------------

/// A capability-specific handler invoked by [FcmMessageRouter].
///
/// Implementations live in each capability's data layer.
/// The router NEVER passes the raw [RemoteMessage] to the handler —
/// only the extracted, validated identifiers.
abstract class CapabilityCommandHandler {
  Future<void> handle({required String commandId, required String systemId});
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

/// Routes incoming FCM push messages to the correct capability handler.
///
/// Enforces four stop conditions in strict order (Constraint 2.3):
/// 1. Required fields present: [capability], [command_id], [system_id]
/// 2. [system_id] is a known paired system (CF-03)
/// 3. [capability] is granted to that system (CF-05)
/// 4. A handler is registered for [capability] (Axiom 10)
///
/// Rejections at any stop condition are written to the audit log —
/// NOT just printed — so they are queryable after the fact.
class FcmMessageRouter {
  final PairedSystemRegistry _registry;
  final AuditLogService _auditLogService;
  final Map<String, CapabilityCommandHandler> _handlers = {};
  final _uuid = const Uuid();

  FcmMessageRouter({
    required PairedSystemRegistry registry,
    required AuditLogService auditLogService,
  })  : _registry = registry,
        _auditLogService = auditLogService;

  /// Registers [handler] for [capabilityId].
  ///
  /// Called once during DI bootstrap — each capability registers itself.
  void registerHandler(String capabilityId, CapabilityCommandHandler handler) {
    _handlers[capabilityId] = handler;
  }

  /// Routes [message] through all four stop conditions, then dispatches.
  Future<void> route(RemoteMessage message) async {
    final data = message.data;

    // Stop 1: Required fields present.
    final capability = data['capability'] as String?;
    final commandId = data['command_id'] as String?;
    final systemId = data['system_id'] as String?;

    if (capability == null || commandId == null || systemId == null) {
      await _rejectAndLog(
        systemId: systemId ?? 'unknown',
        commandId: commandId,
        reason: 'Missing required field(s): capability, command_id, system_id',
      );
      return;
    }

    // Stop 2: system_id is a known paired system (CF-03).
    final system = _registry.findBySystemId(systemId);
    if (system == null) {
      await _rejectAndLog(
        systemId: systemId,
        commandId: commandId,
        reason: 'CF-03: Unknown system "$systemId"',
      );
      return;
    }

    // Stop 3: capability is granted to this system (CF-05).
    if (!system.hasCapability(capability)) {
      await _rejectAndLog(
        systemId: systemId,
        commandId: commandId,
        reason: 'CF-05: Capability "$capability" not granted to system "$systemId"',
      );
      return;
    }

    // Stop 4: A handler is registered for this capability (Axiom 10).
    final handler = _handlers[capability];
    if (handler == null) {
      await _rejectAndLog(
        systemId: systemId,
        commandId: commandId,
        reason: 'Axiom-10: No handler registered for capability "$capability"',
      );
      return;
    }

    // All checks passed — dispatch to the handler.
    await handler.handle(commandId: commandId, systemId: systemId);
  }

  Future<void> _rejectAndLog({
    required String systemId,
    String? commandId,
    required String reason,
  }) async {
    await _auditLogService.log(
      AuditEntry(
        entryId: _uuid.v4(),
        actionType: AuditActionType.unknownCommandRejected,
        systemId: systemId,
        commandId: commandId,
        timestamp: DateTime.now().toUtc(),
        outcome: AuditOutcome.failure,
        failureCode: reason,
      ),
    );
  }
}
