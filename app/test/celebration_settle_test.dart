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
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build 24 reproduction tests for Grand's phone report: a badge
/// celebration earned by a save flow is presented while that flow's
/// own navigation is still in flight, and the flow's pop then eats
/// the celebration dialog instead of its own route — the user is
/// stranded on the form and never lands on the listing.
///
/// On a real phone the window is wide: frames run continuously, so
/// the celebration offer (a post-frame callback after the save's
/// reload) fires in the gap between the reload and the pop. The
/// widget-test harness only pumps frames when told, which is why
/// the older flow tests never saw it. These tests recreate the
/// device interleaving deterministically: the notifications channel
/// answers `cancelAll` — the first call of Reminders.reschedule,
/// which every save flow awaits between its reload and its pop —
/// only after a real 700ms, and the test pumps a frame inside that
/// window, exactly where a phone frame would land.
///
/// The fix (build 24): the Shell presents a celebration only after
/// navigation has fully settled AND a further ~550ms has passed
/// with no new navigation event; any navigation during the wait
/// restarts it.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        // The stall: reschedule's first call answers slowly, which
        // holds every save flow open between its reload (badge
        // queued, celebration offered) and its pop.
        if (call.method == 'cancelAll') {
          await Future<void>.delayed(const Duration(milliseconds: 700));
          return null;
        }
        return call.method == 'initialize' ? true : null;
      },
    );
  });

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // A fresh home scores 100, so the score badges are earned at seed
  // time; a real first run records them as celebrated silently.
  const seedCelebrated = ['score_80', 'score_a', 'score_95', 'score_100'];

  Future<AppState> seededState() async {
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
    await AppDb.setSetting(
        'celebrated_badges', jsonEncode(seedCelebrated));
    final state = AppState();
    await state.init();
    return state;
  }

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

  /// Alternating real-time / fake-frame steps: real IO chains only
  /// advance inside runAsync windows, frames only on pump. Driving
  /// both in small steps walks a flow through every interleaving a
  /// phone would produce.
  Future<void> drive(WidgetTester tester, {int steps = 40}) async {
    for (var i = 0; i < steps; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder,
      {int tries = 40}) async {
    for (var i = 0; i < tries; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
      'appliance add: a frame landing between the save reload and '
      'its pop cannot strand the user on the form', (tester) async {
    bigScreen(tester);
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpShell(tester, state);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'My Home(s)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliances').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fridge');

    // Tap Save in real time: the save writes, reloads (the first-
    // appliance badge queues and the celebration is offered), then
    // stalls inside Reminders.reschedule. A frame lands in that
    // window — the phone interleaving.
    await tester.runAsync(() async {
      await tester.tap(find.text('Save appliance'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();
    await tester.pump();

    // Let the save chain finish (the stall ends, the form pops).
    await drive(tester);
    await tester.pumpAndSettle();

    // The flow's designed end state: the form is gone, the list
    // shows the new appliance, and the celebration is over the
    // LIST — not eaten by the form's pop on the way.
    expect(find.text('Save appliance'), findsNothing);
    expect(find.text('Fridge'), findsWidgets);
    expect(find.text('BADGE EARNED'), findsOneWidget);

    // Dismiss it: the queued ticker follows with its full run.
    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();
    expect(find.text('BADGE EARNED'), findsNothing);
    await pumpUntilFound(tester, find.text('Appliance added'));
    expect(find.text('Appliance added'), findsOneWidget);
    expect(state.appliances, hasLength(1));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'first expense: fine-grained frames through the whole add '
      'still end on Costs with celebration, then ticker',
      (tester) async {
    bigScreen(tester);
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpShell(tester, state);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'My Home(s)'));
    await tester.pumpAndSettle();
    // The Costs tile (the stats strip also says "Costs" nowhere —
    // the tile label is the one).
    await tester.runAsync(() async {
      await tester.tap(find.text('Costs'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Add a cost'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.text('Add').last);

    // Walk the save in small steps so a frame lands at every stage
    // a phone would render one: dialog pop transition, the write,
    // the reload that earns the first-expense badge.
    await drive(tester, steps: 50);
    await tester.pumpAndSettle();

    expect(find.text('Add a cost'), findsNothing);
    expect(find.textContaining('Spent in'), findsOneWidget);
    expect(find.text('BADGE EARNED'), findsOneWidget);

    await tester.tap(find.text('Nice'));
    await tester.pumpAndSettle();
    expect(find.text('BADGE EARNED'), findsNothing);
    await pumpUntilFound(tester, find.text('Expense added'));
    expect(find.text('Expense added'), findsOneWidget);
    expect(state.expenses, hasLength(1));
    expect(find.text('\$40'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
  });
}
