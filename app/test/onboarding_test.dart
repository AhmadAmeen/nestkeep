import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/app_state.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/onboarding.dart';
import 'package:nestkeep/theme.dart';

TaskTemplate tpl(String id, {List<String> req = const []}) => TaskTemplate(
      id: id,
      category: 'HVAC',
      title: id,
      frequencyMonths: 12,
      seasons: const [],
      diyCost: 10,
      ignoreCost: 100,
      difficulty: 'Easy',
      minutes: 10,
      why: 'why',
      steps: const ['step'],
      needs: const [],
      requiresAny: req,
    );

void main() {
  testWidgets('wizard steps through to the job picker', (tester) async {
    final state = AppState();
    state.templates = [
      tpl('hvac-filter'),
      tpl('safety-smoke-test'),
      tpl('pool-filter', req: ['pool']),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: OnboardingScreen(state: state, onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: headline, progress label, Next but no Back.
    expect(find.text('Step 1 of 6'), findsOneWidget);
    expect(find.text('Welcome home.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    // Walk forward: type, heating/cooling, climate, features.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Step 5 of 6'), findsOneWidget);
    expect(find.text('What does it have?'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    // Back keeps the answers and returns to the climate step.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 4 of 6'), findsOneWidget);
    expect(find.text('Winters where you live?'), findsOneWidget);

    // Forward past the features step: the "Finding jobs for you"
    // loader plays first (not a numbered step), then the picker.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Finding jobs for you'), findsOneWidget);
    expect(find.text('Looking at your home\'s systems'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pumpAndSettle();

    // The job picker: the jobs that fit the default answers come
    // pre-ticked (2 of 3; the pool job waits unticked), and nothing
    // enters the plan until the user builds it from their ticks.
    expect(find.text('Step 6 of 6'), findsOneWidget);
    expect(find.text('Choose your jobs'), findsOneWidget);
    expect(
      find.text(
          'Tick the jobs you want in your plan. Tap a job to see its steps.'),
      findsOneWidget,
    );
    expect(find.text('2 of 3 on'), findsOneWidget);
    expect(find.text('Build my plan · 2 jobs'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    // Groups start collapsed to their heading: no job rows yet, just
    // the hint line. Tapping the heading opens the group.
    expect(find.text('Tap to see sub tasks'), findsOneWidget);
    expect(find.text('hvac-filter'), findsNothing);
    await tester.tap(find.text('HVAC'));
    await tester.pumpAndSettle();
    expect(find.text('hvac-filter'), findsOneWidget);

    // Tapping a job row expands its steps as the subtask list.
    await tester.tap(find.text('hvac-filter'));
    await tester.pumpAndSettle();
    expect(find.text('why'), findsOneWidget);
    expect(find.text('step'), findsOneWidget);

    // Unticking a pre-ticked job drops it from the build count.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 on'), findsOneWidget);
    expect(find.text('Build my plan · 1 jobs'), findsOneWidget);
  });
}
