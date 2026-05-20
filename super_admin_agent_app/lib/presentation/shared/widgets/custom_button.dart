import 'package:flutter/material.dart';
import 'package:super_admin_agent/presentation/shared/theme/color_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/radius_tokens.dart';

enum CustomButtonVariant { primary, secondary, danger }

/// Premium animated button backed by the design-system token palette.
///
/// - [primary]   → emerald gradient fill (scheme.primary → scheme.secondary)
/// - [secondary] → transparent outlined (subtleBorder stroke)
/// - [danger]    → deep-red gradient fill
class CustomButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CustomButtonVariant variant;
  final bool isLoading;
  final double height;
  final double? borderRadius;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = CustomButtonVariant.primary,
    this.isLoading = false,
    this.height = 52.0,
    this.borderRadius,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.96,
      upperBound: 1.0,
    )..value = 1.0;
    _scale = _controller.drive(CurveTween(curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _interactive =>
      widget.onPressed != null && !widget.isLoading;

  void _onTapDown(TapDownDetails _) {
    if (_interactive) _controller.reverse();
  }

  void _onTapUp(TapUpDetails _) {
    if (_interactive) _controller.forward();
  }

  void _onTapCancel() {
    if (_interactive) _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = widget.borderRadius ?? RadiusTokens.md.toDouble();
    final isDisabled = !_interactive;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: widget.height,
          decoration: _decoration(cs, radius, isDisabled),
          child: Center(child: _content(cs, isDisabled)),
        ),
      ),
    );
  }

  Widget _content(ColorScheme cs, bool isDisabled) {
    if (widget.isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor:
              AlwaysStoppedAnimation<Color>(isDisabled ? cs.onSurface : Colors.white),
        ),
      );
    }
    final textColor = isDisabled ? cs.onSurfaceVariant : Colors.white;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: textColor, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  BoxDecoration _decoration(ColorScheme cs, double radius, bool isDisabled) {
    if (isDisabled) {
      return BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      );
    }

    switch (widget.variant) {
      case CustomButtonVariant.primary:
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case CustomButtonVariant.danger:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [ColorTokens.errorDeep, ColorTokens.errorSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: ColorTokens.errorSoft.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case CustomButtonVariant.secondary:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: cs.outline, width: 1.5),
        );
    }
  }
}
