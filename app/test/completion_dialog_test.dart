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
import 'package:nestkeep/screens/today.dart';
import 'package:nestkeep/actions.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets/animated_check.dart';
import 'package:nestkeep/widgets/done_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build 23 completion-dialog tests, against the real database
/// and the real completeTask wiring the Shell uses:
///
/// - the Cost field starts EMPTY with a plain "0.00" placeholder
///   (Grand's screenshot showed the sentence "0 if you did it
///   yourself" sitting inside the money field — that text is gone
///   from the field entirely);
/// - the quick tick on a task card opens this same dialog and the
///   job completes only on Save / Nothing;
/// - Save with a number records that cost (task + expense row);
/// - Save with the field left empty behaves like 0 (no expense);
/// - "Nothing" completes with no cost;
/// - cancelling leaves the job un-completed, with no animation.
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

  /// A home with two upcoming jobs: the sooner one lands in the
  /// Next-up card, the other in the task list (Today renders each
  /// job once).
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
    final now = DateTime.now();
    for (final (title, days) in [('First job', 1), ('Second job', 2)]) {
      await AppDb.insertTask(TaskInstance(
        homeId: homeId,
        title: title,
        category: 'General',
        dueDate: DateTime(now.year, now.month, now.day + days),
        updatedAt: now,
      ));
    }
    final state = AppState();
    await state.init();
    return state;
  }

  Future<void> pumpToday(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          theme: nkLightTheme(state.accent),
          home: Scaffold(
            body: TodayScreen(
              state: state,
              onSeeAllPlan: () {},
              onOpenTask: (_) {},
              onQuickDone: (t, r) => completeTask(
                state,
                t,
                costPaid: r.cost,
                doneBy: r.doneBy,
                doneNote: r.note,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Real IO (the completion writes) plus fake frames (the tick
  /// and collapse), alternated until [condition] holds.
  Future<void> pumpUntil(
      WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 60 && !condition(); i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openDialogFromCardTick(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('Done. What did it cost?'), findsOneWidget);
  }

  testWidgets('the cost field starts empty with a plain 0.00 '
      'placeholder and no sentence inside it', (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpToday(tester, state);
    await openDialogFromCardTick(tester);

    final field = tester.widget<TextField>(find
        .descendant(
            of: find.byType(DoneDialog),
            matching: find.byType(TextField))
        .first);
    expect(field.controller?.text, '');
    expect(field.decoration?.hintText, '0.00');
    expect(field.decoration?.prefixText, '\$ ');
    // The DIY sentence is nowhere in the dialog.
    expect(find.textContaining('did it yourself'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });

  testWidgets('tick, then Save with a cost: the job completes '
      'with that cost and an expense row', (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpToday(tester, state);
    await openDialogFromCardTick(tester);
    // Not completed yet, and no animation has started.
    expect(find.byType(AnimatedCheck), findsNothing);
    expect(state.tasks.every((t) => t.status == TaskStatus.upcoming),
        isTrue);

    await tester.enterText(
        find
            .descendant(
                of: find.byType(DoneDialog),
                matching: find.byType(TextField))
            .first,
        '30');
    await tester.tap(find.text('Save'));
    // Poll for the expense as well as the done flag: reload()
    // assigns its fields one by one before notifying, so a bare
    // field read can catch it mid-flight.
    await pumpUntil(
        tester,
        () =>
            state.tasks.any((t) =>
                t.title == 'Second job' && t.status == TaskStatus.done) &&
            state.expenses.any((e) => e.amount == 30));

    final done =
        state.tasks.firstWhere((t) => t.title == 'Second job');
    expect(done.costPaid, 30);
    expect(state.expenses.map((e) => e.amount), contains(30));
    final dbExpenses = await tester
        .runAsync(() => AppDb.expensesForHome(state.activeHome!.id!));
    expect(dbExpenses?.map((e) => e.amount), contains(30));
  });

  testWidgets('tick, then Save with the cost left empty: '
      'completes like 0, no expense', (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpToday(tester, state);
    await openDialogFromCardTick(tester);
    await tester.tap(find.text('Save'));
    await pumpUntil(
        tester,
        () => state.tasks
            .any((t) =>
                t.title == 'Second job' && t.status == TaskStatus.done));
    final done =
        state.tasks.firstWhere((t) => t.title == 'Second job');
    expect(done.status, TaskStatus.done);
    expect(state.expenses, isEmpty);
  });

  testWidgets('Next-up tick, then Nothing: completes with no cost',
      (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpToday(tester, state);
    await tester.tap(find.widgetWithText(FilledButton, 'Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('Done. What did it cost?'), findsOneWidget);
    await tester.tap(find.text('Nothing'));
    await pumpUntil(
        tester,
        () => state.tasks
            .any((t) =>
                t.title == 'First job' && t.status == TaskStatus.done));
    final done = state.tasks.firstWhere((t) => t.title == 'First job');
    expect(done.status, TaskStatus.done);
    // "Nothing" records a zero cost and, the part that matters,
    // no expense row.
    expect(done.costPaid ?? 0, 0);
    expect(state.expenses, isEmpty);
  });

  testWidgets('tick, then cancel: the job stays un-completed, '
      'no animation, no expense', (tester) async {
    final state =
        await tester.runAsync(seededState) ?? (throw StateError('seed'));
    await pumpToday(tester, state);
    await openDialogFromCardTick(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Done. What did it cost?'), findsNothing);
    expect(find.byType(AnimatedCheck), findsNothing);
    expect(find.byTooltip('Mark done'), findsOneWidget);
    expect(
        state.tasks
            .firstWhere((t) => t.title == 'Second job')
            .status,
        TaskStatus.upcoming);
    expect(state.expenses, isEmpty);
  });
}
