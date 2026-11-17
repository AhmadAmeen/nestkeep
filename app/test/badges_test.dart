import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/badges.dart';

void main() {
  group('computeBadges', () {
    test('a brand-new home has earned nothing, with honest progress', () {
      final badges = computeBadges(
        doneCount: 0,
        receiptsCount: 0,
        appliancesCount: 0,
        streakWeeks: 0,
        score: 0,
        isPro: false,
      );
      expect(badges.length, 8);
      expect(badges.every((b) => !b.earned), isTrue);
      final byLabel = {for (final b in badges) b.label: b};
      expect(byLabel['10 jobs done']!.progressLabel, '0 of 10');
      expect(byLabel['Appliances tracked']!.progressLabel, '0 of 3');
      expect(byLabel['4-week streak']!.progressLabel, '0 of 4');
      expect(byLabel['Score A']!.progressLabel, 'Now 0');
      expect(byLabel['Pro member']!.progressLabel, 'Go Pro');
      // Badges whose label already says the target carry no progress.
      expect(byLabel['First job done']!.progressLabel, isNull);
      expect(byLabel['5 jobs done']!.progressLabel, isNull);
      expect(byLabel['First scan']!.progressLabel, isNull);
    });

    test('job badges earn at 1, 5 and 10 and drop their progress', () {
      final badges = computeBadges(
        doneCount: 10,
        receiptsCount: 0,
        appliancesCount: 0,
        streakWeeks: 0,
        score: 0,
        isPro: false,
      );
      final byLabel = {for (final b in badges) b.label: b};
      expect(byLabel['First job done']!.earned, isTrue);
      expect(byLabel['5 jobs done']!.earned, isTrue);
      expect(byLabel['10 jobs done']!.earned, isTrue);
      expect(byLabel['10 jobs done']!.progressLabel, isNull);
    });

    test('progress counts clamp at the target', () {
      final badges = computeBadges(
        doneCount: 7,
        receiptsCount: 1,
        appliancesCount: 2,
        streakWeeks: 3,
        score: 89,
        isPro: false,
      );
      final byLabel = {for (final b in badges) b.label: b};
      expect(byLabel['10 jobs done']!.progressLabel, '7 of 10');
      expect(byLabel['First scan']!.earned, isTrue);
      expect(byLabel['Appliances tracked']!.progressLabel, '2 of 3');
      expect(byLabel['4-week streak']!.progressLabel, '3 of 4');
      expect(byLabel['Score A']!.earned, isFalse);
      expect(byLabel['Score A']!.progressLabel, 'Now 89');
    });

    test('every badge has a stable id and a celebration blurb', () {
      final badges = computeBadges(
        doneCount: 0,
        receiptsCount: 0,
        appliancesCount: 0,
        streakWeeks: 0,
        score: 0,
        isPro: false,
      );
      expect(badges.map((b) => b.id).toList(), badgeIdOrder);
      expect(badges.every((b) => b.blurb.isNotEmpty), isTrue);
    });
  });

  group('newlyEarned', () {
    test('returns earned minus celebrated, in definition order', () {
      expect(
        newlyEarned(
          ['pro_member', 'first_job', 'score_a'],
          ['score_a'],
        ),
        ['first_job', 'pro_member'],
      );
    });

    test('dedupes repeats in the earned list', () {
      expect(
        newlyEarned(['first_job', 'first_job', 'five_jobs'], const []),
        ['first_job', 'five_jobs'],
      );
    });

    test('is empty when nothing is new', () {
      expect(newlyEarned(['first_job'], ['first_job']), isEmpty);
      expect(newlyEarned(const [], const []), isEmpty);
      expect(newlyEarned(const [], ['first_job']), isEmpty);
    });

    test('unknown earned ids never celebrate', () {
      expect(newlyEarned(['not_a_badge'], const []), isEmpty);
    });
  });

  group('computeBadges thresholds', () {
    test('score A earns at 90 and the pro badge follows the plan', () {
      final pro = computeBadges(
        doneCount: 0,
        receiptsCount: 0,
        appliancesCount: 3,
        streakWeeks: 4,
        score: 90,
        isPro: true,
      );
      final byLabel = {for (final b in pro) b.label: b};
      expect(byLabel['Score A']!.earned, isTrue);
      expect(byLabel['Score A']!.progressLabel, isNull);
      expect(byLabel['Appliances tracked']!.earned, isTrue);
      expect(byLabel['4-week streak']!.earned, isTrue);
      expect(byLabel['Pro member']!.earned, isTrue);
      expect(byLabel['Pro member']!.progressLabel, isNull);
      expect(byLabel['Pro member']!.isProBadge, isTrue);
      expect(
        pro.where((b) => b.isProBadge).length,
        1,
        reason: 'only the Pro member badge opens the paywall',
      );
    });
  });
}
