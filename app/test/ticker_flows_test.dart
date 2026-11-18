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
import 'package:nestkeep/billing.dart';
import 'package:nestkeep/db.dart';
import 'package:nestkeep/main.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/plan.dart';
import 'package:nestkeep/screens/belongings.dart';
import 'package:nestkeep/screens/contractors.dart';
import 'package:nestkeep/screens/documents.dart';
import 'package:nestkeep/screens/expenses.dart';
import 'package:nestkeep/screens/home_notes.dart';
import 'package:nestkeep/screens/plan_screen.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build 23 ticker audit: every CRUD flow's confirmation ticker,
/// driven end to end against the real database — contractor,
/// belonging, note, expense, document, space and custom job —
/// plus the coexistence proofs: where a first-time flow earns a
/// badge (first expense, first custom job, first document), the
/// celebration shows AND the ticker still arrives once the
/// celebration is dismissed (the build 23 sequencing rule).
/// Appliance flows and receipt save have their own files
/// (appliance_flows_test, scan_gate_test), home add/delete lives
/// in home_dropdown_test.
void main() {
  late Directory docsDir;

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
    // Billing's constructor connects to Play eagerly; answer its
    // one handshake on the pigeon channel (same setup as
    // appliance_flows_test). Billing.init is never called here.
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
    // Document photos: the picker hands back a prepared file and
    // the documents folder is a real temp dir.
    docsDir = await Directory.systemTemp.createTemp('nestkeep_docs_test');
    final picked = File('${docsDir.path}/picked_doc.jpg');
    await picked.writeAsBytes([7, 7, 7]);
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => docsDir.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (call) async => call.method == 'pickImage' ? picked.path : null,
    );
  });

  // A fresh home scores 100 (no tasks), so the score badges are
  // earned at seed; a real first run celebrates them silently.
  const seedCelebrated = ['score_80', 'score_a', 'score_95', 'score_100'];

  Future<AppState> seededState({
    List<String> celebrated = seedCelebrated,
    bool pro = false,
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
    await AppDb.setSetting(
        'celebratedBadges', celebrated.join(','));
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

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
    // Flows whose write happens after a pop (dialog results, form
    // returns) can land after the first settle; a second round
    // with a real-time window lets that IO finish and its frame
    // render.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Alternating real-time / fake-frame pump until [condition]
  /// holds. Post-pop flows (dialog results) run a chain of real
  /// database writes whose continuations only advance when the
  /// test gives them both; fixed settles starve the chain.
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
    // The AnimatedBuilder mirrors the app root: it is what
    // rebuilds the list screens when a save reloads the state.
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

  // ---------- standalone flows (no celebration in flight) ----------

  testWidgets('contractor add, edit and delete each show their '
      'ticker', (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpStandalone(tester, state, ContractorsScreen(state: state));

    await tapAndSettle(tester, find.byIcon(Icons.add));
    await tester.enterText(find.byType(TextField).first, 'Mike');
    await tapAndSettle(tester, find.text('Save'));
    expect(find.text('Contractor added'), findsOneWidget);
    expect(find.text('Mike'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text('Mike'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mike P');
    await tapAndSettle(tester, find.text('Save'));
    expect(find.text('Contractor updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text('Mike P'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.delete_outline));
    expect(find.text('Contractor deleted'), findsOneWidget);
    expect(state.contractors, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('belonging add and delete each show their ticker',
      (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpStandalone(tester, state, BelongingsScreen(state: state));

    await tapAndSettle(tester, find.byIcon(Icons.add));
    await tester.enterText(find.byType(TextField).first, 'Ladder');
    await tapAndSettle(tester, find.text('Save'));
    expect(find.text('Belonging added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text('Ladder'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.delete_outline));
    expect(find.text('Belonging deleted'), findsOneWidget);
    expect(state.belongings, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('note add and delete each show their ticker',
      (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpStandalone(tester, state, NotesScreen(state: state));

    await tapAndSettle(tester, find.byIcon(Icons.add));
    await tester.enterText(find.byType(TextField).first, 'Paint');
    await tapAndSettle(tester, find.text('Save note'));
    expect(find.text('Note added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.text('Paint'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.delete_outline));
    expect(find.text('Note deleted'), findsOneWidget);
    expect(state.homeNotes, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('expense add, edit and delete each show their ticker',
      (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpStandalone(
      tester,
      state,
      Scaffold(
          body: ExpensesScreen(state: state, onOpenPaywall: () {})),
    );

    // Add: the screen's Add button opens the cost dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.text('Add').last);
    await pumpUntil(
        tester, () => find.text('Expense added').evaluate().isNotEmpty);
    expect(find.text('Expense added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Edit: tap the entry (the last $40 — the first is the year
    // total in the header), change the amount, save.
    await tester.tap(find.text('\$40').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit cost'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '55');
    await tester.tap(find.text('Save changes'));
    await pumpUntil(
        tester, () => find.text('Expense updated').evaluate().isNotEmpty);
    expect(find.text('Expense updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Delete: from the edit dialog, confirmed.
    await tester.tap(find.text('\$55').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await pumpUntil(
        tester, () => find.text('Expense deleted').evaluate().isNotEmpty);
    expect(find.text('Expense deleted'), findsOneWidget);
    expect(state.expenses, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('space add and delete, document add and delete '
      'each show their ticker (Pro)', (tester) async {
    final state = await tester.runAsync(() => seededState(pro: true)) ??
        (throw StateError('seed'));
    await pumpStandalone(
      tester,
      state,
      DocumentsScreen(state: state, onOpenPaywall: () {}),
    );

    // Add a space from the chips row's add chip.
    await tester.tap(find.text('Space'));
    await tester.pumpAndSettle();
    expect(find.text('Add a space'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kitchen');
    await tester.tap(find.text('Save'));
    await pumpUntil(
        tester, () => find.text('Space added').evaluate().isNotEmpty);
    expect(find.text('Space added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Add a document: heading Add -> source sheet -> gallery ->
    // title form -> saved.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Pick from gallery'));
    // The dialog title (the empty-state button behind the sheet
    // carries the same words).
    expect(find.text('Add document'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'Deed');
    await tester.tap(find.text('Save'));
    await pumpUntil(
        tester, () => find.text('Document added').evaluate().isNotEmpty);
    expect(find.text('Document added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Delete the document from its photo view.
    await tester.tap(find.text('Deed'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.delete_outline));
    expect(find.text('Delete this document?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await pumpUntil(
        tester, () => find.text('Document deleted').evaluate().isNotEmpty);
    // findsWidgets: the messenger renders the one ticker in each
    // nested Scaffold of the pushed screen's subtree.
    expect(find.text('Document deleted'), findsWidgets);
    expect(state.docs, isEmpty);
    await tester.pump(const Duration(seconds: 4));

    // Delete the space: long-press its chip, Delete space, confirm.
    await tester.longPress(find.text('Kitchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete space'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Kitchen?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await pumpUntil(
        tester, () => find.text('Space deleted').evaluate().isNotEmpty);
    expect(find.text('Space deleted'), findsOneWidget);
    expect(state.spaces, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('custom job add shows its ticker', (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
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
    await tester.enterText(find.byType(TextField).first, 'Water plants');
    await tester.tap(find.text('Add'));
    await pumpUntil(
        tester, () => find.text('Task added').evaluate().isNotEmpty);
    expect(find.text('Task added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  // ---------- coexistence: badge + ticker (full Shell) ----------

  Future<void> pumpShell(WidgetTester tester, AppState state) async {
    TickerCenter.resetForTest();
    bigScreen(tester);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          theme: nkLightTheme(state.accent),
          navigatorObservers: [appRouteObserver, celebrationObserver],
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

  /// Dismiss every celebration on screen (a flow can queue more
  /// than one). The presence check polls only briefly: a long
  /// empty poll would burn fake seconds the released ticker
  /// (3s life) does not have.
  Future<void> dismissCelebrations(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      for (var j = 0;
          j < 5 && find.text('BADGE EARNED').evaluate().isEmpty;
          j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (find.text('BADGE EARNED').evaluate().isEmpty) return;
      // Prove the ticker waits: 4 fake seconds under the
      // celebration would outlive any un-queued ticker.
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.text('Nice'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('first expense: celebration shows, then the '
      'Expense added ticker arrives', (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpShell(tester, state);
    await tester.tap(find.text('My Home(s)'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Costs'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.text('Add').last);
    await pumpUntil(
        tester, () => find.text('BADGE EARNED').evaluate().isNotEmpty);

    expect(find.text('BADGE EARNED'), findsOneWidget);
    expect(TickerCenter.queuedCount, greaterThanOrEqualTo(1));
    await dismissCelebrations(tester);
    await pumpUntilFound(tester, find.text('Expense added'));
    expect(find.text('Expense added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('first custom job: celebration shows, then the '
      'Task added ticker arrives', (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpShell(tester, state);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add job'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Water plants');
    await tester.tap(find.text('Add'));
    await pumpUntil(
        tester, () => find.text('BADGE EARNED').evaluate().isNotEmpty);

    expect(find.text('BADGE EARNED'), findsOneWidget);
    await dismissCelebrations(tester);
    await pumpUntilFound(tester, find.text('Task added'));
    expect(find.text('Task added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('first document: celebration shows, then the '
      'Document added ticker arrives', (tester) async {
    final state = await tester.runAsync(() => seededState(
          celebrated: [...seedCelebrated, 'pro_member'],
          pro: true,
        )) ??
        (throw StateError('seed'));
    await pumpShell(tester, state);
    await tester.tap(find.text('My Home(s)'));
    await tester.pumpAndSettle();
    // The hub's summary stat is also labelled Documents; the
    // tile is the last one.
    await tapAndSettle(tester, find.text('Documents').last);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Pick from gallery'));
    // The dialog title (the empty-state button behind the sheet
    // carries the same words).
    expect(find.text('Add document'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'Deed');
    await tester.tap(find.text('Save'));
    await pumpUntil(
        tester, () => find.text('BADGE EARNED').evaluate().isNotEmpty);

    expect(find.text('BADGE EARNED'), findsOneWidget);
    await dismissCelebrations(tester);
    await pumpUntilFound(tester, find.text('Document added'));
    expect(find.text('Document added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
