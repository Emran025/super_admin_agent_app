import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../di/app_module.dart';
import '../../../shared/domain/paired_system_registry.dart';
import '../../dashboard/cubit/linked_systems_cubit.dart';

import 'package:super_admin_agent/presentation/shared/theme/color_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/radius_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/spacing_tokens.dart';
import 'package:super_admin_agent/presentation/shared/widgets/custom_button.dart';
import 'package:super_admin_agent/presentation/shared/widgets/custom_card.dart';

/// Redesigned LinkSystemPage for scanning and registering client systems.
class LinkSystemPage extends StatefulWidget {
  const LinkSystemPage({super.key});

  @override
  State<LinkSystemPage> createState() => _LinkSystemPageState();
}

class _LinkSystemPageState extends State<LinkSystemPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
  );
  Map<String, dynamic>? _scannedData;
  bool _isLoading = false;
  String? _errorMessage;
  bool _scanned = false;

  void _onQrScanned(String rawValue) {
    if (_scanned) return;
    // Stop the camera immediately on any detection to free hardware resources.
    _controller.stop();
    try {
      final data = jsonDecode(rawValue) as Map<String, dynamic>;
      if (!data.containsKey('system_id')) {
        setState(() {
          _errorMessage = 'Invalid QR code: Missing system_id';
          _scanned = true;
        });
        return;
      }
      setState(() {
        _scannedData = data;
        _errorMessage = null;
        _scanned = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid QR code format';
        _scanned = true;
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
    final errorMsg = await context.read<LinkedSystemsCubit>().linkSystem(
          gatewaySystemId: gatewaySystemId,
          systemId: systemId,
        );

    if (mounted) {
      if (errorMsg == null) {
        navigator.pop(true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _scannedData = null;
      _errorMessage = null;
      _isLoading = false;
      _scanned = false;
    });
    // Restart the camera for another scan attempt.
    _controller.start();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // Only restart if we are still in scanning state (no result yet)
        if (_scannedData == null && _errorMessage == null && !_isLoading) {
          _controller.start();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _controller.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = _scannedData == null && _errorMessage == null && !_isLoading;
    return Scaffold(
      extendBodyBehindAppBar: isScanning,
      appBar: isScanning
          ? null
          : AppBar(
              title: const Text('Link External System'),
            ),
      body: SafeArea(
        top: !isScanning,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: SpacingTokens.lg),
            Text('Linking external system...', style: tt.titleMedium),
            const SizedBox(height: SpacingTokens.xs),
            Text('Registering trust binding with gateway server', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: cs.error),
              const SizedBox(height: SpacingTokens.md),
              Text(
                _errorMessage!,
                style: tt.titleMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.xs),
              Text(
                'Please scan a valid client integration QR code.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpacingTokens.lg),
              CustomButton(
                label: 'Try Again',
                icon: Icons.refresh,
                onPressed: _resetScanner,
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
        padding: const EdgeInsets.all(SpacingTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.add_link_outlined, size: 54, color: cs.primary),
            const SizedBox(height: SpacingTokens.md),
            Text(
              'Link Scanned System',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.xs),
            Text(
              'Confirm that this system matches the pairing parameters of your client app.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.lg),
            CustomCard(
              hasGradientBorder: true,
              padding: const EdgeInsets.all(SpacingTokens.md + 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoBlock(
                    label: 'SYSTEM ID',
                    value: systemId,
                    icon: Icons.fingerprint,
                  ),
                  Divider(color: cs.outline, height: SpacingTokens.lg),
                  _capabilitiesBlock(capabilities),
                  Divider(color: cs.outline, height: SpacingTokens.lg),
                  _infoBlock(
                    label: 'ENVIRONMENT',
                    value: isTest ? 'Sandbox / Test' : 'Production',
                    icon: Icons.cloud_queue,
                    colorOverride: isTest ? Colors.orange : ColorTokens.emerald400,
                  ),
                ],
              ),
            ),
            const Spacer(),
            CustomButton(
              label: 'Confirm and Link',
              icon: Icons.check_circle_outline,
              onPressed: _confirmLink,
            ),
            const SizedBox(height: SpacingTokens.sm),
            CustomButton(
              label: 'Cancel / Scan Again',
              variant: CustomButtonVariant.secondary,
              icon: Icons.refresh,
              onPressed: _resetScanner,
            ),
            const SizedBox(height: SpacingTokens.md),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final raw = barcodes.first.rawValue;
            if (raw == null || raw.isEmpty) return;
            _onQrScanned(raw);
          },
        ),
        CustomPaint(
          size: Size.infinite,
          painter: _ViewfinderPainter(),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: Container(
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        const Positioned(
          bottom: 64,
          left: 40,
          right: 40,
          child: Text(
            'Align the client system QR code inside the frame to link',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoBlock({
    required String label,
    required String value,
    required IconData icon,
    Color? colorOverride,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              label,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            color: colorOverride ?? cs.onSurface,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _capabilitiesBlock(List<String> capabilities) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.rule, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: SpacingTokens.xs),
            Text('GRANTED CAPABILITIES',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        capabilities.isEmpty
            ? Text('None', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
            : Wrap(
                spacing: SpacingTokens.xs,
                runSpacing: SpacingTokens.xs,
                children: capabilities.map((c) => _capabilityBadge(c)).toList(),
              ),
      ],
    );
  }

  Widget _capabilityBadge(String cap) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (cap) {
      'otp_gateway' => ('SMS Gateway', ColorTokens.emerald500),
      'two_fa' => ('2FA Push', cs.primary),
      'payment_observation' => ('Payment Watch', cs.secondary),
      _ => (cap, cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RadiusTokens.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;

    final sq = size.width * 0.68;
    final l = (size.width - sq) / 2;
    final t = (size.height - sq) / 2;
    final rect = Rect.fromLTWH(l, t, sq, sq);

    // Dimmed surround with cutout
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(22)))
        ..fillType = PathFillType.evenOdd,
      overlay,
    );

    // Frame border (primary)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      Paint()
        ..color = ColorTokens.debitBlueSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Corner accents (secondary / gold)
    final corner = Paint()
      ..color = ColorTokens.goldAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final len = sq * 0.13;
    for (final (x, y, dx, dy) in [
      (l, t, 1.0, 1.0),
      (l + sq, t, -1.0, 1.0),
      (l, t + sq, 1.0, -1.0),
      (l + sq, t + sq, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * len)
          ..lineTo(x, y)
          ..lineTo(x + dx * len, y),
        corner,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
