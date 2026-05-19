import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/app_module.dart';
import '../../../domain/pairing/entities/paired_system.dart';
import '../../../shared/domain/paired_system_registry.dart';
import '../../pairing/cubit/pairing_cubit.dart';
import '../../pairing/cubit/pairing_state.dart';

/// Displays all paired systems and their granted capabilities.
///
/// Constitutional constraints:
/// - READ-ONLY display: system label, agent ID, capabilities (Constraint 2.3)
/// - One control per system: unpair button with confirmation dialog
/// - No capability runtime data shown (2FA status, OTP logs, payment state)
/// - Dashboard is stateless — reads directly from [PairedSystemRegistry]
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PairingCubit, PairingState>(
      listener: (context, state) {
        if (state is PairingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
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
        body: _buildBody(context),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).pushNamed('/pair'),
          icon: const Icon(Icons.add),
          label: const Text('Pair System'),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final registry = getIt<PairedSystemRegistry>();
    final systems = registry.all;

    if (systems.isEmpty) {
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: systems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _SystemCard(system: systems[index]),
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
}

class _SystemCard extends StatelessWidget {
  final PairedSystem system;

  const _SystemCard({required this.system});

  @override
  Widget build(BuildContext context) {
    return Card(
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
              'Paired',
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
