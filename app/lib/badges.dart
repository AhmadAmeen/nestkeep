import 'package:flutter/material.dart';

/// Profile badges: small, honest milestones that make progress visible.
/// Computed from plain counts so the logic is testable without the
/// whole app state. Nothing here is bought or randomised; a badge is
/// earned by using the app, and the Pro member badge is simply the
/// marker of a subscription.
class BadgeResult {
  final IconData icon;
  final String label;
  final bool earned;

  /// Shown only while unearned and only when it adds information,
  /// e.g. "7 of 10".
  final String? progressLabel;
  final bool isProBadge;

  const BadgeResult({
    required this.icon,
    required this.label,
    required this.earned,
    this.progressLabel,
    this.isProBadge = false,
  });
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
      icon: Icons.eco_outlined,
      label: 'First job done',
      earned: doneCount >= 1,
    ),
    BadgeResult(
      icon: Icons.task_alt,
      label: '5 jobs done',
      earned: doneCount >= 5,
    ),
    BadgeResult(
      icon: Icons.military_tech_outlined,
      label: '10 jobs done',
      earned: doneCount >= 10,
      progressLabel: doneCount >= 10 ? null : of(doneCount, 10),
    ),
    BadgeResult(
      icon: Icons.document_scanner_outlined,
      label: 'First scan',
      earned: receiptsCount >= 1,
    ),
    BadgeResult(
      icon: Icons.kitchen_outlined,
      label: 'Appliances tracked',
      earned: appliancesCount >= 3,
      progressLabel: appliancesCount >= 3 ? null : of(appliancesCount, 3),
    ),
    BadgeResult(
      icon: Icons.local_fire_department,
      label: '4-week streak',
      earned: streakWeeks >= 4,
      progressLabel: streakWeeks >= 4 ? null : of(streakWeeks, 4),
    ),
    BadgeResult(
      icon: Icons.favorite_outline,
      label: 'Score A',
      earned: score >= 90,
      progressLabel: score >= 90 ? null : 'Now $score',
    ),
    BadgeResult(
      icon: Icons.workspace_premium_outlined,
      label: 'Pro member',
      earned: isPro,
      progressLabel: isPro ? null : 'Go Pro',
      isProBadge: true,
    ),
  ];
}
