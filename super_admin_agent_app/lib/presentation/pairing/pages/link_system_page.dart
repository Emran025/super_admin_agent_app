import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../di/app_module.dart';
import '../../../shared/domain/paired_system_registry.dart';
import '../../dashboard/cubit/linked_systems_cubit.dart';

class LinkSystemPage extends StatefulWidget {
  const LinkSystemPage({super.key});

  @override
  State<LinkSystemPage> createState() => _LinkSystemPageState();
}

class _LinkSystemPageState extends State<LinkSystemPage> {
  Map<String, dynamic>? _scannedData;
  bool _isLoading = false;
  String? _errorMessage;

  void _onQrScanned(String rawValue) {
    try {
      final data = jsonDecode(rawValue) as Map<String, dynamic>;
      if (!data.containsKey('system_id')) {
        setState(() {
          _errorMessage = 'Invalid QR code: Missing system_id';
        });
        return;
      }
      setState(() {
        _scannedData = data;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid QR code format';
      });
    }
  }

  Future<void> _confirmLink() async {
    if (_scannedData == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final registry = getIt<PairedSystemRegistry>();
    if (registry.all.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No primary gateway system paired.';
      });
      return;
    }

    final gatewaySystemId = registry.all.first.systemId;
    final systemId = _scannedData!['system_id'] as String;

    final navigator = Navigator.of(context);
    final success = await context.read<LinkedSystemsCubit>().linkSystem(
          gatewaySystemId: gatewaySystemId,
          systemId: systemId,
        );

    if (mounted) {
      if (success) {
        navigator.pop(true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to link system on the server.';
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _scannedData = null;
      _errorMessage = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link External System'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Linking external system...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _resetScanner,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_scannedData != null) {
      final systemId = _scannedData!['system_id'] as String;
      final capabilities = List<String>.from(_scannedData!['capabilities'] ?? []);
      final isTest = _scannedData!['is_test'] as bool? ?? false;

      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Link Scanned System',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _row('System ID', systemId),
                    const Divider(),
                    _row('Capabilities', capabilities.isEmpty ? 'None' : capabilities.join(', ')),
                    const Divider(),
                    _row('Environment', isTest ? 'Sandbox / Test' : 'Production'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _confirmLink,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm and Link'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _resetScanner,
              child: const Text('Cancel / Scan Again'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final raw = barcodes.first.rawValue;
            if (raw == null || raw.isEmpty) return;
            _onQrScanned(raw);
          },
        ),
        _buildScannerOverlay(),
      ],
    );
  }

  Widget _buildScannerOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(128),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Position the QR code inside the box',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
