import 'package:flutter/material.dart';
import 'package:super_admin_agent/presentation/shared/theme/qayd_theme_extensions.dart';
import 'package:super_admin_agent/presentation/shared/theme/radius_tokens.dart';

/// Reusable elevated surface card that consumes the app's design-system tokens.
///
/// [hasGradientBorder] wraps the card with a 1.5 dp emerald→navy gradient stroke.
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final bool hasGradientBorder;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.hasGradientBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final custom = Theme.of(context).extension<QaydCustomColors>()!;
    final radius = borderRadius ?? RadiusTokens.lg.toDouble();
    final bgColor = backgroundColor ?? custom.surfaceElevated;
    final effectivePadding = padding ?? const EdgeInsets.all(20);

    final content = Padding(padding: effectivePadding, child: child);

    if (hasGradientBorder) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(radius - 1.5),
          ),
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: custom.subtleBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}
