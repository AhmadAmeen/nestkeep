/// Build 24, Item D: custom categories. Creating one is Pro;
/// the expense form and the custom-job form share one list;
/// deleting removes a category from the pickers but never from
/// history; a lapsed Pro keeps theirs; the cap is 20. Harness
/// mirrors ticker_flows_test (real database, standalone screens).
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:in_app_purchase_android/src/messages.g.dart' as iap_api;
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/db.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/plan.dart';
import 'package:nestkeep/screens/expenses.dart';
import 'package:nestkeep/screens/plan_screen.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets/category_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
    messenger.setMockMessageHandler(
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
    final docsDir = await Directory.systemTemp.createTemp('nk_cats_test');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => docsDir.path,
    );
  });

  // A fresh home scores 100, so the score badges are earned at
  // seed; a real first run celebrates them silently.
  const seedCelebrated = ['score_80', 'score_a', 'score_95', 'score_100'];

  Future<AppState> seededState({bool pro = false}) async {
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
    await AppDb.setSetting('celebratedBadges', seedCelebrated.join(','));
    final state = AppState();
    await state.init();
    if (pro) {
      state.entitlement =
          const Entitlement(isPro: true, source: EntitlementSource.yearly);
    }
    return state;
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpUntil(
      WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 80 && !condition(); i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpStandalone(WidgetTester tester, AppState state,
      Widget screen) async {
    bigScreen(tester);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          theme: nkLightTheme(state.accent),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Open the Add-cost dialog and then its category picker.
  Future<void> openExpensePicker(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Add a cost'), findsOneWidget);
    await tester.tap(find.byType(CategoryField));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);
  }

  testWidgets('Pro adds a category in the expense picker and the '
      'custom-job picker offers it too', (tester) async {
    final state =
        await tester.runAsync(() => seededState(pro: true)) ??
            (throw StateError('seed'));
    await pumpStandalone(
      tester,
      state,
      Scaffold(body: ExpensesScreen(state: state, onOpenPaywall: () {})),
    );
    await openExpensePicker(tester);
    expect(find.widgetWithText(ListTile, 'Plumbing'), findsOneWidget);

    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Garden');
    await tester.tap(find.text('Add').last);
    // The create is a real database write: poll with real time.
    await pumpUntil(tester, () => state.customCategories.isNotEmpty);
    await tester.pumpAndSettle();

    // Created, and picked straight away in the still-open form.
    expect(state.customCategories.map((c) => c.name), ['Garden']);
    expect(find.text('Garden'), findsOneWidget);

    // Save the expense under the new category.
    await tester.enterText(find.byType(TextField).first, '25');
    await tester.tap(find.text('Add').last);
    await pumpUntil(
        tester, () => find.text('Expense added').evaluate().isNotEmpty);
    expect(state.expenses.single.category, 'Garden');
    await tester.pump(const Duration(seconds: 4));

    // The custom-job form offers the same list.
    await pumpStandalone(
      tester,
      state,
      Scaffold(
        body: PlanScreen(
          state: state,
          onOpenTask: (_) {},
          onOpenPaywall: () {},
        ),
      ),
    );
    await tester.tap(find.text('Add job'));
    await tester.pumpAndSettle();
    expect(find.text('Add a custom job'), findsOneWidget);
    await tester.tap(find.byType(CategoryField));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Garden'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Garden'));
    await tester.pumpAndSettle();
    expect(find.text('Garden'), findsOneWidget);
  });

  testWidgets('a free user tapping New category goes to the '
      'paywall and creates nothing', (tester) async {
    var paywallOpened = false;
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpStandalone(
      tester,
      state,
      Scaffold(
          body: ExpensesScreen(
              state: state, onOpenPaywall: () => paywallOpened = true)),
    );
    await openExpensePicker(tester);
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    expect(paywallOpened, isTrue);
    expect(state.customCategories, isEmpty);
    // The picker closed; the expense form is still open.
    expect(find.text('New category'), findsNothing);
    expect(find.text('Add a cost'), findsOneWidget);
  });

  testWidgets('deleting a category removes it from the picker but '
      'an expense already filed under it still shows the name',
      (tester) async {
    final state =
        await tester.runAsync(() => seededState(pro: true)) ??
            (throw StateError('seed'));
    await tester.runAsync(() async {
      await state.addCustomCategory('Garden');
      final now = DateTime.now();
      await AppDb.insertExpense(Expense(
        homeId: state.activeHome!.id!,
        date: now,
        amount: 25,
        category: 'Garden',
        note: 'Mulch',
        updatedAt: now,
      ));
      await state.reload();
    });
    await pumpStandalone(
      tester,
      state,
      Scaffold(body: ExpensesScreen(state: state, onOpenPaywall: () {})),
    );
    // History displays the name.
    expect(find.textContaining('· Garden'), findsOneWidget);

    // Open the expense for editing: its form still carries the
    // name, and the picker lists the category with its delete.
    await tester.tap(find.text('Mulch'));
    await tester.pumpAndSettle();
    expect(find.text('Edit cost'), findsOneWidget);
    await tester.tap(find.byType(CategoryField));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Garden'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete category'));
    // The delete is a real database write: poll with real time.
    await pumpUntil(tester, () => state.customCategories.isEmpty);
    await tester.pumpAndSettle();
    // It was the form's selected category: the picker closed with
    // a built-in fallback, and the category is gone from state.
    expect(state.customCategories, isEmpty);
    expect(find.text('Interior'), findsOneWidget);

    // Reopening the picker: no Garden row any more.
    await tester.tap(find.byType(CategoryField));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Garden'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Plumbing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // The saved expense is untouched and still displays its name.
    expect(state.expenses.single.category, 'Garden');
    expect(find.textContaining('· Garden'), findsOneWidget);
  });

  testWidgets('the cap is 20: at the cap, New category shows the '
      'ticker and creates nothing', (tester) async {
    final state =
        await tester.runAsync(() => seededState(pro: true)) ??
            (throw StateError('seed'));
    await tester.runAsync(() async {
      for (var i = 1; i <= 20; i++) {
        await state.addCustomCategory('Cat $i');
      }
    });
    await pumpStandalone(
      tester,
      state,
      Scaffold(body: ExpensesScreen(state: state, onOpenPaywall: () {})),
    );
    await openExpensePicker(tester);
    await tester.scrollUntilVisible(
      find.text('New category'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
    await pumpUntil(tester,
        () => find.text('You can have up to 20 custom categories')
            .evaluate()
            .isNotEmpty);
    expect(find.text('You can have up to 20 custom categories'),
        findsOneWidget);
    expect(state.customCategories.length, 20);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a lapsed Pro keeps their categories: listed and '
      'selectable, but creating goes to the paywall', (tester) async {
    var paywallOpened = false;
    final state =
        await tester.runAsync(() => seededState(pro: true)) ??
            (throw StateError('seed'));
    await tester.runAsync(() => state.addCustomCategory('Garden'));
    state.entitlement = Entitlement.free;
    await pumpStandalone(
      tester,
      state,
      Scaffold(
          body: ExpensesScreen(
              state: state, onOpenPaywall: () => paywallOpened = true)),
    );
    await openExpensePicker(tester);
    expect(find.widgetWithText(ListTile, 'Garden'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Garden'));
    await tester.pumpAndSettle();
    // Selected and usable in the form.
    expect(find.text('Garden'), findsOneWidget);

    // But a new one is gated again.
    await tester.tap(find.byType(CategoryField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    expect(paywallOpened, isTrue);
    expect(state.customCategories.length, 1);
  });
}
