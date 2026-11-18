import 'package:flutter/material.dart';

/// Profile badges: small, honest milestones that make progress visible.
/// Computed from plain tallies so the logic is testable without the
/// whole app state. Nothing here is bought or randomised; a badge is
/// earned by using the app, and the member badges are simply the
/// markers of a subscription. Every criterion is something the app
/// itself records (build 19 grew the shelf from 8 to 54, build 20
/// to 80).
class BadgeResult {
  /// Stable id, used to remember which badges have been celebrated.
  final String id;
  final IconData icon;
  final String label;
  final bool earned;

  /// One warm line shown in the celebration when the badge is earned.
  final String blurb;

  /// Shown only while unearned and only when it adds information,
  /// e.g. "7 of 10".
  final String? progressLabel;
  final bool isProBadge;

  const BadgeResult({
    required this.id,
    required this.icon,
    required this.label,
    required this.earned,
    required this.blurb,
    this.progressLabel,
    this.isProBadge = false,
  });
}

/// Everything the badge shelf is computed from, tallied by AppState
/// out of the records the app already keeps. A field only ever counts
/// something the app can point at: a finished job, a logged cost, a
/// filed document.
class BadgeTallies {
  final int doneCount;

  /// Finished on or before the day they were due.
  final int onTimeCount;

  /// Finished strictly before the day they were due.
  final int earlyCount;

  /// Finished after the day they were due (late, but finished).
  final int lateCount;

  /// Jobs the user marked skipped.
  final int skippedCount;

  /// The busiest single day: most completions sharing one done date.
  final int maxDoneInOneDay;

  /// Finished by the owner: doneBy empty or "Me" (the done dialog's
  /// own wording is "Me, or the pro's name").
  final int diyCount;

  /// Finished by someone else, i.e. a named pro.
  final int hiredProCount;

  /// Distinct job categories with at least one completion, out of the
  /// categories the library covers.
  final int categoriesDone;
  final int categoriesTotal;
  final int streakWeeks;
  final int score;
  final int expensesCount;
  final double totalSpent;
  final int receiptsCount;

  /// Receipts kept with their photo (imagePath set).
  final int receiptsWithPhoto;
  final int appliancesCount;
  final int appliancesWithPhoto;
  final int appliancesWithCondition;
  final int appliancesWithWarranty;
  final int docsCount;
  final int spacesCount;

  /// Jobs the user added themselves (no library template).
  final int customJobsCount;
  final int homesCount;
  final bool signedIn;
  final bool isPro;
  final bool isLifetime;

  const BadgeTallies({
    this.doneCount = 0,
    this.onTimeCount = 0,
    this.earlyCount = 0,
    this.lateCount = 0,
    this.skippedCount = 0,
    this.maxDoneInOneDay = 0,
    this.diyCount = 0,
    this.hiredProCount = 0,
    this.categoriesDone = 0,
    this.categoriesTotal = 0,
    this.streakWeeks = 0,
    this.score = 0,
    this.expensesCount = 0,
    this.totalSpent = 0,
    this.receiptsCount = 0,
    this.receiptsWithPhoto = 0,
    this.appliancesCount = 0,
    this.appliancesWithPhoto = 0,
    this.appliancesWithCondition = 0,
    this.appliancesWithWarranty = 0,
    this.docsCount = 0,
    this.spacesCount = 0,
    this.customJobsCount = 0,
    this.homesCount = 0,
    this.signedIn = false,
    this.isPro = false,
    this.isLifetime = false,
  });
}

