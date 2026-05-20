import 'package:flutter/material.dart';
import 'package:super_admin_agent/presentation/shared/theme/color_tokens.dart';

enum ConnectionStatus { connected, connecting, disconnected }

/// Pulsing dot indicator that reflects agent connection state.
///
/// Uses [ColorTokens] directly since this widget is also rendered in
/// contexts where a [BuildContext] with a full theme might not be optimal.
class StatusDot extends StatefulWidget {
  final ConnectionStatus status;
  final double size;

  const StatusDot({
    super.key,
    required this.status,
    this.size = 10.0,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.status) {
      case ConnectionStatus.connected:
        return ColorTokens.emerald500;
      case ConnectionStatus.connecting:
        return ColorTokens.warningAmber;
      case ConnectionStatus.disconnected:
        return ColorTokens.errorSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color,
          boxShadow: [
            BoxShadow(
              color: _color.withValues(alpha: _glow.value * 0.7),
              blurRadius: widget.size * 0.9,
              spreadRadius: widget.size * 0.25 * _glow.value,
            ),
          ],
        ),
      ),
    );
  }
}
