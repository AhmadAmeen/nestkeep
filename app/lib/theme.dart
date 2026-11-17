import 'package:flutter/material.dart';

/// NestKeep design tokens — approved mockup v5 (HouseWell-grid language).
/// Light: white cards on #F7F8FA, navy #0A1E46. Dark: cards #141F36 on
/// #0A1120. The primary colour is an accent the user picks (blue, orange
/// or pink, mockup v6); light and dark stay exactly as approved, the
/// accent simply wears over both.
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

  // Shared accents (semantic: never recoloured by the app accent)
  static const green = Color(0xFF1FA97A);
  static const greenRing = Color(0xFF22C08A);
  static const amber = Color(0xFFF5A623);
  static const red = Color(0xFFE5484D);
  static const orange = Color(0xFFEF7D1A);
  static const lifeGreen = Color(0xFF12B76A);
}

/// The user-pickable app colour. Blue is the original NestKeep primary;
/// orange and pink were approved in mockup v6. Each accent has a light
/// and a dark variant so it sits properly on both themes.
enum AppAccent { blue, orange, pink }

extension AppAccentValues on AppAccent {
  Color get lightPrimary => switch (this) {
        AppAccent.blue => const Color(0xFF2456D6),
        AppAccent.orange => const Color(0xFFF97316),
        AppAccent.pink => const Color(0xFFEC4899),
      };

  Color get darkPrimary => switch (this) {
        AppAccent.blue => const Color(0xFF4C7DFF),
        AppAccent.orange => const Color(0xFFFF9E57),
        AppAccent.pink => const Color(0xFFF77FB8),
      };

  Color primaryFor(bool dark) => dark ? darkPrimary : lightPrimary;

  String get label => switch (this) {
        AppAccent.blue => 'Blue',
        AppAccent.orange => 'Orange',
        AppAccent.pink => 'Pink',
      };
}

/// Carries the exact accent primary inside ThemeData so any widget can
/// resolve it via `context.primary` without knowing the user's pick.
class NkAccentColors extends ThemeExtension<NkAccentColors> {
  final Color primary;

  const NkAccentColors({required this.primary});

  @override
  NkAccentColors copyWith({Color? primary}) =>
      NkAccentColors(primary: primary ?? this.primary);

  @override
  NkAccentColors lerp(NkAccentColors? other, double t) =>
      other == null ? this : NkAccentColors(primary: Color.lerp(primary, other.primary, t)!);
}

ThemeData nkLightTheme([AppAccent accent = AppAccent.blue]) {
  final primary = accent.lightPrimary;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: NkColors.lightCard,
    ),
    scaffoldBackgroundColor: NkColors.lightBg,
    fontFamily: 'Roboto',
    extensions: [NkAccentColors(primary: primary)],
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
      indicatorColor: primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: NkColors.lightText),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData nkDarkTheme([AppAccent accent = AppAccent.blue]) {
  final primary = accent.darkPrimary;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: NkColors.darkCard,
    ),
    scaffoldBackgroundColor: NkColors.darkBg,
    fontFamily: 'Roboto',
    extensions: [NkAccentColors(primary: primary)],
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
      indicatorColor: primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: NkColors.darkText),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
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

  /// The selected app accent's primary colour for this brightness.
  /// Falls back to the original blue if a theme was built without the
  /// extension (tests, previews).
  Color get primary =>
      Theme.of(this).extension<NkAccentColors>()?.primary ??
      (isDark ? NkColors.darkPrimary : NkColors.lightPrimary);
}
