import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/badges.dart';

Map<String, BadgeResult> _byId(List<BadgeResult> badges) =>
    {for (final b in badges) b.id: b};

void main() {
  group('computeBadges', () {
    test('the shelf holds exactly 80 badges, ids in definition order', () {
      final badges = computeBadges(const BadgeTallies());
      expect(badges.length, 80);
      expect(badgeIdOrder.length, 80);
      expect(badges.map((b) => b.id).toList(), badgeIdOrder);
      expect(badges.map((b) => b.id).toSet().length, badges.length,
          reason: 'badge ids are unique');
      expect(badges.every((b) => b.blurb.isNotEmpty), isTrue);
      expect(badges.every((b) => b.label.isNotEmpty), isTrue);
    });

    test('the original 54 ids survive, in their original order', () {
      // Celebration history is keyed by id, so build 20's 26
      // additions must never rename, drop or reorder the old shelf.
      const original54 = [
        'first_job', 'five_jobs', 'ten_jobs', 'twentyfive_jobs',
        'fifty_jobs', 'hundred_jobs', 'two_hundred_jobs', //
        'one_week_streak', 'two_week_streak', 'four_week_streak',
        'eight_week_streak', 'twelve_week_streak',
        'twenty_six_week_streak', 'fifty_two_week_streak', //
        'score_80', 'score_a', 'score_95', 'score_100', //
        'on_time_first', 'on_time_10', 'on_time_25', 'on_time_50', //
        'diy_first', 'diy_10', 'hired_pro', //
        'categories_3', 'categories_5', 'categories_all', //
        'first_appliance', 'appliances_tracked', 'appliances_5',
        'appliances_10', 'appliance_photo', 'appliance_condition',
        'appliance_warranty', //
        'first_expense', 'expenses_10', 'expenses_25', //
        'spent_500', 'spent_2000', //
        'first_scan', 'scans_5', 'scans_10', //
        'custom_job_first', 'custom_jobs_5', 'custom_jobs_10', //
        'first_doc', 'docs_5', 'docs_10', //
        'first_space', //
        'second_home', //
        'signed_in', 'pro_member', 'lifetime_member',
      ];
      expect(original54.length, 54);
      expect(badgeIdOrder.where(original54.contains).toList(), original54);
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

    group('build 20 additions earn at their thresholds', () {
      test('the long-haul job counts', () {
        final at299 = _byId(computeBadges(const BadgeTallies(doneCount: 299)));
        expect(at299['three_hundred_jobs']!.earned, isFalse);
        expect(at299['three_hundred_jobs']!.progressLabel, '299 of 300');
        final at500 = _byId(computeBadges(const BadgeTallies(doneCount: 500)));
        expect(at500['three_hundred_jobs']!.earned, isTrue);
        expect(at500['five_hundred_jobs']!.earned, isTrue);
      });

      test('busy day, early birds and comebacks read the new tallies', () {
        final byId = _byId(computeBadges(const BadgeTallies(
          maxDoneInOneDay: 2,
          earlyCount: 9,
          lateCount: 0,
          skippedCount: 0,
        )));
        expect(byId['busy_day_3']!.earned, isFalse);
        expect(byId['early_10']!.earned, isFalse);
        expect(byId['early_10']!.progressLabel, '9 of 10');
        expect(byId['comeback']!.earned, isFalse);
        expect(byId['skipped_first']!.earned, isFalse);
        final earned = _byId(computeBadges(const BadgeTallies(
          maxDoneInOneDay: 3,
          earlyCount: 25,
          lateCount: 5,
          skippedCount: 1,
        )));
        expect(earned['busy_day_3']!.earned, isTrue);
        expect(earned['early_10']!.earned, isTrue);
        expect(earned['early_25']!.earned, isTrue);
        expect(earned['comeback']!.earned, isTrue);
        expect(earned['comeback_5']!.earned, isTrue);
        expect(earned['skipped_first']!.earned, isTrue);
      });

      test('on-time century, DIY 25 and five pros hired', () {
        final byId = _byId(computeBadges(const BadgeTallies(
          onTimeCount: 99,
          diyCount: 24,
          hiredProCount: 4,
        )));
        expect(byId['on_time_100']!.earned, isFalse);
        expect(byId['diy_25']!.earned, isFalse);
        expect(byId['hired_pro_5']!.earned, isFalse);
        final earned = _byId(computeBadges(const BadgeTallies(
          onTimeCount: 100,
          diyCount: 25,
          hiredProCount: 5,
        )));
        expect(earned['on_time_100']!.earned, isTrue);
        expect(earned['diy_25']!.earned, isTrue);
        expect(earned['hired_pro_5']!.earned, isTrue);
      });

      test('the bigger appliance shelf', () {
        final byId = _byId(computeBadges(const BadgeTallies(
          appliancesCount: 14,
          appliancesWithPhoto: 4,
          appliancesWithWarranty: 4,
          appliancesWithCondition: 2,
        )));
        expect(byId['appliances_15']!.earned, isFalse);
        expect(byId['appliance_photos_5']!.earned, isFalse);
        expect(byId['appliance_warranties_5']!.earned, isFalse);
        expect(byId['all_conditioned']!.earned, isFalse,
            reason: 'fewer than 3 appliances never counts');
        final earned = _byId(computeBadges(const BadgeTallies(
          appliancesCount: 20,
          appliancesWithPhoto: 5,
          appliancesWithWarranty: 5,
          appliancesWithCondition: 20,
        )));
        expect(earned['appliances_15']!.earned, isTrue);
        expect(earned['appliances_20']!.earned, isTrue);
        expect(earned['appliance_photos_5']!.earned, isTrue);
        expect(earned['appliance_warranties_5']!.earned, isTrue);
        expect(earned['all_conditioned']!.earned, isTrue);
        final partial = _byId(computeBadges(const BadgeTallies(
          appliancesCount: 4,
          appliancesWithCondition: 3,
        )));
        expect(partial['all_conditioned']!.earned, isFalse,
            reason: 'one unrated appliance breaks it');
        expect(partial['all_conditioned']!.progressLabel, '3 of 4');
      });

      test('money and paper milestones', () {
        final byId = _byId(computeBadges(const BadgeTallies(
          expensesCount: 49,
          totalSpent: 4999,
          receiptsCount: 24,
          customJobsCount: 24,
          docsCount: 24,
          spacesCount: 2,
          homesCount: 2,
        )));
        expect(byId['expenses_50']!.earned, isFalse);
        expect(byId['spent_5000']!.earned, isFalse);
        expect(byId['scans_25']!.earned, isFalse);
        expect(byId['scan_photo']!.earned, isFalse);
        expect(byId['custom_jobs_25']!.earned, isFalse);
        expect(byId['docs_25']!.earned, isFalse);
        expect(byId['spaces_3']!.earned, isFalse);
        expect(byId['third_home']!.earned, isFalse);
        final earned = _byId(computeBadges(const BadgeTallies(
          expensesCount: 50,
          totalSpent: 10000,
          receiptsCount: 25,
          receiptsWithPhoto: 1,
          customJobsCount: 25,
          docsCount: 25,
          spacesCount: 5,
          homesCount: 3,
        )));
        expect(earned['expenses_50']!.earned, isTrue);
        expect(earned['spent_5000']!.earned, isTrue);
        expect(earned['spent_10000']!.earned, isTrue);
        expect(earned['scans_25']!.earned, isTrue);
        expect(earned['scan_photo']!.earned, isTrue);
        expect(earned['custom_jobs_25']!.earned, isTrue);
        expect(earned['docs_25']!.earned, isTrue);
        expect(earned['spaces_3']!.earned, isTrue);
        expect(earned['spaces_5']!.earned, isTrue);
        expect(earned['third_home']!.earned, isTrue);
      });
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
