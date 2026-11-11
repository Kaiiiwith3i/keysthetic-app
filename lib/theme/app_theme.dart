import 'package:flutter/material.dart';
import 'tokens.dart';

const _accentLight = Color(0xFFFF4D1C); // keycap vermilion
const _accentDark = Color(0xFFFF6A3D);

TextStyle _ts(String family, double size, double w, {double? ls, double? h}) =>
    TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[((w / 100).round() - 1).clamp(0, 8)],
      fontVariations: [FontVariation.weight(w)],
      letterSpacing: ls,
      height: h,
    );

TextTheme _textTheme(Color ink) {
  TextStyle d(double s, double w, {double? ls}) =>
      _ts('Bricolage', s, w, ls: ls, h: 1.1).copyWith(color: ink);
  TextStyle b(double s, double w, {double? h}) =>
      _ts('InstrumentSans', s, w, h: h ?? 1.35).copyWith(color: ink);
  return TextTheme(
    displaySmall: d(34, 800, ls: -.8),
    headlineMedium: d(28, 700, ls: -.5),
    headlineSmall: d(24, 700, ls: -.3),
    titleLarge: d(20, 700, ls: -.2),
    titleMedium: b(16, 650),
    titleSmall: b(14, 650),
    bodyLarge: b(16, 450),
    bodyMedium: b(14, 450),
    bodySmall: b(12, 450),
    labelLarge: b(14, 650),
    labelMedium: b(12, 600),
    labelSmall: b(11, 600),
  );
}

/// Monospace style for prices, counts and keycap legends.
TextStyle monoStyle(double size, Color color, {double w = 600}) =>
    _ts('JetBrainsMono', size, w).copyWith(
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final accent = dark ? _accentDark : _accentLight;
  final bg = dark ? const Color(0xFF16140F) : const Color(0xFFF4F0E7);
  final ink = dark ? const Color(0xFFF2EEE4) : const Color(0xFF1D1A14);
  final scheme = ColorScheme(
    brightness: b,
    primary: accent,
    onPrimary: dark ? const Color(0xFF1A0C05) : Colors.white,
    secondary: dark ? const Color(0xFFD8CFBD) : const Color(0xFF3A342A),
    onSecondary: dark ? const Color(0xFF1D1A14) : Colors.white,
    error: dark ? const Color(0xFFFF7A7A) : const Color(0xFFC53030),
    onError: dark ? const Color(0xFF2A0808) : Colors.white,
    surface: bg,
    onSurface: ink,
    surfaceContainerHighest: dark ? const Color(0xFF2B2823) : const Color(0xFFE9E3D6),
    onSurfaceVariant: dark ? const Color(0xFFB5AD9C) : const Color(0xFF6A6252),
    outline: dark ? const Color(0xFF4A453B) : const Color(0xFFCBC3B1),
    outlineVariant: dark ? const Color(0xFF332F27) : const Color(0xFFE0D9C9),
  );
  final k = dark ? KeysColors.dark : KeysColors.light;
  final tt = _textTheme(ink);
  OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Rad.md),
        borderSide: BorderSide(color: c, width: w),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: tt,
    fontFamily: 'InstrumentSans',
    extensions: [k],
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: tt.titleLarge,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: k.capTop,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(accent, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
      labelStyle: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
      hintStyle: tt.bodyMedium!.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: .7)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: tt.bodyMedium!.copyWith(color: bg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: k.capTop,
      selectedColor: accent.withValues(alpha: .18),
      checkmarkColor: accent,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: tt.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
