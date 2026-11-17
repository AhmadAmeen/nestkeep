import 'package:flutter/material.dart';

/// NestKeep design tokens — approved mockup v5 (HouseWell-grid language).
/// Light: white cards on #F7F8FA, navy #0A1E46. Dark: cards #141F36 on
/// #0A1120. The primary colour is an accent the user picks from one close
/// purple family (indigo, purple or plum; purple is the default, build
/// 11); light and dark stay exactly as approved, the accent simply wears
/// over both.
/// Amber is an accent only: grade chip, streak, tip card edge, typical marker.
class NkColors {
  // Light
  static const lightBg = Color(0xFFF7F8FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightPrimary = Color(0xFF6D4DF6);
  static const lightNavy = Color(0xFF0A1E46);
  static const lightText = Color(0xFF16233B);
  static const lightMuted = Color(0xFF5A6B8A);
  static const lightLine = Color(0xFFE4E9F2);

  // Dark
  static const darkBg = Color(0xFF0A1120);
  static const darkCard = Color(0xFF141F36);
  static const darkPrimary = Color(0xFFA48FFF);
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

/// The user-pickable app colour: one close purple family (build 11
/// replaced the mockup v6 blue/orange/pink set, which clashed with each
/// other). Purple is the default. Each accent has a light and a dark
/// variant so it sits properly on both themes.
enum AppAccent { indigo, purple, plum }

extension AppAccentValues on AppAccent {
  Color get lightPrimary => switch (this) {
        AppAccent.indigo => const Color(0xFF5457E8),
        AppAccent.purple => const Color(0xFF6D4DF6),
        AppAccent.plum => const Color(0xFFB44FD8),
      };

  Color get darkPrimary => switch (this) {
        AppAccent.indigo => const Color(0xFF9AA0FF),
        AppAccent.purple => const Color(0xFFA48FFF),
        AppAccent.plum => const Color(0xFFD98CFF),
      };

  Color primaryFor(bool dark) => dark ? darkPrimary : lightPrimary;

  String get label => switch (this) {
        AppAccent.indigo => 'Indigo',
        AppAccent.purple => 'Purple',
        AppAccent.plum => 'Plum',
      };
}

/// Parse a stored accent preference, tolerantly. The current names map
/// to themselves; the retired mockup v6 names land on their nearest
/// purple-family neighbour (blue -> purple, orange -> plum, pink ->
/// plum); anything unknown or missing falls back to the purple default.
AppAccent parseAppAccent(String? raw) => switch (raw) {
      'indigo' => AppAccent.indigo,
      'purple' => AppAccent.purple,
      'plum' => AppAccent.plum,
      'blue' => AppAccent.purple,
      'orange' => AppAccent.plum,
      'pink' => AppAccent.plum,
      _ => AppAccent.purple,
    };

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

ThemeData nkLightTheme([AppAccent accent = AppAccent.purple]) {
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
    inputDecorationTheme: _inputDecoration(
      primary: primary,
      fill: NkColors.lightCard,
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

/// The modern form look, shared by every text field in the app: rounded
/// corners (radius 16), filled with the card colour, a hairline border
/// in the app accent that deepens to a full 2px accent on focus.
InputDecorationTheme _inputDecoration({
  required Color primary,
  required Color fill,
}) {
  final radius = BorderRadius.circular(16);
  return InputDecorationTheme(
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: primary.withValues(alpha: 0.35)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: primary.withValues(alpha: 0.35)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: NkColors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: NkColors.red, width: 2),
    ),
  );
}

ThemeData nkDarkTheme([AppAccent accent = AppAccent.purple]) {
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
    inputDecorationTheme: _inputDecoration(
      primary: primary,
      fill: NkColors.darkCard,
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
  /// Falls back to the default purple if a theme was built without the
  /// extension (tests, previews).
  Color get primary =>
      Theme.of(this).extension<NkAccentColors>()?.primary ??
      (isDark ? NkColors.darkPrimary : NkColors.lightPrimary);
}
