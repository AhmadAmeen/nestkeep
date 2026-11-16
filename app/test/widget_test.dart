import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets.dart';

void main() {
  testWidgets('HealthRing renders score and grade', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: const Scaffold(body: HealthRing(score: 86, grade: 'B')),
      ),
    );
    expect(find.text('86'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('HealthRing renders in dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: nkDarkTheme(),
        home: const Scaffold(body: HealthRing(score: 42, grade: 'F')),
      ),
    );
    expect(find.text('42'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });
}
