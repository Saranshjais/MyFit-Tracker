import 'package:flutter/material.dart';

/// Semantic colours for the app. Widgets read these through
/// `context.palette` instead of hard-coding hex values, so the dark and light
/// themes stay consistent.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.elevated,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.accentSoft,
    required this.warning,
    required this.error,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.water,
  });

  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color elevated;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textMuted;

  /// Fill colour for primary actions and progress.
  final Color accent;

  /// Accent used for text and icons on [background] or [surface].
  final Color accentText;

  /// Text and icons drawn on top of [accent].
  final Color onAccent;

  /// Low-emphasis accent background (selected chips, completed states).
  final Color accentSoft;
  final Color warning;
  final Color error;
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color water;

  static const dark = AppPalette(
    background: Color(0xFF0E1113),
    backgroundAlt: Color(0xFF151A1D),
    surface: Color(0xFF1A2024),
    elevated: Color(0xFF20272B),
    border: Color(0xFF2A3236),
    text: Color(0xFFF5F7F6),
    textSecondary: Color(0xFFA0AAA7),
    textMuted: Color(0xFF727D79),
    accent: Color(0xFF24E88A),
    accentText: Color(0xFF24E88A),
    onAccent: Color(0xFF04140C),
    accentSoft: Color(0xFF153B2C),
    warning: Color(0xFFF4C95D),
    error: Color(0xFFFF6268),
    protein: Color(0xFF24E88A),
    carbs: Color(0xFFA5C96D),
    fat: Color(0xFFF2CF65),
    water: Color(0xFF5DB8FF),
  );

  static const light = AppPalette(
    background: Color(0xFFF5F6F2),
    backgroundAlt: Color(0xFFECEEE9),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFF0F2EE),
    border: Color(0xFFDDE2DD),
    text: Color(0xFF131816),
    textSecondary: Color(0xFF56605C),
    textMuted: Color(0xFF7D8783),
    accent: Color(0xFF1FC979),
    accentText: Color(0xFF0B8A4F),
    onAccent: Color(0xFF04140C),
    accentSoft: Color(0xFFDDF5E8),
    warning: Color(0xFFB7860B),
    error: Color(0xFFD93A40),
    protein: Color(0xFF17B26A),
    carbs: Color(0xFF7FA346),
    fat: Color(0xFFD9A92B),
    water: Color(0xFF2F8FE0),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
