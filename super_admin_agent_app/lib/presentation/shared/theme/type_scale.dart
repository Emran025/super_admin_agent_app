import 'package:flutter/material.dart';

/// Cairo-based type ramp aligned with `theming_and_design_system.md` §2.2.
abstract final class TypeScale {
  static TextTheme buildTextTheme(ColorScheme scheme) {
    TextStyle cairo({
      required double size,
      required FontWeight weight,
      double height = 1.35,
    }) {
      return TextStyle(
        fontFamily: 'Cairo',
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: scheme.onSurface,
      );
    }

    return TextTheme(
      displayLarge: cairo(size: 28, weight: FontWeight.w700),
      displayMedium: cairo(size: 24, weight: FontWeight.w600),
      displaySmall: cairo(size: 22, weight: FontWeight.w600),
      headlineLarge: cairo(size: 22, weight: FontWeight.w600),
      headlineMedium: cairo(size: 20, weight: FontWeight.w600),
      headlineSmall: cairo(size: 18, weight: FontWeight.w500),
      titleLarge: cairo(size: 20, weight: FontWeight.w600),
      titleMedium: cairo(size: 18, weight: FontWeight.w500),
      titleSmall: cairo(size: 16, weight: FontWeight.w500),
      bodyLarge: cairo(size: 16, weight: FontWeight.w400),
      bodyMedium: cairo(size: 14, weight: FontWeight.w400),
      bodySmall: cairo(size: 12, weight: FontWeight.w400),
      labelLarge: cairo(size: 14, weight: FontWeight.w600),
      labelMedium: cairo(size: 12, weight: FontWeight.w500),
      labelSmall: cairo(size: 11, weight: FontWeight.w500),
    );
  }

  static TextStyle moneyLarge(ColorScheme scheme) => const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ).copyWith(color: scheme.onSurface);

  static TextStyle moneyMedium(ColorScheme scheme) => const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ).copyWith(color: scheme.onSurface);

  static TextStyle moneySmall(ColorScheme scheme) => const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.25,
      ).copyWith(color: scheme.onSurface);
}

