import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/today.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets/animated_check.dart';
import 'package:nestkeep/widgets/done_dialog.dart';

void main() {
  testWidgets('AnimatedCheck draws and reports completion once',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(
          body: Center(
            child: AnimatedCheck(
              size: 54,
              onCompleted: () => completions++,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AnimatedCheck), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(AnimatedCheck), matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(completions, 0);

    // Mid-draw: not yet complete.
    await tester.pump(const Duration(milliseconds: 200));
    expect(completions, 0);

    // Past the 450ms draw: completed exactly once, and stays once.
    await tester.pump(const Duration(milliseconds: 300));
    expect(completions, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(completions, 1);
  });

  testWidgets(
      'TaskCard tick asks first (done dialog), then plays the tick, '
      'glides away, and fires onDone once with the dialog answers',
      (tester) async {
    var doneCount = 0;
    var tapCount = 0;
    DoneResult? lastResult;
    final task = TaskInstance(
      id: 7,
      homeId: 1,
      title: 'Test the smoke alarms',
      category: 'Safety',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      updatedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TaskCard(
              task: task,
              onTap: () => tapCount++,
              onDone: (r) async {
                doneCount++;
                lastResult = r;
              },
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Mark done'), findsOneWidget);
    expect(find.byType(AnimatedCheck), findsNothing);

    // The tick opens the done dialog (build 23); nothing has
    // completed and no animation has started.
    await tester.tap(find.byTooltip('Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('Done. What did it cost?'), findsOneWidget);
    expect(find.byType(AnimatedCheck), findsNothing);
    expect(doneCount, 0);

    // Confirm with a cost: the dialog closes, the tick draws, the
    // card glides away, and only then does the completion fire.
    await tester.enterText(
        find.descendant(
            of: find.byType(DoneDialog),
            matching: find.byType(TextField).first),
        '25');
    await tester.tap(find.text('Save'));
    // The dialog pops, then the tick starts drawing. Poll in small
    // steps: the pop, the tick (450ms) and the collapse (300ms)
    // chain off each other's completions.
    for (var i = 0;
        i < 20 && find.text('Done. What did it cost?').evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Done. What did it cost?'), findsNothing);
    expect(find.byType(AnimatedCheck), findsOneWidget);
    expect(find.byTooltip('Mark done'), findsNothing);
    expect(doneCount, 0);
    await tester.tap(find.text('Test the smoke alarms'));
    await tester.pump();
    expect(tapCount, 0);

    // Tick + collapse run their course: onDone fires exactly once,
    // carrying the cost the user entered.
    for (var i = 0; i < 30 && doneCount == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(doneCount, 1);
    expect(lastResult?.cost, 25);
    await tester.pump(const Duration(milliseconds: 500));
    expect(doneCount, 1);
  });

  testWidgets(
      'TaskCard tick cancelled in the dialog completes nothing and '
      'animates nothing', (tester) async {
    var doneCount = 0;
    final task = TaskInstance(
      id: 7,
      homeId: 1,
      title: 'Test the smoke alarms',
      category: 'Safety',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      updatedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TaskCard(
              task: task,
              onTap: () {},
              onDone: (r) async => doneCount++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('Done. What did it cost?'), findsOneWidget);

    // Dismiss the dialog by its barrier: the card is exactly as
    // it was.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Done. What did it cost?'), findsNothing);
    expect(find.byType(AnimatedCheck), findsNothing);
    expect(find.byTooltip('Mark done'), findsOneWidget);
    expect(doneCount, 0);
  });
}
