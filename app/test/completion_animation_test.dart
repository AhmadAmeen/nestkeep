import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/today.dart';
import 'package:nestkeep/theme.dart';
import 'package:nestkeep/widgets/animated_check.dart';

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
      'TaskCard plays the tick, glides away, then fires onDone once',
      (tester) async {
    var doneCount = 0;
    var tapCount = 0;
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
              onDone: () => doneCount++,
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Mark done'), findsOneWidget);
    expect(find.byType(AnimatedCheck), findsNothing);

    await tester.tap(find.byTooltip('Mark done'));
    await tester.pump();
    // The button became the drawing tick; nothing has completed yet,
    // and the card no longer opens the guide while it plays.
    expect(find.byType(AnimatedCheck), findsOneWidget);
    expect(find.byTooltip('Mark done'), findsNothing);
    expect(doneCount, 0);
    await tester.tap(find.text('Test the smoke alarms'));
    await tester.pump();
    expect(tapCount, 0);

    // Tick finishes (450ms): the collapse starts, but the real
    // completion still has not fired.
    await tester.pump(const Duration(milliseconds: 500));
    expect(doneCount, 0);

    // Collapse finishes (300ms): onDone fires exactly once.
    await tester.pump(const Duration(milliseconds: 350));
    expect(doneCount, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(doneCount, 1);
  });
}