/// Badge ids in definition order; celebrations fire in this order.
const badgeIdOrder = [
  'first_job',
  'five_jobs',
  'ten_jobs',
  'twentyfive_jobs',
  'fifty_jobs',
  'hundred_jobs',
  'two_hundred_jobs',
  'three_hundred_jobs',
  'five_hundred_jobs',
  'busy_day_3',
  'one_week_streak',
  'two_week_streak',
  'four_week_streak',
  'eight_week_streak',
  'twelve_week_streak',
  'twenty_six_week_streak',
  'fifty_two_week_streak',
  'score_80',
  'score_a',
  'score_95',
  'score_100',
  'on_time_first',
  'on_time_10',
  'on_time_25',
  'on_time_50',
  'early_10',
  'early_25',
  'comeback',
  'comeback_5',
  'on_time_100',
  'diy_first',
  'diy_10',
  'hired_pro',
  'diy_25',
  'hired_pro_5',
  'skipped_first',
  'categories_3',
  'categories_5',
  'categories_all',
  'first_appliance',
  'appliances_tracked',
  'appliances_5',
  'appliances_10',
  'appliance_photo',
  'appliance_condition',
  'appliance_warranty',
  'appliances_15',
  'appliances_20',
  'appliance_photos_5',
  'appliance_warranties_5',
  'all_conditioned',
  'first_expense',
  'expenses_10',
  'expenses_25',
  'spent_500',
  'spent_2000',
  'expenses_50',
  'spent_5000',
  'spent_10000',
  'first_scan',
  'scans_5',
  'scans_10',
  'scans_25',
  'scan_photo',
  'custom_job_first',
  'custom_jobs_5',
  'custom_jobs_10',
  'custom_jobs_25',
  'first_doc',
  'docs_5',
  'docs_10',
  'docs_25',
  'first_space',
  'spaces_3',
  'spaces_5',
  'second_home',
  'third_home',
  'signed_in',
  'pro_member',
  'lifetime_member',
];

/// The badges that have been earned but not yet celebrated: earned
/// minus celebrated, deduped, in badge-definition order.
List<String> newlyEarned(
  Iterable<String> earnedIds,
  Iterable<String> celebratedIds,
) {
  final earned = earnedIds.toSet();
  final celebrated = celebratedIds.toSet();
  return [
    for (final id in badgeIdOrder)
      if (earned.contains(id) && !celebrated.contains(id)) id,
  ];
}

