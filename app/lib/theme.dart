import 'package:flutter/material.dart';

/// NestKeep design tokens — approved mockup v5 (HouseWell-grid language).
/// Light: white cards on #F7F8FA, primary royal blue #2456D6, navy #0A1E46.
/// Dark: cards #141F36 on #0A1120, primary #4C7DFF.
/// Amber is an accent only: grade chip, streak, tip card edge, typical marker.
class NkColors {
  // Light
  static const lightBg = Color(0xFFF7F8FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF2456D6);
  static const lightNavy = Color(0xFF0A1E46);
  static const lightText = Color(0xFF16233B);
  static const lightMuted = Color(0xFF5A6B8A);
  static const lightLine = Color(0xFFE4E9F2);

  // Dark
  static const darkBg = Color(0xFF0A1120);
  static const darkCard = Color(0xFF141F36);
  static const darkPrimary = Color(0xFF4C7DFF);
  static const darkText = Color(0xFFEAF0FF);
  static const darkMuted = Color(0xFF93A5C9);
  static const darkLine = Color(0xFF22314F);

  // Shared accents
  static const green = Color(0xFF1FA97A);
  static const greenRing = Color(0xFF22C08A);
  static const amber = Color(0xFFF5A623);
  static const red = Color(0xFFE5484D);
  static const orange = Color(0xFFEF7D1A);
}

ThemeData nkLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: NkColors.lightPrimary,
      brightness: Brightness.light,
      surface: NkColors.lightCard,
    ),
    scaffoldBackgroundColor: NkColors.lightBg,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: NkColors.lightText,
      displayColor: NkColors.lightNavy,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NkColors.lightBg,
      foregroundColor: NkColors.lightNavy,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: NkColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: NkColors.lightLine),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NkColors.lightCard,
      indicatorColor: NkColors.lightPrimary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: NkColors.lightText),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NkColors.lightPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData nkDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: NkColors.darkPrimary,
      brightness: Brightness.dark,
      surface: NkColors.darkCard,
    ),
    scaffoldBackgroundColor: NkColors.darkBg,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: NkColors.darkText,
      displayColor: NkColors.darkText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NkColors.darkBg,
      foregroundColor: NkColors.darkText,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: NkColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: NkColors.darkLine),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NkColors.darkCard,
      indicatorColor: NkColors.darkPrimary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: NkColors.darkText),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NkColors.darkPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Small helpers shared by screens.
extension NkContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get muted => isDark ? NkColors.darkMuted : NkColors.lightMuted;
  Color get line => isDark ? NkColors.darkLine : NkColors.lightLine;
  Color get navyText => isDark ? NkColors.darkText : NkColors.lightNavy;
}
