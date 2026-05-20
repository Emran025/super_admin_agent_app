import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:super_admin_agent/domain/pairing/entities/pairing_token.dart';
import 'package:super_admin_agent/presentation/shared/theme/color_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/radius_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/spacing_tokens.dart';
import 'package:super_admin_agent/presentation/shared/widgets/custom_button.dart';
import 'package:super_admin_agent/presentation/shared/widgets/custom_card.dart';
import '../cubit/pairing_cubit.dart';
import '../cubit/pairing_state.dart';

/// Pairing ceremony UI page.
///
/// State machine:
/// - [PairingIdle]         → premium onboarding screen
/// - [PairingScanning]     → full-screen QR scanner with viewfinder overlay
/// - [PairingTokenScanned] → system detail confirmation card
/// - [PairingInProgress]   → loading indicator
/// - [PairingSuccess]      → navigate to /dashboard
/// - [PairingError]        → SnackBar + return to Idle
class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PairingCubit, PairingState>(
      listener: (context, state) {
        if (state is PairingSuccess) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        } else if (state is PairingError) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cs.error,
              behavior: SnackBarBehavior.floating,
              content: Text(
                state.message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isScanning = state is PairingScanning;
        return Scaffold(
          extendBodyBehindAppBar: isScanning,
          appBar: isScanning
              ? null
              : AppBar(title: const Text('Gateway Pairing')),
          body: SafeArea(
            top: !isScanning,
            child: _buildBody(context, state),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // State renderers
  // ---------------------------------------------------------------------------

  Widget _buildBody(BuildContext context, PairingState state) {
    if (state is PairingScanning) {
      return _ScannerView(
      onDetect: (raw) => context.read<PairingCubit>().onQrScanned(raw),
      onBack: () => context.read<PairingCubit>().cancelScanning(),
    );
    }

    if (state is PairingTokenScanned) return _ConfirmationView(token: state.token);

    if (state is PairingInProgress) return _ProgressView();

    return _IdleView();
  }
}

// ---------------------------------------------------------------------------
// Idle — onboarding
// ---------------------------------------------------------------------------

class _IdleView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.lg, vertical: SpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Shield icon with concentric glow rings
          Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.07),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.18), width: 2),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.11),
                ),
                child: Icon(Icons.shield_outlined, size: 72, color: cs.primary),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.xl),
          Text('Secure Agent Pairing',
              style: tt.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Link this device to the primary gateway. Once paired, the agent acts as an encrypted relay for security flows.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant, height: 1.6),
          ),
          const SizedBox(height: SpacingTokens.lg),
          CustomCard(
            padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.md, vertical: SpacingTokens.sm + 4),
            child: Column(
              children: [
                const _FeatureRow(
                  icon: Icons.vpn_key_outlined,
                  title: 'Zero-Trust Protocol',
                  subtitle: 'Hardware-backed ECDSA key validation.',
                ),
                Divider(color: cs.outline, height: SpacingTokens.md),
                const _FeatureRow(
                  icon: Icons.sms_outlined,
                  title: 'Encrypted SMS Relay',
                  subtitle: 'Automatic OTP routing through the agent.',
                ),
                Divider(color: cs.outline, height: SpacingTokens.md),
                const _FeatureRow(
                  icon: Icons.lock_person_outlined,
                  title: '2FA Push Approvals',
                  subtitle: 'Approve dashboard sign-in actions instantly.',
                ),
              ],
            ),
          ),
          const Spacer(),
          CustomButton(
            label: 'Pair with System',
            icon: Icons.qr_code_scanner,
            onPressed: () => context.read<PairingCubit>().startScanning(),
          ),
          const SizedBox(height: SpacingTokens.md),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.secondary, size: 22),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation view
// ---------------------------------------------------------------------------

