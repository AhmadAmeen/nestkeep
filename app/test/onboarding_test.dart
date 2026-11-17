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
  testWidgets('wizard steps through to the plan summary', (tester) async {
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

    // Forward to the summary: live counts from the default answers
    // (2 of 3 templates apply; the pool job is left out).
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 6 of 6'), findsOneWidget);
    expect(find.text('Your plan is ready'), findsOneWidget);
    expect(find.text('2 jobs'), findsOneWidget);
    expect(
      find.text('1 left out because they do not apply to your home.'),
      findsOneWidget,
    );
    expect(find.text('Build my plan'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });
}
