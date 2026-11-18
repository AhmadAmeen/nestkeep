import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/badges.dart';

Map<String, BadgeResult> _byId(List<BadgeResult> badges) =>
    {for (final b in badges) b.id: b};

void main() {
  group('computeBadges', () {
    test('the shelf holds at least 50 badges, ids in definition order', () {
      final badges = computeBadges(const BadgeTallies());
      expect(badges.length, greaterThanOrEqualTo(50));
      expect(badges.map((b) => b.id).toList(), badgeIdOrder);
      expect(badges.map((b) => b.id).toSet().length, badges.length,
          reason: 'badge ids are unique');
      expect(badges.every((b) => b.blurb.isNotEmpty), isTrue);
      expect(badges.every((b) => b.label.isNotEmpty), isTrue);
    });

    test('a brand-new home has earned nothing, with honest progress', () {
      final badges = computeBadges(const BadgeTallies());
      expect(badges.every((b) => !b.earned), isTrue);
      final byId = _byId(badges);
      expect(byId['ten_jobs']!.progressLabel, '0 of 10');
      expect(byId['appliances_tracked']!.progressLabel, '0 of 3');
      expect(byId['four_week_streak']!.progressLabel, '0 of 4');
      expect(byId['score_a']!.progressLabel, 'Now 0');
      expect(byId['pro_member']!.progressLabel, 'Go Pro');
      // One-step badges carry no counter.
      expect(byId['first_job']!.progressLabel, isNull);
      expect(byId['first_scan']!.progressLabel, isNull);
      expect(byId['signed_in']!.progressLabel, isNull);
    });

    test('job badges earn at their milestones and drop their progress', () {
      final byId = _byId(computeBadges(const BadgeTallies(doneCount: 25)));
      expect(byId['first_job']!.earned, isTrue);
      expect(byId['five_jobs']!.earned, isTrue);
      expect(byId['ten_jobs']!.earned, isTrue);
      expect(byId['ten_jobs']!.progressLabel, isNull);
      expect(byId['twentyfive_jobs']!.earned, isTrue);
      expect(byId['fifty_jobs']!.earned, isFalse);
      expect(byId['fifty_jobs']!.progressLabel, '25 of 50');
    });

    test('progress counts clamp at the target', () {
      final byId = _byId(computeBadges(const BadgeTallies(
        doneCount: 7,
        receiptsCount: 1,
        appliancesCount: 2,
        streakWeeks: 3,
        score: 89,
      )));
      expect(byId['ten_jobs']!.progressLabel, '7 of 10');
      expect(byId['first_scan']!.earned, isTrue);
      expect(byId['appliances_tracked']!.progressLabel, '2 of 3');
      expect(byId['four_week_streak']!.progressLabel, '3 of 4');
      expect(byId['score_a']!.earned, isFalse);
      expect(byId['score_a']!.progressLabel, 'Now 89');
    });

    test('streak and score families earn at their rungs', () {
      final byId = _byId(computeBadges(
          const BadgeTallies(streakWeeks: 12, score: 95)));
      expect(byId['one_week_streak']!.earned, isTrue);
      expect(byId['eight_week_streak']!.earned, isTrue);
      expect(byId['twelve_week_streak']!.earned, isTrue);
      expect(byId['twenty_six_week_streak']!.earned, isFalse);
      expect(byId['score_80']!.earned, isTrue);
      expect(byId['score_a']!.earned, isTrue);
      expect(byId['score_95']!.earned, isTrue);
      expect(byId['score_100']!.earned, isFalse);
    });

    test('on-time, DIY and hired-pro tallies drive their badges', () {
      final byId = _byId(computeBadges(const BadgeTallies(
        onTimeCount: 10,
        diyCount: 1,
        hiredProCount: 1,
      )));
      expect(byId['on_time_first']!.earned, isTrue);
      expect(byId['on_time_10']!.earned, isTrue);
      expect(byId['on_time_25']!.earned, isFalse);
      expect(byId['diy_first']!.earned, isTrue);
      expect(byId['diy_10']!.earned, isFalse);
      expect(byId['hired_pro']!.earned, isTrue);
    });

    test('category coverage needs every library category for the top badge',
        () {
      final partial = _byId(computeBadges(
          const BadgeTallies(categoriesDone: 5, categoriesTotal: 8)));
      expect(partial['categories_3']!.earned, isTrue);
      expect(partial['categories_5']!.earned, isTrue);
      expect(partial['categories_all']!.earned, isFalse);
      expect(partial['categories_all']!.progressLabel, '5 of 8');
      final full = _byId(computeBadges(
          const BadgeTallies(categoriesDone: 8, categoriesTotal: 8)));
      expect(full['categories_all']!.earned, isTrue);
      // No library loaded (total 0) can never earn it.
      final none = _byId(computeBadges(const BadgeTallies()));
      expect(none['categories_all']!.earned, isFalse);
    });

    test('appliance extras: photo, condition and warranty are separate', () {
      final byId = _byId(computeBadges(const BadgeTallies(
        appliancesCount: 5,
        appliancesWithPhoto: 1,
        appliancesWithWarranty: 2,
      )));
      expect(byId['first_appliance']!.earned, isTrue);
      expect(byId['appliances_5']!.earned, isTrue);
      expect(byId['appliances_10']!.earned, isFalse);
      expect(byId['appliance_photo']!.earned, isTrue);
      expect(byId['appliance_condition']!.earned, isFalse);
      expect(byId['appliance_warranty']!.earned, isTrue);
    });

    test('money badges follow expense counts and tracked spend', () {
      final byId = _byId(computeBadges(const BadgeTallies(
        expensesCount: 10,
        totalSpent: 750,
      )));
      expect(byId['first_expense']!.earned, isTrue);
      expect(byId['expenses_10']!.earned, isTrue);
      expect(byId['expenses_25']!.earned, isFalse);
      expect(byId['spent_500']!.earned, isTrue);
      expect(byId['spent_2000']!.earned, isFalse);
      expect(byId['spent_2000']!.progressLabel, '\$750 of \$2,000');
    });

    test('scans, own jobs, documents, spaces, homes and account', () {
      final byId = _byId(computeBadges(const BadgeTallies(
        receiptsCount: 5,
        customJobsCount: 5,
        docsCount: 5,
        spacesCount: 1,
        homesCount: 2,
        signedIn: true,
      )));
      expect(byId['scans_5']!.earned, isTrue);
      expect(byId['scans_10']!.earned, isFalse);
      expect(byId['custom_job_first']!.earned, isTrue);
      expect(byId['custom_jobs_5']!.earned, isTrue);
      expect(byId['first_doc']!.earned, isTrue);
      expect(byId['docs_5']!.earned, isTrue);
      expect(byId['docs_10']!.earned, isFalse);
      expect(byId['first_space']!.earned, isTrue);
      expect(byId['second_home']!.earned, isTrue);
      expect(byId['signed_in']!.earned, isTrue);
    });

    test('the member badges follow the plan, lifetime included', () {
      final free = _byId(computeBadges(const BadgeTallies()));
      expect(free['pro_member']!.earned, isFalse);
      expect(free['pro_member']!.isProBadge, isTrue);
      expect(free['lifetime_member']!.earned, isFalse);
      final life = _byId(computeBadges(
          const BadgeTallies(isPro: true, isLifetime: true)));
      expect(life['pro_member']!.earned, isTrue);
      expect(life['pro_member']!.progressLabel, isNull);
      expect(life['lifetime_member']!.earned, isTrue);
      expect(life['lifetime_member']!.isProBadge, isTrue);
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
}
