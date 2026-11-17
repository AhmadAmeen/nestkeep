import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/theme.dart';

void main() {
  group('parseAppAccent', () {
    test('current purple-family names map to themselves', () {
      expect(parseAppAccent('indigo'), AppAccent.indigo);
      expect(parseAppAccent('purple'), AppAccent.purple);
      expect(parseAppAccent('plum'), AppAccent.plum);
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

  test('the default themes carry the purple accent', () {
    expect(nkLightTheme().extension<NkAccentColors>()!.primary,
        const Color(0xFF6D4DF6));
    expect(nkDarkTheme().extension<NkAccentColors>()!.primary,
        const Color(0xFFA48FFF));
  });

  test('each accent resolves its light and dark primaries', () {
    expect(AppAccent.indigo.primaryFor(false), const Color(0xFF5457E8));
    expect(AppAccent.indigo.primaryFor(true), const Color(0xFF9AA0FF));
    expect(AppAccent.purple.primaryFor(false), const Color(0xFF6D4DF6));
    expect(AppAccent.purple.primaryFor(true), const Color(0xFFA48FFF));
    expect(AppAccent.plum.primaryFor(false), const Color(0xFFB44FD8));
    expect(AppAccent.plum.primaryFor(true), const Color(0xFFD98CFF));
  });
}
