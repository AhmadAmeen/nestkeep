import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/screens/finding_jobs.dart';
import 'package:nestkeep/theme.dart';

void main() {
  testWidgets('staged lines tick in one by one, then onDone fires once',
      (tester) async {
    var doneCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(body: FindingJobsView(onDone: () => doneCalls++)),
      ),
    );
    await tester.pump();

    expect(find.text('Finding jobs for you'), findsOneWidget);
    expect(find.text('Looking at your home\'s systems'), findsOneWidget);
    expect(find.text('Matching jobs to your home'), findsOneWidget);
    expect(find.text('Estimating times and costs'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(doneCalls, 0);

    // The first line ticks in after about a second.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(doneCalls, 0);

    // By the total duration every line has ticked and onDone has fired.
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    expect(doneCalls, 1);
  });

  testWidgets('leaving early cancels the timers', (tester) async {
    var doneCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(body: FindingJobsView(onDone: () => doneCalls++)),
      ),
    );
    await tester.pump();

    // Unmount well before the sequence finishes: no late onDone, no
    // setState-after-dispose errors.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(doneCalls, 0);
  });
}
