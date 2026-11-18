import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/history.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets/month_calendar.dart';

/// Build 21: History gains a List / Calendar switch, mirroring Plan.
/// The calendar marks the days that have completions with green dots
/// and lists exactly the tapped day's finished jobs underneath, in
/// the same rows as the list.
TaskInstance _done(String title, DateTime doneDay) => TaskInstance(
      homeId: 1,
      title: title,
      category: 'Interior',
      dueDate: doneDay,
      status: TaskStatus.done,
      doneDate: doneDay,
      updatedAt: doneDay,
    );

void main() {
  // Two jobs finished on one day, one job finished today, all inside
  // the displayed month so the grid shows them without stepping.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final otherDay =
      today.add(Duration(days: today.day >= 15 ? -3 : 3));

  AppState seeded() {
    final state = AppState();
    state.tasks = [
      _done('Fixed the tap', today),
      _done('Painted the fence', otherDay),
      _done('Cleared the gutters', otherDay),
      TaskInstance(
        homeId: 1,
        title: 'Still to do',
        category: 'Interior',
        dueDate: today,
        status: TaskStatus.upcoming,
        updatedAt: today,
      ),
    ];
    return state;
  }

  Future<void> pumpHistory(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: HistoryScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the list is the default and shows every finished job',
      (tester) async {
    await pumpHistory(tester, seeded());
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Fixed the tap'), findsOneWidget);
    expect(find.text('Painted the fence'), findsOneWidget);
    expect(find.text('Cleared the gutters'), findsOneWidget);
    expect(find.text('Still to do'), findsNothing);
    expect(find.byType(MonthCalendarGrid), findsNothing);
  });

  testWidgets('calendar marks completion days with green dots and '
      'lists exactly the tapped day\'s jobs', (tester) async {
    await pumpHistory(tester, seeded());
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthCalendarGrid), findsOneWidget);
    expect(find.text('Timeline'), findsNothing);

    // One green dot per completion, capped at three per day: two on
    // the other day, one today.
    final greenDots = find.descendant(
      of: find.byType(MonthCalendarGrid),
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.shape == BoxShape.circle &&
            d.color == NkColors.green &&
            w.constraints?.maxWidth == 5;
      }),
    );
    expect(greenDots, findsNWidgets(3));

    // Today starts selected: only today's job is listed.
    expect(find.text('Fixed the tap'), findsOneWidget);
    expect(find.text('Painted the fence'), findsNothing);
    expect(find.text('Cleared the gutters'), findsNothing);

    // Tap the other day: exactly its two jobs are listed.
    await tester.tap(
      find.descendant(
        of: find.byType(MonthCalendarGrid),
        matching: find.text('${otherDay.day}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Painted the fence'), findsOneWidget);
    expect(find.text('Cleared the gutters'), findsOneWidget);
    expect(find.text('Fixed the tap'), findsNothing);
    expect(find.text('Still to do'), findsNothing);
  });
}
