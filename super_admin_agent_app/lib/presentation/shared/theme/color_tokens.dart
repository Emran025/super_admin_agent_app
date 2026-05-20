import 'package:flutter/material.dart';

/// Raw palette anchors (navy, emerald, refined grays). Prefer [AppTheme] ColorScheme in UI.
abstract final class ColorTokens {
  // Navy family
  static const Color navy950 = Color(0xFF0A1628);
  static const Color navy900 = Color(0xFF0F2741);
  static const Color navy800 = Color(0xFF163056);
  static const Color navy700 = Color(0xFF1E3D6B);

  // Emerald accent
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald400 = Color(0xFF34D399);

  // Neutrals (light)
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate800 = Color(0xFF1E293B);

  // Neutrals (dark surfaces)
  static const Color graphite950 = Color(0xFF0B0F14);
  static const Color graphite900 = Color(0xFF121A22);
  static const Color graphite850 = Color(0xFF171F29);
  static const Color graphite800 = Color(0xFF1C2632);
  static const Color graphite700 = Color(0xFF2A3544);

  // Semantic accents
  static const Color goldAccent = Color(0xFFC9A227);
  static const Color errorDeep = Color(0xFFB91C1C);
  static const Color errorSoft = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color debitBlue = Color(0xFF2563EB);
  static const Color debitBlueSoft = Color(0xFF60A5FA);
  static const Color creditGreen = Color(0xFF15803D);
  static const Color creditGreenSoft = Color(0xFF4ADE80);
}
