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
    // The ring sweeps up from zero; let it land before reading it.
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });

  String centreNumber(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((d) => int.tryParse(d) != null);

  testWidgets('HealthRing sweeps from zero to the score', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: const Scaffold(body: HealthRing(score: 86, grade: 'B')),
      ),
    );

    // First frame: the sweep has not started, the number sits at zero.
    expect(centreNumber(tester), '0');
    // Halfway through the ~900ms sweep the number is on its way up.
    await tester.pump(const Duration(milliseconds: 450));
    final mid = int.parse(centreNumber(tester));
    expect(mid, greaterThan(0));
    expect(mid, lessThan(86));
    // After the sweep the final value is shown.
    await tester.pump(const Duration(milliseconds: 500));
    expect(centreNumber(tester), '86');
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('HealthRing re-sweeps when the score changes', (tester) async {
    Widget ring(int score, String grade) => MaterialApp(
          theme: nkLightTheme(),
          home: Scaffold(body: HealthRing(score: score, grade: grade)),
        );
    await tester.pumpWidget(ring(40, 'C'));
    await tester.pumpAndSettle();
    expect(find.text('40'), findsOneWidget);

    await tester.pumpWidget(ring(90, 'A'));
    await tester.pump(const Duration(milliseconds: 450));
    // Mid-sweep between the old and new values, not snapped to either.
    final mid = int.parse(centreNumber(tester));
    expect(mid, greaterThan(40));
    expect(mid, lessThan(90));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('90'), findsOneWidget);
  });
}
