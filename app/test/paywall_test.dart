import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/billing.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/paywall.dart';
import 'package:nestkeep/theme.dart';

AppState _state({bool pro = false}) {
  final s = AppState();
  s.entitlement = pro
      ? const Entitlement(isPro: true, source: EntitlementSource.yearly)
      : Entitlement.free;
  return s;
}

/// Pumps the paywall with a real Billing whose product list is empty
/// (as before Play answers), so prices fall back to the USD list prices.
Future<void> _pump(WidgetTester tester, AppState state,
    {bool dark = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? nkDarkTheme() : nkLightTheme(),
      home: Scaffold(body: PaywallScreen(state: state, billing: Billing())),
    ),
  );
}

void main() {
  testWidgets('plan cards render with the right prices', (tester) async {
    await _pump(tester, _state());
    // The hero and the value anchor lead the page.
    expect(find.text('NestKeep Pro'), findsOneWidget);
    expect(find.text('Everything your home needs, in one place.'),
        findsOneWidget);
    expect(find.textContaining('\$120 a year'), findsOneWidget);
    // Scroll the plan cards into view.
    await tester.scrollUntilVisible(find.text('\$29.99/year'), 120);
    expect(find.text('Pro Yearly'), findsOneWidget);
    expect(find.text('\$29.99/year'), findsOneWidget);
    expect(find.text('BEST VALUE'), findsOneWidget);
    expect(find.textContaining('14 days free'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('\$79.99 once'), 120);
    expect(find.text('Pro Monthly'), findsOneWidget);
    expect(find.text('\$4.99/month'), findsOneWidget);
    expect(find.text('Lifetime'), findsOneWidget);
    expect(find.text('\$79.99 once'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('yearly is preselected, so the button offers the trial',
      (tester) async {
    await _pump(tester, _state());
    expect(find.text('Start my 14 free days'), findsOneWidget);
    expect(find.text('Get Lifetime, \$79.99'), findsNothing);
  });

  testWidgets('selecting Lifetime changes the buy button label',
      (tester) async {
    await _pump(tester, _state());
    await tester.scrollUntilVisible(find.text('\$79.99 once'), 120);
    await tester.pump();
    await tester.tap(find.text('Lifetime'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Get Lifetime, \$79.99'), findsOneWidget);
    expect(find.text('Start my 14 free days'), findsNothing);
  });

  testWidgets('selecting Monthly changes the buy button label',
      (tester) async {
    await _pump(tester, _state());
    await tester.scrollUntilVisible(find.text('\$4.99/month'), 120);
    await tester.pump();
    await tester.tap(find.text('Pro Monthly'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Go Pro, \$4.99/month'), findsOneWidget);
    expect(find.text('Start my 14 free days'), findsNothing);
  });

  testWidgets('plan cards render in the dark theme too', (tester) async {
    await _pump(tester, _state(), dark: true);
    await tester.scrollUntilVisible(find.text('\$29.99/year'), 120);
    expect(find.text('\$29.99/year'), findsOneWidget);
    expect(find.text('Start my 14 free days'), findsOneWidget);
  });

  testWidgets('the already-Pro state still renders', (tester) async {
    await _pump(tester, _state(pro: true));
    expect(find.text('Pro is active'), findsWidgets);
    expect(find.textContaining('Plan: yearly'), findsOneWidget);
    expect(find.text('Manage or cancel in Google Play'), findsOneWidget);
    expect(find.text('Start my 14 free days'), findsNothing);
    expect(find.text('\$29.99/year'), findsNothing);
  });
}
