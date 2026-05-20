import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/app_module.dart';
import '../../../domain/pairing/entities/linked_system.dart';
import '../../../domain/pairing/entities/paired_system.dart';
import '../../../shared/domain/paired_system_registry.dart';
import '../../pairing/cubit/pairing_cubit.dart';
import '../../pairing/cubit/pairing_state.dart';
import '../cubit/linked_systems_cubit.dart';

/// Displays the paired primary system and its linked external systems.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    _loadLinkedSystems();
  }

  void _loadLinkedSystems() {
    final registry = getIt<PairedSystemRegistry>();
    if (registry.all.isNotEmpty) {
      final gatewaySystemId = registry.all.first.systemId;
      context.read<LinkedSystemsCubit>().loadSystems(gatewaySystemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = getIt<PairedSystemRegistry>();
    final systems = registry.all;
    final primarySystem = systems.isNotEmpty ? systems.first : null;

    return BlocListener<PairingCubit, PairingState>(
      listener: (context, state) {
        if (state is PairingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is PairingIdle) {
          Navigator.of(context).pushReplacementNamed('/pair');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Super Admin Agent'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About',
              onPressed: () => _showAboutDialog(context),
            ),
          ],
        ),
        body: _buildBody(context, systems, primarySystem),
        floatingActionButton: systems.isEmpty
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.of(context).pushNamed('/pair'),
                icon: const Icon(Icons.add),
                label: const Text('Pair System'),
              )
            : FloatingActionButton.extended(
                onPressed: () async {
                  final linked = await Navigator.of(context).pushNamed('/link-system');
                  if (linked == true && mounted) {
                    _loadLinkedSystems();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Link System'),
              ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<PairedSystem> systems, PairedSystem? primarySystem) {
    if (systems.isEmpty || primarySystem == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No paired systems',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Tap + to pair a new system.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Primary Gateway Server',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          _SystemCard(system: primarySystem),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Linked External Systems',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh list',
                onPressed: _loadLinkedSystems,
              ),
            ],
          ),
          const SizedBox(height: 8),
          BlocBuilder<LinkedSystemsCubit, LinkedSystemsState>(
            builder: (context, state) {
              if (state is LinkedSystemsLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (state is LinkedSystemsError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          state.message,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadLinkedSystems,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is LinkedSystemsLoaded) {
                if (state.systems.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(
                      child: Text(
                        'No external systems linked.\nTap Link System below to link one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.systems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final linkedSystem = state.systems[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          linkedSystem.isTest ? Icons.bug_report : Icons.business,
                          color: linkedSystem.isTest ? Colors.orange : Colors.indigo,
                        ),
                        title: Text(linkedSystem.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('ID: ${linkedSystem.id}', style: const TextStyle(fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('Capabilities: ${linkedSystem.capabilities.join(', ')}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.link_off, color: Colors.redAccent),
                          tooltip: 'Unlink System',
                          onPressed: () => _confirmUnlink(context, primarySystem.systemId, linkedSystem),
                        ),
                      ),
                    );
                  },
                );
              }

              return const SizedBox();
            },
          ),
          const SizedBox(height: 80), // spacer for FAB
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Super Admin Agent',
      applicationVersion: '0.1.0',
      children: const [
        Text(
          'A private, hardware-bound execution agent for trusted backend systems.',
        ),
      ],
    );
  }

  Future<void> _confirmUnlink(BuildContext context, String gatewaySystemId, LinkedSystem linkedSystem) async {
    final cubit = context.read<LinkedSystemsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink System'),
        content: Text(
          'Are you sure you want to unlink "${linkedSystem.name}"?\n\n'
          'This will remove its mapping on the gateway server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    }
  }
}

class _SystemCard extends StatelessWidget {
  final PairedSystem system;

  const _SystemCard({required this.system});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    system.systemLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.link_off, color: Colors.red),
                  tooltip: 'Unpair',
                  onPressed: () => _confirmUnpair(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _infoRow('Agent ID', system.agentId),
            const SizedBox(height: 4),
            _infoRow(
              'Capabilities',
              system.grantedCapabilities.isEmpty
                  ? 'None'
                  : system.grantedCapabilities.join(', '),
            ),
            const SizedBox(height: 4),
            _infoRow(
              'Paired At',
              system.pairedAt.toLocal().toString().split('.').first,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _confirmUnpair(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpair System'),
        content: Text(
          'Are you sure you want to unpair "${system.systemLabel}"?\n\n'
          'This will remove all stored credentials for this system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('UNPAIR'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<PairingCubit>().unpair(system.systemId);
    }
  }
}
