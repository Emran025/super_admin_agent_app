import 'package:flutter/material.dart';
import 'package:super_admin_agent/presentation/shared/theme/color_tokens.dart';

/// Semantic colors not covered by [ColorScheme] (debit/credit, voucher states).
@immutable
final class QaydCustomColors extends ThemeExtension<QaydCustomColors> {
  const QaydCustomColors({
    required this.debit,
    required this.credit,
    required this.draftState,
    required this.confirmedState,
    required this.settledState,
    required this.badgeOnDraft,
    required this.badgeOnConfirmed,
    required this.badgeOnSettled,
    required this.subtleBorder,
    required this.surfaceElevated,
    required this.goldAccent,
  });

  final Color debit;
  final Color credit;
  final Color draftState;
  final Color confirmedState;
  final Color settledState;
  final Color badgeOnDraft;
  final Color badgeOnConfirmed;
  final Color badgeOnSettled;
  final Color subtleBorder;
  final Color surfaceElevated;
  final Color goldAccent;

  static const QaydCustomColors light = QaydCustomColors(
    debit: ColorTokens.debitBlue,
    credit: ColorTokens.creditGreen,
    draftState: ColorTokens.warningAmber,
    confirmedState: ColorTokens.emerald700,
    settledState: ColorTokens.creditGreen,
    badgeOnDraft: Color(0xFFFFFFFF),
    badgeOnConfirmed: Color(0xFFFFFFFF),
    badgeOnSettled: Color(0xFFFFFFFF),
    subtleBorder: ColorTokens.slate200,
    surfaceElevated: ColorTokens.slate50,
    goldAccent: ColorTokens.goldAccent,
  );

  static const QaydCustomColors dark = QaydCustomColors(
    debit: ColorTokens.debitBlueSoft,
    credit: ColorTokens.creditGreenSoft,
    draftState: Color(0xFFFBBF24),
    confirmedState: ColorTokens.emerald400,
    settledState: ColorTokens.emerald500,
    badgeOnDraft: ColorTokens.graphite950,
    badgeOnConfirmed: ColorTokens.navy950,
    badgeOnSettled: ColorTokens.graphite950,
    subtleBorder: ColorTokens.graphite700,
    surfaceElevated: ColorTokens.graphite850,
    goldAccent: Color(0xFFE8C547),
  );

  @override
  QaydCustomColors copyWith({
    Color? debit,
    Color? credit,
    Color? draftState,
    Color? confirmedState,
    Color? settledState,
    Color? badgeOnDraft,
    Color? badgeOnConfirmed,
    Color? badgeOnSettled,
    Color? subtleBorder,
    Color? surfaceElevated,
    Color? goldAccent,
  }) {
    return QaydCustomColors(
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      draftState: draftState ?? this.draftState,
      confirmedState: confirmedState ?? this.confirmedState,
      settledState: settledState ?? this.settledState,
      badgeOnDraft: badgeOnDraft ?? this.badgeOnDraft,
      badgeOnConfirmed: badgeOnConfirmed ?? this.badgeOnConfirmed,
      badgeOnSettled: badgeOnSettled ?? this.badgeOnSettled,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      goldAccent: goldAccent ?? this.goldAccent,
    );
  }

  @override
  QaydCustomColors lerp(ThemeExtension<QaydCustomColors>? other, double t) {
    if (other is! QaydCustomColors) return this;
    return QaydCustomColors(
      debit: Color.lerp(debit, other.debit, t)!,
      credit: Color.lerp(credit, other.credit, t)!,
      draftState: Color.lerp(draftState, other.draftState, t)!,
      confirmedState: Color.lerp(confirmedState, other.confirmedState, t)!,
      settledState: Color.lerp(settledState, other.settledState, t)!,
      badgeOnDraft: Color.lerp(badgeOnDraft, other.badgeOnDraft, t)!,
      badgeOnConfirmed:
          Color.lerp(badgeOnConfirmed, other.badgeOnConfirmed, t)!,
      badgeOnSettled: Color.lerp(badgeOnSettled, other.badgeOnSettled, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      goldAccent: Color.lerp(goldAccent, other.goldAccent, t)!,
    );
  }
}
