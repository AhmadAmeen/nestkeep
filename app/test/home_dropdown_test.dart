import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/db.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/plan.dart';
import 'package:nestkeep/screens/my_home.dart';
import 'package:nestkeep/theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build 23: home management lives in the My Home header. The big
/// title is a dropdown: it lists the homes (current one ticked,
/// tap switches), then Add home / Edit home / Delete home. These
/// tests drive the real screen against the real database: the caps
/// (Free paywall, 3-home limit), the edit detour, the delete rules
/// (switch + "Home deleted" ticker; the only home is protected).
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
  });

  Future<AppState> seededState(List<String> names,
      {bool pro = false}) async {
    await AppDb.wipeAll();
    for (final name in names) {
      final id = await AppDb.insertHome(Home(
        name: name,
        addressLine: '',
        type: 'house',
        yearBuilt: 2000,
        updatedAt: DateTime(2026, 1, 1),
      ));
      await saveProfile(
        id,
        const HomeProfile(
          homeType: 'house',
          heating: 'forced_air',
          cooling: 'central',
          hasBasement: false,
          hasGarage: false,
          hasDeck: false,
          hasSprinklers: false,
          hasSoftener: false,
          hasChimney: false,
        ),
      );
    }
    final state = AppState();
    await state.init();
    if (pro) {
      state.entitlement =
          const Entitlement(isPro: true, source: EntitlementSource.yearly);
    }
    return state;
  }

  Future<void> pumpHome(
    WidgetTester tester,
    AppState state, {
    VoidCallback? onAddHome,
    VoidCallback? onOpenPaywall,
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          theme: nkLightTheme(state.accent),
          home: Scaffold(
            body: MyHomeScreen(
              state: state,
              onOpenPaywall: onOpenPaywall ?? () {},
              onAddHome: onAddHome ?? () {},
              onOpenCosts: () {},
              onOpenScan: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    // Menu selections fire as the menu pops and their async work
    // (reload, delete) can land after the first settle; give the
    // rebuild a second round so assertions see the settled tree.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Finder menuButton() =>
      find.byWidgetPredicate((w) => w is PopupMenuButton);

  /// Menu actions kick off real async work (reload, delete)
  /// whose notify can land between fake-time settles; poll,
  /// alternating real time (for the IO) with frames (for the
  /// rebuild), until [condition] holds.
  Future<void> pumpUntil(
      WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 60 && !condition(); i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(menuButton());
    await tester.pumpAndSettle();
  }

  testWidgets('the header is the home dropdown: name, chevron, '
      'all homes listed with the current one ticked', (tester) async {
    final state = await tester.runAsync(
            () => seededState(['Alpha house', 'Beta house'])) ??
        (throw StateError('seed failed'));
    await pumpHome(tester, state);

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(menuButton(), findsOneWidget);
    await openMenu(tester);
    // Both homes are menu rows, plus the three actions.
    expect(find.text('Beta house'), findsWidgets);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Add home'), findsOneWidget);
    expect(find.text('Edit home'), findsOneWidget);
    expect(find.text('Delete home'), findsOneWidget);
  });

  testWidgets('tapping another home in the dropdown switches to it',
      (tester) async {
    final state = await tester.runAsync(
            () => seededState(['Alpha house', 'Beta house'])) ??
        (throw StateError('seed failed'));
    await pumpHome(tester, state);
    expect(state.activeHome?.name, 'Alpha house');

    await openMenu(tester);
    await tapAndSettle(tester, find.text('Beta house').last);
    await pumpUntil(
        tester, () => find.text('Beta house').evaluate().isNotEmpty);
    expect(state.activeHome?.name, 'Beta house');
    // The header now leads with the new home.
    expect(find.text('Beta house'), findsWidgets);
  });

  testWidgets('Add home on Free with one home opens the paywall, '
      'not the wizard', (tester) async {
    var paywallCalls = 0;
    var addCalls = 0;
    final state = await tester
            .runAsync(() => seededState(['Only house'])) ??
        (throw StateError('seed failed'));
    await pumpHome(
      tester,
      state,
      onAddHome: () => addCalls++,
      onOpenPaywall: () => paywallCalls++,
    );
    await openMenu(tester);
    await tester.tap(find.text('Add home'));
    await tester.pumpAndSettle();
    expect(paywallCalls, 1);
    expect(addCalls, 0);
  });

  testWidgets('Add home on Pro under the cap opens the wizard',
      (tester) async {
    var addCalls = 0;
    final state = await tester.runAsync(
            () => seededState(['One house', 'Two house'], pro: true)) ??
        (throw StateError('seed failed'));
    await pumpHome(tester, state, onAddHome: () => addCalls++);
    await openMenu(tester);
    await tester.tap(find.text('Add home'));
    await tester.pumpAndSettle();
    expect(addCalls, 1);
  });

  testWidgets('Add home at three homes shows the limit ticker',
      (tester) async {
    var addCalls = 0;
    final state = await tester.runAsync(() => seededState(
            ['One house', 'Two house', 'Three house'],
            pro: true)) ??
        (throw StateError('seed failed'));
    await pumpHome(tester, state, onAddHome: () => addCalls++);
    await openMenu(tester);
    await tester.tap(find.text('Add home'));
    await tester.pumpAndSettle();
    expect(addCalls, 0);
    expect(find.text('3 homes is the limit'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Edit home opens the home details already editing',
      (tester) async {
    final state = await tester
            .runAsync(() => seededState(['Alpha house'])) ??
        (throw StateError('seed failed'));
    await pumpHome(tester, state);
    await openMenu(tester);
    await tapAndSettle(tester, find.text('Edit home'));
    await pumpUntil(
        tester, () => find.text('Save changes').evaluate().isNotEmpty);
    // The details screen opened straight into its edit form.
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Alpha house'), findsOneWidget);
  });

  testWidgets('Delete home: confirm deletes it, switches to the '
      'other home and shows the ticker', (tester) async {
    final state = await tester.runAsync(
            () => seededState(['Alpha house', 'Beta house'])) ??
        (throw StateError('seed failed'));
    await pumpHome(tester, state);
    await openMenu(tester);
    await tapAndSettle(tester, find.text('Delete home'));
    expect(find.text('Delete this home?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Delete'));
    await pumpUntil(
        tester, () => find.text('Home deleted').evaluate().isNotEmpty);

    expect(state.homes.map((h) => h.name), ['Beta house']);
    expect(state.activeHome?.name, 'Beta house');
    expect(find.text('Home deleted'), findsOneWidget);
    final dbHomes = await tester.runAsync(() => AppDb.homes());
    expect(dbHomes?.map((h) => h.name), ['Beta house']);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('deleting the ONLY home is blocked with its ticker',
      (tester) async {
    final state = await tester
            .runAsync(() => seededState(['Only house'])) ??
        (throw StateError('seed failed'));
    await pumpHome(tester, state);
    await openMenu(tester);
    await tester.tap(find.text('Delete home'));
    await tester.pumpAndSettle();
    await pumpUntil(tester,
        () => find.text('You need at least one home').evaluate().isNotEmpty);
    expect(find.text('Delete this home?'), findsNothing);
    expect(find.text('You need at least one home'), findsOneWidget);
    expect(state.homes, hasLength(1));
    await tester.pump(const Duration(seconds: 4));
  });
}