class _ConfirmationView extends StatelessWidget {
  final PairingToken token;
  const _ConfirmationView({required this.token});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.domain_verification_outlined, size: 54, color: cs.primary),
          const SizedBox(height: SpacingTokens.md),
          Text('Verify System Connection',
              style: tt.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Confirm these parameters match your administration portal.',
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
                _InfoBlock(
                  label: 'SYSTEM NAME',
                  value: token.systemLabel,
                  icon: Icons.computer,
                ),
                Divider(color: cs.outline, height: SpacingTokens.lg),
                _InfoBlock(
                  label: 'ENDPOINT URL',
                  value: token.pairingEndpoint,
                  icon: Icons.link,
                  isUrl: true,
                ),
                Divider(color: cs.outline, height: SpacingTokens.lg),
                _CapabilitiesBlock(
                    capabilities: token.capabilities),
              ],
            ),
          ),
          const Spacer(),
          CustomButton(
            label: 'Confirm and Pair',
            icon: Icons.check_circle_outline,
            onPressed: () => context.read<PairingCubit>().confirmPairing(),
          ),
          const SizedBox(height: SpacingTokens.sm),
          CustomButton(
            label: 'Scan Again',
            variant: CustomButtonVariant.secondary,
            icon: Icons.refresh,
            onPressed: () => context.read<PairingCubit>().startScanning(),
          ),
          const SizedBox(height: SpacingTokens.md),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isUrl;
  const _InfoBlock(
      {required this.label,
      required this.value,
      required this.icon,
      this.isUrl = false});

  @override
  Widget build(BuildContext context) {
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
              style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            color: isUrl ? cs.secondary : cs.onSurface,
            fontWeight: FontWeight.w600,
            fontFamily: isUrl ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}

class _CapabilitiesBlock extends StatelessWidget {
  final List<String> capabilities;
  const _CapabilitiesBlock({required this.capabilities});

  @override
  Widget build(BuildContext context) {
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
                style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        capabilities.isEmpty
            ? Text('None',
                style:
                    tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
            : Wrap(
                spacing: SpacingTokens.xs,
                runSpacing: SpacingTokens.xs,
                children: capabilities
                    .map((c) => _CapabilityBadge(cap: c))
                    .toList(),
              ),
      ],
    );
  }
}

class _CapabilityBadge extends StatelessWidget {
  final String cap;
  const _CapabilityBadge({required this.cap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (cap) {
      'otp_gateway' => ('SMS Gateway', ColorTokens.emerald500),
      'two_fa' => ('2FA Push', cs.primary),
      'payment_observation' => ('Payment Watch', cs.secondary),
      _ => (cap, cs.onSurfaceVariant),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(RadiusTokens.sm.toDouble()),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress view
// ---------------------------------------------------------------------------

class _ProgressView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
          Text('Establishing secure connection…', style: tt.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text('Generating keypair and registering with server',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scanner view
// ---------------------------------------------------------------------------

class _ScannerView extends StatefulWidget {
  final void Function(String rawValue) onDetect;
  final VoidCallback onBack;
  const _ScannerView({required this.onDetect, required this.onBack});

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            if (_scanned) return;
            final raw = capture.barcodes.firstOrNull?.rawValue;
            if (raw == null || raw.isEmpty) return;
            setState(() => _scanned = true);
            widget.onDetect(raw);
          },
        ),
        // Dimmed overlay + viewfinder frame
        CustomPaint(
          size: Size.infinite,
          painter: _ViewfinderPainter(),
        ),
        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
          ),
        ),
        // Instruction label
        const Positioned(
          bottom: 64,
          left: 40,
          right: 40,
          child: Text(
            'Align the server QR code inside the frame to pair',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                    color: Colors.black87,
                    blurRadius: 4,
                    offset: Offset(0, 1))
              ],
            ),
          ),
        ),
      ],
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
        ..addRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(22)))
        ..fillType = PathFillType.evenOdd,
      overlay,
    );

    // Frame border (primary)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      Paint()
        ..color = ColorTokens.emerald500
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
