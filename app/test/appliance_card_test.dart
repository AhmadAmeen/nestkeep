import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/lifespan.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/appliance_detail.dart';
import 'package:nestkeep/screens/appliances.dart';
import 'package:nestkeep/screens/my_home.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets.dart';

Appliance _appliance({
  String name = 'Fridge',
  DateTime? purchaseDate,
  int? lifespanYears,
  String? condition,
}) =>
    Appliance(
      id: 7,
      homeId: 1,
      name: name,
      purchaseDate: purchaseDate,
      warrantyMonths: 12,
      lifespanYears: lifespanYears,
      condition: condition,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 6, 15);

  group('condition on the model', () {
    test('survives a map round trip', () {
      final a = _appliance(condition: conditionBad);
      final back = Appliance.fromMap(a.toMap());
      expect(back.condition, 'bad');
      expect(_appliance().condition, isNull);
      expect(Appliance.fromMap(_appliance().toMap()).condition, isNull);
    });

    test('copyWith sets and clears the tag', () {
      final set = _appliance().copyWith(condition: conditionExcellent);
      expect(set.condition, 'excellent');
      final cleared = set.copyWith(clearCondition: true);
      expect(cleared.condition, isNull);
      // A copyWith that does not mention the tag keeps it.
      expect(set.copyWith(updatedAt: now).condition, 'excellent');
    });

    test('labels and colours cover the four tags', () {
      expect(conditionLabel(conditionExcellent), 'Excellent');
      expect(conditionLabel(conditionGood), 'Good');
      expect(conditionLabel(conditionBad), 'Bad');
      expect(conditionLabel(conditionWornOut), 'Worn out');
      expect(conditionColor(conditionExcellent), NkColors.lifeGreen);
      expect(conditionColor(conditionGood), NkColors.green);
      expect(conditionColor(conditionBad), NkColors.amber);
      expect(conditionColor(conditionWornOut), NkColors.red);
    });
  });

  group('ConditionChip', () {
    Future<void> pumpChip(WidgetTester tester, String? condition) =>
        tester.pumpWidget(MaterialApp(
          theme: nkLightTheme(),
          home: Scaffold(
            body: ConditionChip(condition: condition, onTap: () {}),
          ),
        ));

    testWidgets('renders each set tag by its label', (tester) async {
      for (final (value, label) in [
        (conditionExcellent, 'Excellent'),
        (conditionGood, 'Good'),
        (conditionBad, 'Bad'),
        (conditionWornOut, 'Worn out'),
      ]) {
        await pumpChip(tester, value);
        expect(find.text(label), findsOneWidget);
        expect(find.text('Set condition'), findsNothing);
      }
    });

    testWidgets('renders the quiet unset state', (tester) async {
      await pumpChip(tester, null);
      expect(find.text('Set condition'), findsOneWidget);
    });
  });

  testWidgets('the picker saves the picked tag, then clears it',
      (tester) async {
    final saved = <String?>[];
    String? current;
    await tester.pumpWidget(MaterialApp(
      theme: nkLightTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showConditionSheet(
                context,
                current: current,
                onSave: (c) async {
                  saved.add(c);
                  current = c;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('How is it doing?'), findsOneWidget);
    await tester.tap(find.text('Worn out'));
    await tester.pumpAndSettle();
    expect(saved, ['worn_out']);
    expect(find.text('How is it doing?'), findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not set'));
    await tester.pumpAndSettle();
    expect(saved, ['worn_out', null]);
  });

  group('ApplianceLifeSection', () {
    Future<void> pumpSection(WidgetTester tester, Appliance a) =>
        tester.pumpWidget(MaterialApp(
          theme: nkLightTheme(),
          home: Scaffold(
            body: ApplianceLifeSection(appliance: a, now: now),
          ),
        ));

    testWidgets('no purchase date: empty track and the honest label',
        (tester) async {
      await pumpSection(tester, _appliance());
      expect(find.text('Add a purchase date to see its life'),
          findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 0);
    });

    testWidgets('dated: the bar shows the life REMAINING (build 24)',
        (tester) async {
      // Three years into a 12-year life: a quarter used, so the
      // bar stands at three quarters — full at new, draining with
      // age. (At exactly half, used and remaining coincide, which
      // is why this fixture is a quarter.)
      final a = _appliance(
        purchaseDate: now.subtract(const Duration(days: 1096)),
        lifespanYears: 12,
      );
      await pumpSection(tester, a);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(lifeRemaining(a, now), 0.001));
      expect(bar.value, closeTo(0.75, 0.01));
      expect(find.text('Year 4 of about 12'), findsOneWidget);
      expect(find.text('Add a purchase date to see its life'), findsNothing);
    });
  });

  testWidgets(
      'Appliance card (via the My Home hub tile): undated appliance '
      'shows the empty bar, the unset chip and the PRO pill; the chip '
      'opens the picker, not the detail', (tester) async {
    // A tall surface so the whole hub, tiles included, is built.
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final s = AppState();
    s.activeHome = Home(
      id: 1,
      name: 'Maple House',
      addressLine: '',
      type: 'house',
      yearBuilt: 1998,
      updatedAt: DateTime(2026, 1, 1),
    );
    s.appliances = [_appliance()];
    await tester.pumpWidget(MaterialApp(
      theme: nkLightTheme(),
      home: Scaffold(
        body: MyHomeScreen(
          state: s,
          onOpenScan: () {},
          onOpenCosts: () {},
          onOpenPaywall: () {},
        ),
      ),
    ));
    // The hub itself lists nothing inline: the card lives behind the
    // Appliances tile (its sublabel is unique on this page).
    expect(find.text('Add a purchase date to see its life'), findsNothing);
    await tester.tap(find.text('1 tracked'));
    await tester.pumpAndSettle();
    expect(find.byType(AppliancesScreen), findsOneWidget);

    expect(find.text('Add a purchase date to see its life'), findsOneWidget);
    expect(find.text('Set condition'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);

    await tester.tap(find.text('Set condition'));
    await tester.pumpAndSettle();
    expect(find.text('How is it doing?'), findsOneWidget);
    expect(find.byType(ApplianceDetailScreen), findsNothing);

    // Dismiss without choosing (no save path is exercised).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('How is it doing?'), findsNothing);
  });
}