List<BadgeResult> computeBadges(BadgeTallies t) {
  String of(int have, int target) => '${have.clamp(0, target)} of $target';
  BadgeResult milestone({
    required String id,
    required IconData icon,
    required String label,
    required String blurb,
    required int have,
    required int target,
    bool proBadge = false,
    String? unearnedProgress,
  }) {
    final earned = have >= target;
    return BadgeResult(
      id: id,
      icon: icon,
      label: label,
      earned: earned,
      blurb: blurb,
      // A one-step badge needs no counter; bigger milestones count up.
      progressLabel: earned
          ? null
          : (unearnedProgress ?? (target > 1 ? of(have, target) : null)),
      isProBadge: proBadge,
    );
  }

  return [
    // Jobs done.
    milestone(
      id: 'first_job',
      icon: Icons.eco_outlined,
      label: 'First job done',
      blurb: 'Your first job is in the books.',
      have: t.doneCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'five_jobs',
      icon: Icons.task_alt,
      label: '5 jobs done',
      blurb: 'Five down. The house can feel it.',
      have: t.doneCount,
      target: 5,
      unearnedProgress: null,
    ),
    milestone(
      id: 'ten_jobs',
      icon: Icons.military_tech_outlined,
      label: '10 jobs done',
      blurb: 'Ten jobs done. Proper keeper.',
      have: t.doneCount,
      target: 10,
    ),
    milestone(
      id: 'twentyfive_jobs',
      icon: Icons.emoji_events_outlined,
      label: '25 jobs done',
      blurb: 'Twenty-five jobs. This home is looked after.',
      have: t.doneCount,
      target: 25,
    ),
    milestone(
      id: 'fifty_jobs',
      icon: Icons.stars_outlined,
      label: '50 jobs done',
      blurb: 'Fifty jobs done. Serious keeping.',
      have: t.doneCount,
      target: 50,
    ),
    milestone(
      id: 'hundred_jobs',
      icon: Icons.diamond_outlined,
      label: '100 jobs done',
      blurb: 'One hundred jobs. A serious keeper.',
      have: t.doneCount,
      target: 100,
    ),
    milestone(
      id: 'two_hundred_jobs',
      icon: Icons.castle_outlined,
      label: '200 jobs done',
      blurb: 'Two hundred jobs. This home runs like a castle.',
      have: t.doneCount,
      target: 200,
    ),
    milestone(
      id: 'three_hundred_jobs',
      icon: Icons.castle_outlined,
      label: '300 jobs done',
      blurb: 'Three hundred jobs. This home is a fortress of upkeep.',
      have: t.doneCount,
      target: 300,
    ),
    milestone(
      id: 'five_hundred_jobs',
      icon: Icons.emoji_events,
      label: '500 jobs done',
      blurb: 'Five hundred jobs done. Legendary keeping.',
      have: t.doneCount,
      target: 500,
    ),
    milestone(
      id: 'busy_day_3',
      icon: Icons.bolt_outlined,
      label: 'Busy day',
      blurb: 'Three jobs done in a single day.',
      have: t.maxDoneInOneDay,
      target: 3,
    ),
    // Weekly streaks.
    milestone(
      id: 'one_week_streak',
      icon: Icons.local_fire_department_outlined,
      label: '1-week streak',
      blurb: 'One week on the board. The streak has started.',
      have: t.streakWeeks,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'two_week_streak',
      icon: Icons.local_fire_department_outlined,
      label: '2-week streak',
      blurb: 'Two weeks running. Momentum is building.',
      have: t.streakWeeks,
      target: 2,
    ),
    milestone(
      id: 'four_week_streak',
      icon: Icons.local_fire_department,
      label: '4-week streak',
      blurb: 'Four weeks in a row. That is a habit now.',
      have: t.streakWeeks,
      target: 4,
    ),
    milestone(
      id: 'eight_week_streak',
      icon: Icons.whatshot_outlined,
      label: '8-week streak',
      blurb: 'Eight weeks straight. Nothing is slipping.',
      have: t.streakWeeks,
      target: 8,
    ),
    milestone(
      id: 'twelve_week_streak',
      icon: Icons.whatshot_outlined,
      label: '12-week streak',
      blurb: 'Twelve weeks. A whole season of showing up.',
      have: t.streakWeeks,
      target: 12,
    ),
    milestone(
      id: 'twenty_six_week_streak',
      icon: Icons.whatshot,
      label: '26-week streak',
      blurb: 'Half a year of weeks, every one with a job done.',
      have: t.streakWeeks,
      target: 26,
    ),
    milestone(
      id: 'fifty_two_week_streak',
      icon: Icons.whatshot,
      label: '52-week streak',
      blurb: 'A full year of weeks. That is dedication.',
      have: t.streakWeeks,
      target: 52,
    ),
    // The health score.
    milestone(
      id: 'score_80',
      icon: Icons.trending_up,
      label: 'Score 80+',
      blurb: 'Past 80. The home is in good shape.',
      have: t.score,
      target: 80,
      unearnedProgress: 'Now ${t.score}',
    ),
    milestone(
      id: 'score_a',
      icon: Icons.favorite_outline,
      label: 'Score A',
      blurb: 'Grade A. This home is in top shape.',
      have: t.score,
      target: 90,
      unearnedProgress: 'Now ${t.score}',
    ),
    milestone(
      id: 'score_95',
      icon: Icons.favorite,
      label: 'Score 95+',
      blurb: 'Ninety-five. Nearly flawless.',
      have: t.score,
      target: 95,
      unearnedProgress: 'Now ${t.score}',
    ),
    milestone(
      id: 'score_100',
      icon: Icons.verified_outlined,
      label: 'Perfect score',
      blurb: 'A perfect 100. Nothing overdue, nothing looming.',
      have: t.score,
      target: 100,
      unearnedProgress: 'Now ${t.score}',
    ),
    // Finished on or before the due day.
    milestone(
      id: 'on_time_first',
      icon: Icons.schedule_outlined,
      label: 'On time',
      blurb: 'Finished before it was due. Ahead of the game.',
      have: t.onTimeCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'on_time_10',
      icon: Icons.schedule,
      label: '10 on time',
      blurb: 'Ten jobs beaten to the deadline.',
      have: t.onTimeCount,
      target: 10,
    ),
    milestone(
      id: 'on_time_25',
      icon: Icons.more_time_outlined,
      label: '25 on time',
      blurb: 'Twenty-five on time. This plan runs like clockwork.',
      have: t.onTimeCount,
      target: 25,
    ),
    milestone(
      id: 'on_time_50',
      icon: Icons.more_time,
      label: '50 on time',
      blurb: 'Fifty jobs done early or on the day. Remarkable.',
      have: t.onTimeCount,
      target: 50,
    ),
    milestone(
      id: 'early_10',
      icon: Icons.wb_sunny_outlined,
      label: 'Early bird',
      blurb: 'Ten jobs finished before they were even due.',
      have: t.earlyCount,
      target: 10,
    ),
    milestone(
      id: 'early_25',
      icon: Icons.wb_sunny,
      label: '25 early finishes',
      blurb: 'Twenty-five jobs beaten early. Ahead of everything.',
      have: t.earlyCount,
      target: 25,
    ),
    milestone(
      id: 'comeback',
      icon: Icons.history,
      label: 'Comeback',
      blurb: 'A job finished after its due day. Caught up, not given up.',
      have: t.lateCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'comeback_5',
      icon: Icons.restart_alt,
      label: '5 comebacks',
      blurb: 'Five late jobs pulled back. Nothing left hanging.',
      have: t.lateCount,
      target: 5,
    ),
    milestone(
      id: 'on_time_100',
      icon: Icons.more_time,
      label: '100 on time',
      blurb: 'One hundred jobs on time. The plan runs like clockwork.',
      have: t.onTimeCount,
      target: 100,
    ),
    // Who did the work.
    milestone(
      id: 'diy_first',
      icon: Icons.handyman_outlined,
      label: 'Did it myself',
      blurb: 'Rolled up your sleeves and did it yourself.',
      have: t.diyCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'diy_10',
      icon: Icons.construction_outlined,
      label: '10 DIY jobs',
      blurb: 'Ten jobs with your own hands. Money saved, skills earned.',
      have: t.diyCount,
      target: 10,
    ),
    milestone(
      id: 'hired_pro',
      icon: Icons.engineering_outlined,
      label: 'Hired a pro',
      blurb: 'You brought in a pro and it is on the record.',
      have: t.hiredProCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'diy_25',
      icon: Icons.construction,
      label: '25 DIY jobs',
      blurb: 'Twenty-five jobs by your own hand.',
      have: t.diyCount,
      target: 25,
    ),
    milestone(
      id: 'hired_pro_5',
      icon: Icons.engineering,
      label: '5 pro jobs',
      blurb: 'Five jobs handed to pros, all on the record.',
      have: t.hiredProCount,
      target: 5,
    ),
    milestone(
      id: 'skipped_first',
      icon: Icons.skip_next_outlined,
      label: 'Skipped wisely',
      blurb: 'Not every job needs doing. You called one off, and the '
          'record stays honest.',
      have: t.skippedCount,
      target: 1,
      unearnedProgress: null,
    ),
    // Coverage across the home's areas.
    milestone(
      id: 'categories_3',
      icon: Icons.grid_view_outlined,
      label: '3 areas covered',
      blurb: 'Jobs done in three different areas of the home.',
      have: t.categoriesDone,
      target: 3,
    ),
    milestone(
      id: 'categories_5',
      icon: Icons.grid_view,
      label: '5 areas covered',
      blurb: 'Five areas of the home have had attention.',
      have: t.categoriesDone,
      target: 5,
    ),
    BadgeResult(
      id: 'categories_all',
      icon: Icons.home_outlined,
      label: 'Whole home covered',
      earned: t.categoriesTotal > 0 && t.categoriesDone >= t.categoriesTotal,
      blurb: 'Every area of the home has had a job done.',
      progressLabel: t.categoriesTotal > 0 &&
              t.categoriesDone < t.categoriesTotal
          ? of(t.categoriesDone, t.categoriesTotal)
          : null,
    ),
    // Appliances.
    milestone(
      id: 'first_appliance',
      icon: Icons.kitchen_outlined,
      label: 'First appliance',
      blurb: 'Your first appliance is on the record.',
      have: t.appliancesCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'appliances_tracked',
      icon: Icons.kitchen,
      label: 'Appliances tracked',
      blurb: 'Your appliances are on the record.',
      have: t.appliancesCount,
      target: 3,
    ),
    milestone(
      id: 'appliances_5',
      icon: Icons.microwave_outlined,
      label: '5 appliances',
      blurb: 'Five appliances tracked, warranties and all.',
      have: t.appliancesCount,
      target: 5,
    ),
    milestone(
      id: 'appliances_10',
      icon: Icons.microwave,
      label: '10 appliances',
      blurb: 'Ten appliances on the record. A full house.',
      have: t.appliancesCount,
      target: 10,
    ),
    milestone(
      id: 'appliance_photo',
      icon: Icons.photo_camera_outlined,
      label: 'Appliance photo',
      blurb: 'A photo filed with an appliance. Proof, ready.',
      have: t.appliancesWithPhoto,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'appliance_condition',
      icon: Icons.health_and_safety_outlined,
      label: 'Condition checked',
      blurb: "You rated an appliance's condition yourself.",
      have: t.appliancesWithCondition,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'appliance_warranty',
      icon: Icons.shield_outlined,
      label: 'Warranty filed',
      blurb: 'An appliance with its warranty on record.',
      have: t.appliancesWithWarranty,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'appliances_15',
      icon: Icons.devices_outlined,
      label: '15 appliances',
      blurb: 'Fifteen appliances tracked.',
      have: t.appliancesCount,
      target: 15,
    ),
    milestone(
      id: 'appliances_20',
      icon: Icons.devices_other_outlined,
      label: '20 appliances',
      blurb: 'Twenty appliances on the record. Every machine '
          'accounted for.',
      have: t.appliancesCount,
      target: 20,
    ),
    milestone(
      id: 'appliance_photos_5',
      icon: Icons.photo_library_outlined,
      label: '5 appliance photos',
      blurb: 'Five appliances with their photos filed.',
      have: t.appliancesWithPhoto,
      target: 5,
    ),
    milestone(
      id: 'appliance_warranties_5',
      icon: Icons.shield,
      label: '5 warranties filed',
      blurb: 'Five appliances with their warranty on record.',
      have: t.appliancesWithWarranty,
      target: 5,
    ),
    BadgeResult(
      id: 'all_conditioned',
      icon: Icons.fact_check_outlined,
      label: 'All rated',
      earned: t.appliancesCount >= 3 &&
          t.appliancesWithCondition >= t.appliancesCount,
      blurb: 'Every appliance carries your own condition rating.',
      progressLabel: t.appliancesCount >= 3 &&
              t.appliancesWithCondition < t.appliancesCount
          ? '${t.appliancesWithCondition} of ${t.appliancesCount}'
          : null,
    ),
    // Money.
    milestone(
      id: 'first_expense',
      icon: Icons.receipt_long_outlined,
      label: 'First cost logged',
      blurb: 'The first cost is on the books.',
      have: t.expensesCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'expenses_10',
      icon: Icons.receipt_long,
      label: '10 costs logged',
      blurb: 'Ten costs logged. The money picture is forming.',
      have: t.expensesCount,
      target: 10,
    ),
    milestone(
      id: 'expenses_25',
      icon: Icons.request_quote_outlined,
      label: '25 costs logged',
      blurb: 'Twenty-five costs. Nothing slips through.',
      have: t.expensesCount,
      target: 25,
    ),
    BadgeResult(
      id: 'spent_500',
      icon: Icons.savings_outlined,
      label: '\$500 tracked',
      earned: t.totalSpent >= 500,
      blurb: 'Five hundred dollars of home costs, all accounted for.',
      progressLabel:
          t.totalSpent >= 500 ? null : '\$${t.totalSpent.floor()} of \$500',
    ),
    BadgeResult(
      id: 'spent_2000',
      icon: Icons.account_balance_outlined,
      label: '\$2,000 tracked',
      earned: t.totalSpent >= 2000,
      blurb: 'Two thousand dollars tracked. You know what this home costs.',
      progressLabel: t.totalSpent >= 2000
          ? null
          : '\$${t.totalSpent.floor()} of \$2,000',
    ),
    milestone(
      id: 'expenses_50',
      icon: Icons.request_quote,
      label: '50 costs logged',
      blurb: 'Fifty costs logged. The books are thorough.',
      have: t.expensesCount,
      target: 50,
    ),
    BadgeResult(
      id: 'spent_5000',
      icon: Icons.account_balance,
      label: '\$5,000 tracked',
      earned: t.totalSpent >= 5000,
      blurb: 'Five thousand dollars of home costs, all accounted for.',
      progressLabel: t.totalSpent >= 5000
          ? null
          : '\$${t.totalSpent.floor()} of \$5,000',
    ),
    BadgeResult(
      id: 'spent_10000',
      icon: Icons.savings,
      label: '\$10,000 tracked',
      earned: t.totalSpent >= 10000,
      blurb: 'Ten thousand dollars tracked. Few owners know their '
          'home this well.',
      progressLabel: t.totalSpent >= 10000
          ? null
          : '\$${t.totalSpent.floor()} of \$10,000',
    ),
    // Receipt scans.
    milestone(
      id: 'first_scan',
      icon: Icons.document_scanner_outlined,
      label: 'First scan',
      blurb: 'Receipt scanned and safely filed.',
      have: t.receiptsCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'scans_5',
      icon: Icons.document_scanner,
      label: '5 scans',
      blurb: 'Five receipts scanned. The shoebox is retiring.',
      have: t.receiptsCount,
      target: 5,
    ),
    milestone(
      id: 'scans_10',
      icon: Icons.qr_code_scanner_outlined,
      label: '10 scans',
      blurb: 'Ten receipts scanned and filed.',
      have: t.receiptsCount,
      target: 10,
    ),
    milestone(
      id: 'scans_25',
      icon: Icons.qr_code_scanner,
      label: '25 scans',
      blurb: 'Twenty-five receipts scanned and filed.',
      have: t.receiptsCount,
      target: 25,
    ),
    milestone(
      id: 'scan_photo',
      icon: Icons.add_a_photo_outlined,
      label: 'Photo proof',
      blurb: 'A receipt kept with its photo, ready for a claim.',
      have: t.receiptsWithPhoto,
      target: 1,
      unearnedProgress: null,
    ),
    // Jobs the user added themselves.
    milestone(
      id: 'custom_job_first',
      icon: Icons.add_task,
      label: 'My own job',
      blurb: 'You added a job of your own to the plan.',
      have: t.customJobsCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'custom_jobs_5',
      icon: Icons.playlist_add_check_outlined,
      label: '5 own jobs',
      blurb: 'Five of your own jobs on the plan.',
      have: t.customJobsCount,
      target: 5,
    ),
    milestone(
      id: 'custom_jobs_10',
      icon: Icons.playlist_add_check,
      label: '10 own jobs',
      blurb: 'Ten own jobs. The plan is truly yours now.',
      have: t.customJobsCount,
      target: 10,
    ),
    milestone(
      id: 'custom_jobs_25',
      icon: Icons.playlist_add_check,
      label: '25 own jobs',
      blurb: 'Twenty-five of your own jobs. The plan is fully yours.',
      have: t.customJobsCount,
      target: 25,
    ),
    // Documents and spaces.
    milestone(
      id: 'first_doc',
      icon: Icons.folder_outlined,
      label: 'First document',
      blurb: "The home's first paper is filed.",
      have: t.docsCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'docs_5',
      icon: Icons.folder,
      label: '5 documents',
      blurb: 'Five documents filed. Deeds, insurance, manuals, safe.',
      have: t.docsCount,
      target: 5,
    ),
    milestone(
      id: 'docs_10',
      icon: Icons.folder_copy_outlined,
      label: '10 documents',
      blurb: 'Ten documents in the vault.',
      have: t.docsCount,
      target: 10,
    ),
    milestone(
      id: 'docs_25',
      icon: Icons.folder_copy,
      label: '25 documents',
      blurb: 'Twenty-five documents in the vault.',
      have: t.docsCount,
      target: 25,
    ),
    milestone(
      id: 'first_space',
      icon: Icons.meeting_room_outlined,
      label: 'First space',
      blurb: 'You named a space in the home and started filing by it.',
      have: t.spacesCount,
      target: 1,
      unearnedProgress: null,
    ),
    milestone(
      id: 'spaces_3',
      icon: Icons.widgets_outlined,
      label: '3 spaces',
      blurb: 'Three named spaces, each with its own papers.',
      have: t.spacesCount,
      target: 3,
    ),
    milestone(
      id: 'spaces_5',
      icon: Icons.widgets,
      label: '5 spaces',
      blurb: 'Five spaces. The whole home, organised.',
      have: t.spacesCount,
      target: 5,
    ),
    // Homes and account.
    milestone(
      id: 'second_home',
      icon: Icons.holiday_village_outlined,
      label: 'Second home',
      blurb: 'A second home, kept in the same place.',
      have: t.homesCount,
      target: 2,
    ),
    milestone(
      id: 'third_home',
      icon: Icons.holiday_village,
      label: 'Three homes',
      blurb: 'Three homes, all kept in one place.',
      have: t.homesCount,
      target: 3,
    ),
    BadgeResult(
      id: 'signed_in',
      icon: Icons.cloud_done_outlined,
      label: 'Backed up',
      earned: t.signedIn,
      blurb: 'Signed in. Your home is backed up and follows you.',
    ),
    BadgeResult(
      id: 'pro_member',
      icon: Icons.workspace_premium_outlined,
      label: 'Pro member',
      earned: t.isPro,
      blurb: 'Welcome to Pro. Everything is unlocked.',
      progressLabel: t.isPro ? null : 'Go Pro',
      isProBadge: true,
    ),
    BadgeResult(
      id: 'lifetime_member',
      icon: Icons.all_inclusive_outlined,
      label: 'Lifetime member',
      earned: t.isLifetime,
      blurb: 'Lifetime. Yours for good.',
      isProBadge: true,
    ),
  ];
}
