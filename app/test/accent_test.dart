import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/theme.dart';

void main() {
  group('parseAppAccent', () {
    test('current purple-family names map to themselves', () {
      expect(parseAppAccent('purple'), AppAccent.purple);
      expect(parseAppAccent('violet'), AppAccent.violet);
      expect(parseAppAccent('plum'), AppAccent.plum);
      expect(parseAppAccent('fuchsia'), AppAccent.fuchsia);
    });

    test('retired indigo lands on violet, its nearest neighbour', () {
      expect(parseAppAccent('indigo'), AppAccent.violet);
    });

    test('retired mockup v6 names land on their nearest neighbours', () {
      expect(parseAppAccent('blue'), AppAccent.purple);
      expect(parseAppAccent('orange'), AppAccent.plum);
      expect(parseAppAccent('pink'), AppAccent.plum);
    });

    test('unknown or missing values fall back to purple', () {
      expect(parseAppAccent(null), AppAccent.purple);
      expect(parseAppAccent(''), AppAccent.purple);
      expect(parseAppAccent('teal'), AppAccent.purple);
    });
  });

  test('the picker offers four accents, all in the purple family', () {
    expect(AppAccent.values, [
      AppAccent.purple,
      AppAccent.violet,
      AppAccent.plum,
      AppAccent.fuchsia,
    ]);
    expect(AppAccent.values.map((a) => a.label),
        ['Purple', 'Violet', 'Plum', 'Fuchsia']);
  });

  test('the default themes carry the purple accent', () {
    expect(nkLightTheme().extension<NkAccentColors>()!.primary,
        const Color(0xFF6D4DF6));
    expect(nkDarkTheme().extension<NkAccentColors>()!.primary,
        const Color(0xFFA48FFF));
  });

  test('only Purple is free; the custom colours are Pro', () {
    expect(AppAccent.purple.proOnly, isFalse);
    expect(AppAccent.violet.proOnly, isTrue);
    expect(AppAccent.plum.proOnly, isTrue);
    expect(AppAccent.fuchsia.proOnly, isTrue);
  });

  test('each accent resolves its light and dark primaries', () {
    expect(AppAccent.purple.primaryFor(false), const Color(0xFF6D4DF6));
    expect(AppAccent.purple.primaryFor(true), const Color(0xFFA48FFF));
    expect(AppAccent.violet.primaryFor(false), const Color(0xFF7C3AED));
    expect(AppAccent.violet.primaryFor(true), const Color(0xFFA78BFA));
    expect(AppAccent.plum.primaryFor(false), const Color(0xFFB44FD8));
    expect(AppAccent.plum.primaryFor(true), const Color(0xFFD98CFF));
    expect(AppAccent.fuchsia.primaryFor(false), const Color(0xFFC026D3));
    expect(AppAccent.fuchsia.primaryFor(true), const Color(0xFFE879F9));
  });
}
