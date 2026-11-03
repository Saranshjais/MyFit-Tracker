import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Builds the Material 3 theme from an [AppPalette].
///
/// Type scale follows the design brief: screen titles 24–28, section titles
/// 17–20, card titles 14–16, body 13–15, secondary labels 11–13.
ThemeData buildTheme(AppPalette p, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.error,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerHighest: p.elevated,
    surfaceContainerHigh: p.elevated,
    surfaceContainer: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainerLowest: p.background,
    outline: p.border,
    outlineVariant: p.border,
  );

  final text = TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: p.text, height: 1.15),
    headlineSmall: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: p.text, height: 1.2),
    titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.text),
    titleMedium: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.text),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text),
    bodyLarge: TextStyle(fontSize: 15, color: p.text),
    bodyMedium: TextStyle(fontSize: 14, color: p.text),
    bodySmall: TextStyle(fontSize: 12.5, color: p.textSecondary),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text),
    labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.textSecondary),
    labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.textSecondary, letterSpacing: 0.8),
  );

  final radius = BorderRadius.circular(12);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: p.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    textTheme: text,
    extensions: [p],
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: p.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? p.accentText : p.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(size: 24, color: states.contains(WidgetState.selected) ? p.accentText : p.textMuted),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.elevated,
        disabledForegroundColor: p.textMuted,
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: p.border),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accentText,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.text)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.backgroundAlt,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
      labelStyle: TextStyle(color: p.textSecondary, fontSize: 14),
      floatingLabelStyle: TextStyle(color: p.accentText, fontSize: 14),
      helperStyle: TextStyle(color: p.textMuted, fontSize: 12),
      errorStyle: TextStyle(color: p.error, fontSize: 12),
      prefixIconColor: p.textMuted,
      suffixIconColor: p.textMuted,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.accent, width: 1.5)),
      errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.error)),
      focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.error, width: 1.5)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.accent,
      disabledColor: p.elevated,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text),
      secondaryLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.onAccent),
      checkmarkColor: p.onAccent,
      side: BorderSide(color: p.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.text),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.elevated),
      trackOutlineColor: WidgetStatePropertyAll(p.border),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.onAccent),
      side: BorderSide(color: p.textMuted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.textMuted),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.elevated,
      circularTrackColor: p.elevated,
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.accent, thumbColor: p.accent, inactiveTrackColor: p.elevated),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text),
      contentTextStyle: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.border,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.elevated,
      contentTextStyle: TextStyle(color: p.text, fontSize: 14),
      actionTextColor: p.accentText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.elevated,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: p.text, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
      subtitleTextStyle: TextStyle(fontSize: 12.5, color: p.textSecondary),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.accentText,
      unselectedLabelColor: p.textSecondary,
      indicatorColor: p.accent,
      dividerColor: p.border,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: p.surface),
    datePickerTheme: DatePickerThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
  );
}
