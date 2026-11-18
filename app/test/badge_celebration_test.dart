import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/badges.dart';
import 'package:nestkeep/widgets/badge_celebration.dart';

void main() {
  testWidgets('celebration shows the badge and dismisses via Nice',
      (tester) async {
    final badge =
        computeBadges(const BadgeTallies(doneCount: 1)).first;
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BadgeCelebrationOverlay(
          badge: badge,
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    // Let the badge spring in and the confetti get going.
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('BADGE EARNED'), findsOneWidget);
    expect(find.text('First job done'), findsOneWidget);
    expect(find.text('Your first job is in the books.'), findsOneWidget);

    await tester.tap(find.text('Nice'));
    expect(dismissed, isTrue);
  });
}
