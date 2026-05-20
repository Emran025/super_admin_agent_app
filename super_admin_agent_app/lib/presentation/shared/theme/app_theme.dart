import 'package:flutter/material.dart';
import 'package:super_admin_agent/presentation/shared/theme/color_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/qayd_theme_extensions.dart';
import 'package:super_admin_agent/presentation/shared/theme/radius_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/spacing_tokens.dart';
import 'package:super_admin_agent/presentation/shared/theme/type_scale.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: ColorTokens.navy900,
      onPrimary: Colors.white,
      primaryContainer: ColorTokens.navy800,
      onPrimaryContainer: ColorTokens.slate50,
      secondary: ColorTokens.emerald600,
      onSecondary: Colors.white,
      secondaryContainer: ColorTokens.emerald500.withValues(alpha: 0.22),
      onSecondaryContainer: ColorTokens.navy900,
      tertiary: ColorTokens.goldAccent,
      onTertiary: ColorTokens.navy950,
      error: ColorTokens.errorDeep,
      onError: Colors.white,
      surface: ColorTokens.slate50,
      onSurface: ColorTokens.slate800,
      onSurfaceVariant: ColorTokens.slate600,
      outline: ColorTokens.slate200,
      outlineVariant: ColorTokens.slate200.withValues(alpha: 0.6),
      shadow: ColorTokens.navy950.withValues(alpha: 0.12),
      scrim: ColorTokens.navy950.withValues(alpha: 0.45),
      inverseSurface: ColorTokens.navy900,
      onInverseSurface: ColorTokens.slate50,
      inversePrimary: ColorTokens.emerald400,
      surfaceContainerHighest: ColorTokens.slate100,
      surfaceContainerHigh: ColorTokens.slate50,
      surfaceContainer: ColorTokens.slate100.withValues(alpha: 0.85),
      surfaceContainerLow: ColorTokens.slate50,
      surfaceContainerLowest: Colors.white,
      surfaceDim: ColorTokens.slate200,
      surfaceBright: Colors.white,
    );

    return _buildTheme(scheme, QaydCustomColors.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ColorTokens.emerald500,
      onPrimary: ColorTokens.navy950,
      primaryContainer: ColorTokens.navy800,
      onPrimaryContainer: ColorTokens.slate100,
      secondary: ColorTokens.emerald400,
      onSecondary: ColorTokens.navy950,
      secondaryContainer: ColorTokens.emerald600.withValues(alpha: 0.35),
      onSecondaryContainer: ColorTokens.slate50,
      tertiary: ColorTokens.goldAccent,
      onTertiary: ColorTokens.navy950,
      error: ColorTokens.errorSoft,
      onError: ColorTokens.navy950,
      surface: ColorTokens.graphite900,
      onSurface: ColorTokens.slate100,
      onSurfaceVariant: ColorTokens.slate400,
      outline: ColorTokens.graphite700,
      outlineVariant: ColorTokens.graphite800,
      shadow: Colors.black.withValues(alpha: 0.45),
      scrim: Colors.black.withValues(alpha: 0.6),
      inverseSurface: ColorTokens.slate100,
      onInverseSurface: ColorTokens.navy900,
      inversePrimary: ColorTokens.navy800,
      surfaceContainerHighest: ColorTokens.graphite800,
      surfaceContainerHigh: ColorTokens.graphite850,
      surfaceContainer: ColorTokens.graphite800.withValues(alpha: 0.9),
      surfaceContainerLow: ColorTokens.graphite900,
      surfaceContainerLowest: ColorTokens.graphite950,
      surfaceDim: ColorTokens.graphite950,
      surfaceBright: ColorTokens.graphite700,
    );

    return _buildTheme(scheme, QaydCustomColors.dark);
  }

  static ThemeData _buildTheme(ColorScheme scheme, QaydCustomColors custom) {
    final textTheme = TypeScale.buildTextTheme(scheme);
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Cairo',
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: custom.subtleBorder,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      borderSide: BorderSide(color: custom.subtleBorder, width: 1),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[custom],
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (BuildContext context) => const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
        ),
      ),
      appBarTheme: AppBarTheme(
        iconTheme: IconThemeData(color: scheme.onSurface),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.all(SpacingTokens.sm),
        color: custom.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          side: BorderSide(color: custom.subtleBorder.withValues(alpha: 0.65)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.sm + 2,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.lg,
            vertical: SpacingTokens.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.lg,
            vertical: SpacingTokens.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.md),
          ),
          side: BorderSide(color: custom.subtleBorder),
          foregroundColor: scheme.onSurface,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
        ),
        backgroundColor: scheme.surface,
        elevation: 12,
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.sm,
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16.0, // Reduced from 24.0 for more width
          vertical: 24.0,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: ColorTokens.goldAccent,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
    );
  }
}
