import 'package:flutter/material.dart';

import '../../shared/theme/color_tokens.dart';

/// Deterministic avatar background from a display name or address.
Color avatarColorForKey(String key) {
  const palette = [
    ColorTokens.debitBlue,
    ColorTokens.emerald500,
    ColorTokens.warningAmber,
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];
  var hash = 0;
  for (final code in key.codeUnits) {
    hash = (hash + code) % 10007;
  }
  return palette[hash % palette.length];
}
