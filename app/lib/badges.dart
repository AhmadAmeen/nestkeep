import 'package:flutter/material.dart';

/// Profile badges: small, honest milestones that make progress visible.
/// Computed from plain counts so the logic is testable without the
/// whole app state. Nothing here is bought or randomised; a badge is
/// earned by using the app, and the Pro member badge is simply the
/// marker of a subscription.
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

/// Badge ids in definition order; celebrations fire in this order.
const badgeIdOrder = [
  'first_job',
  'five_jobs',
  'ten_jobs',
  'first_scan',
  'appliances_tracked',
  'four_week_streak',
  'score_a',
  'pro_member',
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

List<BadgeResult> computeBadges({
  required int doneCount,
  required int receiptsCount,
  required int appliancesCount,
  required int streakWeeks,
  required int score,
  required bool isPro,
}) {
  String of(int have, int target) =>
      '${have.clamp(0, target)} of $target';
  return [
    BadgeResult(
      id: 'first_job',
      icon: Icons.eco_outlined,
      label: 'First job done',
      earned: doneCount >= 1,
      blurb: 'Your first job is in the books.',
    ),
    BadgeResult(
      id: 'five_jobs',
      icon: Icons.task_alt,
      label: '5 jobs done',
      earned: doneCount >= 5,
      blurb: 'Five down. The house can feel it.',
    ),
    BadgeResult(
      id: 'ten_jobs',
      icon: Icons.military_tech_outlined,
      label: '10 jobs done',
      earned: doneCount >= 10,
      blurb: 'Ten jobs done. Proper keeper.',
      progressLabel: doneCount >= 10 ? null : of(doneCount, 10),
    ),
    BadgeResult(
      id: 'first_scan',
      icon: Icons.document_scanner_outlined,
      label: 'First scan',
      earned: receiptsCount >= 1,
      blurb: 'Receipt scanned and safely filed.',
    ),
    BadgeResult(
      id: 'appliances_tracked',
      icon: Icons.kitchen_outlined,
      label: 'Appliances tracked',
      earned: appliancesCount >= 3,
      blurb: 'Your appliances are on the record.',
      progressLabel: appliancesCount >= 3 ? null : of(appliancesCount, 3),
    ),
    BadgeResult(
      id: 'four_week_streak',
      icon: Icons.local_fire_department,
      label: '4-week streak',
      earned: streakWeeks >= 4,
      blurb: 'Four weeks in a row. That is a habit now.',
      progressLabel: streakWeeks >= 4 ? null : of(streakWeeks, 4),
    ),
    BadgeResult(
      id: 'score_a',
      icon: Icons.favorite_outline,
      label: 'Score A',
      earned: score >= 90,
      blurb: 'Grade A. This home is in top shape.',
      progressLabel: score >= 90 ? null : 'Now $score',
    ),
    BadgeResult(
      id: 'pro_member',
      icon: Icons.workspace_premium_outlined,
      label: 'Pro member',
      earned: isPro,
      blurb: 'Welcome to Pro. Everything is unlocked.',
      progressLabel: isPro ? null : 'Go Pro',
      isProBadge: true,
    ),
  ];
}
