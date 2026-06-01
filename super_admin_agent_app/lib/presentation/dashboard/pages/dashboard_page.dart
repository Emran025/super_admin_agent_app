import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/app_module.dart';
import '../../../domain/pairing/entities/linked_system.dart';
import '../../../domain/pairing/entities/paired_system.dart';
import '../../../shared/domain/paired_system_registry.dart';
import '../../../shared/domain/audit_log_service.dart';
import '../../pairing/cubit/pairing_cubit.dart';
import '../../pairing/cubit/pairing_state.dart';
import '../cubit/linked_systems_cubit.dart';

import 'package:super_admin_agent/presentation/shared/theme/color_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/radius_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/spacing_tokens.dart';
import 'package:super_admin_agent/presentation/shared/widgets/custom_button.dart';
import 'package:super_admin_agent/presentation/shared/widgets/custom_card.dart';
import 'package:super_admin_agent/presentation/shared/widgets/status_dot.dart';

/// Redesigned DashboardPage displaying the Operations Control Center.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<AuditEntry> _recentLogs = [];
  bool _loadingLogs = false;
  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    _loadLinkedSystems();
    _loadLogs();
  }

  void _loadLinkedSystems() {
    final registry = getIt<PairedSystemRegistry>();
    if (registry.all.isNotEmpty) {
      final gatewaySystemId = registry.all.first.systemId;
      context.read<LinkedSystemsCubit>().loadSystems(gatewaySystemId);
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    final result = await getIt<AuditLogService>().queryAll();
    result.fold(
      (_) => setState(() => _loadingLogs = false),
      (logs) {
        final reversed = logs.reversed.toList();
        setState(() {
          _recentLogs = reversed.take(5).toList();
          _loadingLogs = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final registry = getIt<PairedSystemRegistry>();
    final cs = Theme.of(context).colorScheme;
    final systems = registry.all;
    final primarySystem = systems.isNotEmpty ? systems.first : null;

    return BlocListener<PairingCubit, PairingState>(
      listener: (context, state) {
        if (state is PairingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.error,
              behavior: SnackBarBehavior.floating,
              content: Text(
                state.message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        } else if (state is PairingIdle) {
          Navigator.of(context).pushReplacementNamed('/pair');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agent Control Center'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _refreshAll,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About',
              onPressed: () => _showAboutDialog(context),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            _refreshAll();
          },
          child: _buildBody(context, systems, primarySystem),
        ),
        floatingActionButton: systems.isEmpty
            ? FloatingActionButton.extended(
                heroTag: 'operations_pair_fab',
                onPressed: () => Navigator.of(context).pushNamed('/pair'),
                icon: const Icon(Icons.add),
                label: const Text('Pair System'),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              )
            : FloatingActionButton.extended(
                heroTag: 'operations_link_fab',
                onPressed: () async {
                  final linked = await Navigator.of(context).pushNamed('/link-system');
                  if (linked == true && mounted) {
                    _refreshAll();
                  }
                },
                icon: const Icon(Icons.link),
                label: const Text('Link External System'),
                backgroundColor: cs.secondary,
                foregroundColor: cs.onSecondary,
              ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<PairedSystem> systems,
    PairedSystem? primarySystem,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (systems.isEmpty || primarySystem == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_off, size: 72, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: SpacingTokens.md),
              Text(
                'System Offline',
                style: tt.headlineSmall,
              ),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                'This agent is currently not paired to any system. Pair with a server gateway to enable operations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: SpacingTokens.lg),
              CustomButton(
                label: 'Begin Pairing',
                icon: Icons.qr_code_scanner,
                onPressed: () => Navigator.of(context).pushNamed('/pair'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md, vertical: SpacingTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Connection Status Banner
          _buildStatusBanner(context, primarySystem),
          const SizedBox(height: SpacingTokens.lg),

          // 2. Active Capabilities Panel
          Text(
            'ACTIVE GATEWAY CAPABILITIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          _buildCapabilitiesList(primarySystem),
          const SizedBox(height: SpacingTokens.lg),

          // 3. Linked External Systems
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LINKED EXTERNAL SYSTEMS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              if (_loadingLogs)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          _buildLinkedSystemsSection(primarySystem),
          const SizedBox(height: SpacingTokens.lg),

          // 4. Audit Log Timeline
          Text(
            'RECENT SECURITY EVENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          _buildAuditLogsSection(),
          const SizedBox(height: SpacingTokens.xl),

          // 5. Explicit Unpair Button (Clear & Prominent)
          CustomCard(
            backgroundColor: cs.error.withValues(alpha: 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, color: cs.error, size: 36),
                const SizedBox(height: SpacingTokens.sm),
                const Text(
                  'Disconnect System',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  'Unpairing resets secure cryptographic keys. The agent will immediately stop listening to WebSocket triggers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: SpacingTokens.md),
                CustomButton(
                  label: 'Unpair & Reset Agent',
                  variant: CustomButtonVariant.danger,
                  icon: Icons.link_off,
                  height: 44,
                  onPressed: () => _confirmUnpair(context, primarySystem),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80), // bottom spacer for FAB
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, PairedSystem system) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomCard(
      hasGradientBorder: true,
      padding: const EdgeInsets.all(SpacingTokens.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusDot(status: ConnectionStatus.connected, size: 10),
              const SizedBox(width: 8),
              const Text(
                'Connected & Listening',
                style: TextStyle(
                  color: ColorTokens.emerald500,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(RadiusTokens.xs),
                ),
                child: const Text(
                  'PRIMARY',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            system.systemLabel,
            style: tt.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Gateway: ${system.baseUrl}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontFamily: 'monospace'),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AGENT ID', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      system.agentId.length > 18 ? '${system.agentId.substring(0, 18)}...' : system.agentId,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PAIRED DATE', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      system.pairedAt.toLocal().toString().split(' ').first,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesList(PairedSystem system) {
    final cs = Theme.of(context).colorScheme;

    final allCaps = [
      {'id': 'otp_gateway', 'name': 'SMS Gateway', 'desc': 'Receives commands to broadcast real SMS tokens.'},
      {'id': 'two_fa', 'name': '2FA Push Approval', 'desc': 'Prompt challenge overlays for admin dashboard sign-in.'},
      {'id': 'payment_observation', 'name': 'Payment Watch', 'desc': 'Observes notifications to report transaction tokens.'},
    ];

    return Column(
      children: allCaps.map((cap) {
        final isActive = system.hasCapability(cap['id']!);
        final icon = cap['id'] == 'otp_gateway'
            ? Icons.sms_outlined
            : cap['id'] == 'two_fa'
                ? Icons.security_outlined
                : Icons.payments_outlined;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: CustomCard(
            backgroundColor: isActive ? null : cs.surfaceContainerLow.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: isActive ? cs.secondary : cs.onSurfaceVariant, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cap['name']!,
                        style: TextStyle(
                          color: isActive ? Colors.white : cs.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cap['desc']!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: isActive ? 1.0 : 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? ColorTokens.emerald500.withValues(alpha: 0.1) : cs.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(RadiusTokens.sm),
                    border: Border.all(
                      color: isActive ? ColorTokens.emerald500.withValues(alpha: 0.3) : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    isActive ? 'ENABLED' : 'DISABLED',
                    style: TextStyle(
                      color: isActive ? ColorTokens.emerald400 : cs.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLinkedSystemsSection(PairedSystem primarySystem) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<LinkedSystemsCubit, LinkedSystemsState>(
      builder: (context, state) {
        if (state is LinkedSystemsLoading) {
          return const CustomCard(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (state is LinkedSystemsError) {
          return CustomCard(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(state.message, style: TextStyle(color: cs.error, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                CustomButton(
                  label: 'Retry Load',
                  variant: CustomButtonVariant.secondary,
                  height: 36,
                  onPressed: _loadLinkedSystems,
                ),
              ],
            ),
          );
        }

        if (state is LinkedSystemsLoaded) {
          if (state.systems.isEmpty) {
            return CustomCard(
              backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.layers_outlined, color: cs.onSurfaceVariant, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'No external client systems linked yet.\nLink a system to observe transactions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: state.systems.map((linkedSystem) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: CustomCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (linkedSystem.isTest ? Colors.orange : cs.primary).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          linkedSystem.isTest ? Icons.bug_report : Icons.business,
                          color: linkedSystem.isTest ? Colors.orange : cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              linkedSystem.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${linkedSystem.id.length > 15 ? "${linkedSystem.id.substring(0, 15)}..." : linkedSystem.id}',
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: linkedSystem.capabilities.map((c) {
                                final (label, color) = switch (c) {
                                  'otp' || 'otp_gateway' => ('SMS Gateway', ColorTokens.emerald500),
                                  'super_admin_login' || 'two_fa' => ('2FA Push', cs.primary),
                                  'payment' || 'payment_observation' => ('Payment Watch', cs.secondary),
                                  _ => (c, cs.onSurfaceVariant),
                                };
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(RadiusTokens.xs),
                                    border: Border.all(color: color.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.link_off, color: cs.error, size: 20),
                        tooltip: 'Unlink client system',
                        onPressed: () => _confirmUnlink(context, primarySystem.systemId, linkedSystem),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildAuditLogsSection() {
    final cs = Theme.of(context).colorScheme;

    if (_recentLogs.isEmpty) {
      return CustomCard(
        backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_toggle_off, color: cs.onSurfaceVariant, size: 28),
              const SizedBox(height: 8),
              Text(
                'No events recorded in audit log yet.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: _recentLogs.map((log) {
          final isSuccess = log.outcome == AuditOutcome.success;
          final timeStr = log.timestamp.toLocal().toString().split(' ').last.substring(0, 5);
          final dateStr = log.timestamp.toLocal().toString().split(' ').first.substring(5);

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getLogColor(log.actionType, cs).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(RadiusTokens.md),
              ),
              child: Icon(
                _getLogIcon(log.actionType),
                color: _getLogColor(log.actionType, cs),
                size: 18,
              ),
            ),
            title: Text(
              _getLogTitle(log.actionType),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
            ),
            subtitle: Text(
              isSuccess ? 'Completed successfully' : 'Failed: ${log.failureCode ?? "Unknown error"}',
              style: TextStyle(
                color: isSuccess ? cs.onSurfaceVariant : cs.error.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getLogIcon(AuditActionType type) {
    switch (type) {
      case AuditActionType.pairingCompleted:
      case AuditActionType.pairingFailed:
        return Icons.link;
      case AuditActionType.unpairingCompleted:
        return Icons.link_off;
      case AuditActionType.challengeReceived:
      case AuditActionType.challengeResponded:
      case AuditActionType.challengeSubmissionFailed:
        return Icons.lock_person;
      case AuditActionType.otpDispatchReceived:
      case AuditActionType.otpSmsSent:
      case AuditActionType.otpSmsFailed:
      case AuditActionType.otpReportSubmitted:
        return Icons.sms;
      default:
        return Icons.security;
    }
  }

  Color _getLogColor(AuditActionType type, ColorScheme cs) {
    switch (type) {
      case AuditActionType.pairingCompleted:
      case AuditActionType.challengeResponded:
      case AuditActionType.otpSmsSent:
      case AuditActionType.otpReportSubmitted:
        return ColorTokens.emerald500;
      case AuditActionType.pairingFailed:
      case AuditActionType.challengeSubmissionFailed:
      case AuditActionType.otpSmsFailed:
      case AuditActionType.unknownCommandRejected:
      case AuditActionType.signingFailure:
        return cs.error;
      default:
        return cs.primary;
    }
  }

  String _getLogTitle(AuditActionType type) {
    switch (type) {
      case AuditActionType.pairingCompleted:
        return 'System Paired';
      case AuditActionType.pairingFailed:
        return 'Pairing Failed';
      case AuditActionType.unpairingCompleted:
        return 'System Unpaired';
      case AuditActionType.challengeReceived:
        return '2FA Challenge Received';
      case AuditActionType.challengeResponded:
        return '2FA Challenge Decision';
      case AuditActionType.challengeSubmissionFailed:
        return '2FA Submission Failed';
      case AuditActionType.otpDispatchReceived:
        return 'SMS Request Received';
      case AuditActionType.otpSmsSent:
        return 'SMS OTP Dispatched';
      case AuditActionType.otpSmsFailed:
        return 'SMS Dispatch Failed';
      case AuditActionType.otpReportSubmitted:
        return 'SMS Gateway Report';
      case AuditActionType.unknownCommandRejected:
        return 'Command Rejected (CF)';
      case AuditActionType.signingFailure:
        return 'Signing Error';
      default:
        return 'Security Event';
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Super Admin Agent',
      applicationVersion: '1.0.0',
      children: const [
        Text(
          'A zero-trust cryptographic background relay agent bound to a primary host gateway.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    String gatewaySystemId,
    LinkedSystem linkedSystem,
  ) async {
    final cubit = context.read<LinkedSystemsCubit>();
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink System'),
        content: Text(
          'Are you sure you want to unlink client system "${linkedSystem.name}"?\n\n'
          'This removes its observational access from the gateway.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('UNLINK'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await cubit.unlinkSystem(
        gatewaySystemId: gatewaySystemId,
        systemId: linkedSystem.id,
      );
      _refreshAll();
    }
  }

  Future<void> _confirmUnpair(BuildContext context, PairedSystem system) async {
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Reset'),
        content: Text(
          'Unpair from "${system.systemLabel}"?\n\n'
          'This will purge all local keys and encryption configurations. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('UNPAIR & RESET'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<PairingCubit>().unpair(system.systemId);
    }
  }
}
