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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build 20 regression tests for the appliance flows, run against a
/// real (FFI) database: the badge-celebration navigation bug, the
/// delete-lands-on-detail bug, and the confirmation tickers.
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

  testWidgets(
      'adding an appliance that earns a badge still lands back on the '
      'list, with the celebration over it', (tester) async {
    bigScreen(tester);
    final (state, _) = await tester.runAsync(seededState) ?? (throw StateError('seed failed'));
    // The app root wraps MaterialApp in an AnimatedBuilder on the
    // state (NestKeepApp): every reload rebuilds the theme, which
    // is what refreshes the pushed list screens on a real phone.
    // The harness mirrors that shape.
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
    await tester.tap(find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'My Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliances').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fridge');
    await tapAndSettle(tester, find.text('Save appliance'));

    // The navigation completed: the form is gone and the list shows
    // the new appliance. Before the fix, the celebration dialog ate
    // the form's pop and the user stayed on the form.
    expect(find.text('Save appliance'), findsNothing);
    expect(find.text('Fridge'), findsWidgets);
    // The ticker confirms the add on the list screen...
    expect(find.text('Appliance added'), findsOneWidget);
    // ...and the badge celebration shows over the list.
    expect(find.text('BADGE EARNED'), findsOneWidget);
    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();
    expect(find.text('BADGE EARNED'), findsNothing);
    expect(find.text('Fridge'), findsWidgets);
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

    expect(find.text('Save appliance'), findsNothing);
    expect(find.text('Edit appliance'), findsOneWidget);
    expect(find.text('New fridge'), findsWidgets);
    expect(find.text('Appliance updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
