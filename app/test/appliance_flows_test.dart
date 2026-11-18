import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:in_app_purchase_android/src/messages.g.dart' as iap_api;
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/billing.dart';
import 'package:nestkeep/db.dart';
import 'package:nestkeep/main.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/plan.dart';
import 'package:nestkeep/screens/appliances.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build 20 regression tests for the appliance flows, run against a
/// real (FFI) database: the badge-celebration navigation bug, the
/// delete-lands-on-detail bug, and the confirmation tickers.
/// Build 23 added the ticker/celebration sequencing tests: a ticker
/// requested while a badge celebration is showing or pending must
/// queue behind it and appear once it is dismissed — before the
/// fix, the SnackBar fired underneath the modal celebration and
/// its 3 seconds expired while the user was still reading it, so
/// the confirmation was never seen (Grand's phone report: deleting
/// an appliance showed no ticker; adding one that earned a badge
/// showed the celebration but never the ticker).
///
/// Firebase is mocked at the core level so the app's unawaited
/// SyncService calls see "not signed in" and return quietly, exactly
/// as they do for a guest on a real phone.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Constructing Billing touches InAppPurchase.instance, whose
    // Android implementation connects to Play eagerly in its
    // constructor; on a test host that connection fails
    // asynchronously and poisons the test. Billing.init is never
    // called here, so answering that one handshake (the pigeon
    // channel name includes the method) is enough.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.in_app_purchase_android.InAppPurchaseApi.startConnection',
      (message) async =>
          iap_api.InAppPurchaseApi.pigeonChannelCodec.encodeMessage(
        <Object?>[
          iap_api.PlatformBillingResult(
            responseCode: iap_api.PlatformBillingResponse.ok,
            debugMessage: '',
          ),
        ],
      ),
    );
    // Reminders resolves the Android notifications implementation;
    // on a test host nothing registers one and it throws. Register
    // the real Android class — its calls land on the mocked channel
    // below and quietly succeed.
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
  });

  /// Tap something whose handler does real IO (database writes,
  /// reminder scheduling). Those futures cannot complete inside the
  /// fake-async test zone, so the tap runs in real time, then the
  /// tree settles back in the fake zone.
  /// A tall viewport so long forms (the appliance form runs past
  /// the default test surface) render every field, save included.
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    // Follow-on chains (a screen awaiting a popped route, then doing
    // its own IO before popping further) need the real loop again.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pumpAndSettle();
  }

  /// Bounded wait for a state that only arrives once real IO has
  /// finished. The FFI database lives in its own isolate and does not
  /// run on the fake test clock, so on a loaded CI runner the save
  /// chain (update, reload's dozen queries, reminders) can outlast
  /// tapAndSettle's fixed delays; the edit test failed in CI exactly
  /// that way (the detail screen was back, the refreshed name not yet
  /// rendered) while passing locally. Poll with short real waits —
  /// the assertions after this are unchanged, so a genuinely broken
  /// flow still fails, just after seconds of trying rather than one
  /// fixed budget.
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder,
      {int tries = 40}) async {
    for (var i = 0; i < tries; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(AppState, int)> seededState({
    bool withAppliance = false,
    List<String>? celebrated,
  }) async {
    await AppDb.wipeAll();
    final homeId = await AppDb.insertHome(Home(
      name: 'Test home',
      addressLine: '',
      type: 'house',
      yearBuilt: 2000,
      updatedAt: DateTime(2026, 1, 1),
    ));
    await saveProfile(
      homeId,
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
    // Only seeded when a test asks: left unset, the first reload
    // seeds the celebration history silently (the app's first-run
    // rule), so baseline badges do not fire as celebrations.
    if (celebrated != null) {
      await AppDb.setSetting('celebrated_badges', jsonEncode(celebrated));
    }
    if (withAppliance) {
      await AppDb.insertAppliance(Appliance(
        homeId: homeId,
        name: 'Old fridge',
        warrantyMonths: 24,
        updatedAt: DateTime(2026, 1, 1),
      ));
    }
    final state = AppState();
    await state.init();
    return (state, homeId);
  }

  /// The full Shell harness: the app root wraps MaterialApp in an
  /// AnimatedBuilder on the state (NestKeepApp), which is what
  /// refreshes the pushed list screens on a real phone, and the
  /// Shell is where celebrations are presented and tickers queue.
  Future<void> pumpShell(WidgetTester tester, AppState state) async {
    TickerCenter.resetForTest();
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          navigatorObservers: [appRouteObserver, celebrationObserver],
          theme: nkLightTheme(state.accent),
          home: Shell(
            state: state,
            billing: Billing(),
            themeMode: ThemeMode.system,
            onThemeChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goToAppliances(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'My Home(s)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliances').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'adding an appliance that earns a badge still lands back on the '
      'list, with the celebration over it, and the ticker after it',
      (tester) async {
    bigScreen(tester);
    final (state, _) = await tester.runAsync(seededState) ?? (throw StateError('seed failed'));
    await pumpShell(tester, state);
    await goToAppliances(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fridge');
    await tapAndSettle(tester, find.text('Save appliance'));

    // The navigation completed: the form is gone and the list shows
    // the new appliance. Before the build-20 fix, the celebration
    // dialog ate the form's pop and the user stayed on the form.
    expect(find.text('Save appliance'), findsNothing);
    expect(find.text('Fridge'), findsWidgets);
    // The badge celebration shows over the list...
    expect(find.text('BADGE EARNED'), findsOneWidget);
    // ...and the ticker is NOT under it: it queues behind the
    // celebration (build 23), so it cannot expire unseen while the
    // user reads. The user takes a few seconds over the
    // celebration — longer than a ticker's whole life.
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();
    expect(find.text('BADGE EARNED'), findsNothing);
    expect(find.text('Fridge'), findsWidgets);
    // Only now does the confirmation appear, with its full run.
    await pumpUntilFound(tester, find.text('Appliance added'));
    expect(find.text('Appliance added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'deleting from the detail screen ends on the list with the '
      'ticker, not back on the deleted detail page', (tester) async {
    bigScreen(tester);
    final (state, _) = await tester.runAsync(() => seededState(
          withAppliance: true,
          celebrated: const ['first_appliance'],
        )) ??
        (throw StateError('seed failed'));
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          theme: nkLightTheme(state.accent),
          home: AppliancesScreen(
            state: state,
            onOpenScan: () {},
            onOpenPaywall: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old fridge'), findsOneWidget);
    await tester.tap(find.text('Old fridge'));
    await tester.pumpAndSettle();
    expect(find.text('Edit appliance'), findsOneWidget);
    await tester.tap(find.text('Edit appliance'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.delete_outline));

    // All the way back on the list: no form, no detail page, the
    // item is gone and the ticker confirms the delete.
    expect(find.text('Save appliance'), findsNothing);
    expect(find.text('Edit appliance'), findsNothing);
    expect(find.text('Old fridge'), findsNothing);
    expect(find.text('Appliance deleted'), findsOneWidget);
    expect(state.appliances, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('editing an appliance shows the updated ticker back on '
      'its detail screen', (tester) async {
    bigScreen(tester);
    final (state, _) = await tester.runAsync(() => seededState(
          withAppliance: true,
          celebrated: const ['first_appliance'],
        )) ??
        (throw StateError('seed failed'));
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          theme: nkLightTheme(state.accent),
          home: AppliancesScreen(
            state: state,
            onOpenScan: () {},
            onOpenPaywall: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old fridge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit appliance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'New fridge');
    await tapAndSettle(tester, find.text('Save appliance'));

    // The detail screen re-renders from reloaded state and the
    // ticker follows in the same continuation; on a loaded runner
    // either can land after tapAndSettle's fixed budget. Wait for
    // both, bounded, then assert exactly as before.
    await pumpUntilFound(tester, find.text('New fridge'));
    await pumpUntilFound(tester, find.text('Appliance updated'));

    expect(find.text('Save appliance'), findsNothing);
    expect(find.text('Edit appliance'), findsOneWidget);
    expect(find.text('New fridge'), findsWidgets);
    expect(find.text('Appliance updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  // A fresh home scores 100 (no tasks), so the score badges are
  // earned at seed time too; a real first run seeds every earned
  // badge silently, which is what this list mirrors.
  const seedCelebrated = [
    'first_appliance',
    'score_80',
    'score_a',
    'score_95',
    'score_100',
  ];

  testWidgets(
      'deleting in the full Shell ends on the list with the ticker',
      (tester) async {
    bigScreen(tester);
    final (state, _) = await tester.runAsync(() => seededState(
          withAppliance: true,
          celebrated: seedCelebrated,
        )) ??
        (throw StateError('seed failed'));
    await pumpShell(tester, state);
    await goToAppliances(tester);
    expect(find.text('Old fridge'), findsOneWidget);
    await tester.tap(find.text('Old fridge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit appliance'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.delete_outline));

    expect(find.text('Save appliance'), findsNothing);
    expect(find.text('Edit appliance'), findsNothing);
    expect(find.text('Old fridge'), findsNothing);
    expect(find.text('Appliance deleted'), findsOneWidget);
    expect(state.appliances, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'a celebration landing with the delete: the deleted ticker '
      'waits and shows after it', (tester) async {
    bigScreen(tester);
    final (state, _) = await tester.runAsync(() => seededState(
          withAppliance: true,
          celebrated: seedCelebrated,
        )) ??
        (throw StateError('seed failed'));
    await pumpShell(tester, state);
    // The phone scenario behind Grand's report: a badge celebration
    // is in flight at the moment the delete lands (earned a moment
    // before, its presentation deferred until navigation settled).
    // Simulate it with a one-shot listener: the moment the delete's
    // reload empties the appliance list, a celebration becomes
    // pending, exactly as if that reload had earned it.
    final badge =
        state.currentBadges.firstWhere((b) => b.id == 'first_appliance');
    var injected = false;
    state.addListener(() {
      if (!injected && state.appliances.isEmpty) {
        injected = true;
        state.pendingCelebrations = [badge];
      }
    });
    await goToAppliances(tester);
    await tester.tap(find.text('Old fridge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit appliance'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.delete_outline));

    expect(find.text('Old fridge'), findsNothing);
    // The celebration is on screen over the list and the ticker is
    // queued behind it, not expiring underneath.
    expect(find.text('BADGE EARNED'), findsOneWidget);
    expect(TickerCenter.queuedCount, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();
    expect(find.text('BADGE EARNED'), findsNothing);
    await pumpUntilFound(tester, find.text('Appliance deleted'));
    expect(find.text('Appliance deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
