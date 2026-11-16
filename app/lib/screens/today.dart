import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// The Today screen: the approved front-page grid. One card per job,
/// generous spacing, nothing repeated.
class TodayScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onSeeAllPlan;
  final void Function(TaskInstance) onOpenTask;
  final Future<void> Function(TaskInstance) onQuickDone;

  const TodayScreen({
    super.key,
    required this.state,
    required this.onSeeAllPlan,
    required this.onOpenTask,
    required this.onQuickDone,
  });

  @override
  Widget build(BuildContext context) {
    final home = state.activeHome!;
    final health = state.health;
    final now = DateTime.now();
    final nextTasks = state.upcoming.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome home.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.navyText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    home.addressLine.isEmpty ? home.name : home.addressLine,
                    style: TextStyle(fontSize: 14, color: context.muted),
                  ),
                ],
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 27),
                  onPressed: onSeeAllPlan,
                ),
                if (state.overdue.isNotEmpty)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: NkColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${state.overdue.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 21,
              backgroundColor:
                  context.isDark ? NkColors.darkPrimary : NkColors.lightNavy,
              child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Health score + right column
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 55,
                child: NkCard(
                  child: Column(
                    children: [
                      HealthRing(score: health.score, grade: health.grade),
                      const SizedBox(height: 10),
                      Text(
                        health.statusSentence,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: context.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 45,
                child: Column(
                  children: [
                    Expanded(
                      child: NkCard(
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: NkColors.amber, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${state.streakWeeks} week${state.streakWeeks == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: context.navyText,
                                    ),
                                  ),
                                  Text('streak',
                                      style: TextStyle(
                                          fontSize: 13, color: context.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: NkCard(
                        child: Row(
                          children: [
                            Icon(Icons.savings_outlined,
                                color: context.isDark
                                    ? NkColors.darkPrimary
                                    : NkColors.lightPrimary,
                                size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    money(state.spentThisYear),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: context.navyText,
                                    ),
                                  ),
                                  Text(
                                    'spent this year',
                                    style: TextStyle(
                                        fontSize: 13, color: context.muted),
                                  ),
                                  Text(
                                    'typical ${money(state.typicalYearSpend)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: NkColors.amber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action needed / Completed pair
        Row(
          children: [
            Expanded(
              child: NkCard(
                onTap: onSeeAllPlan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: NkColors.red, size: 20),
                        const SizedBox(width: 6),
                        Text('Action needed',
                            style: TextStyle(
                                fontSize: 13.5, color: context.muted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${state.actionNeeded.length}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.navyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: NkColors.green, size: 20),
                        const SizedBox(width: 6),
                        Text('Completed',
                            style: TextStyle(
                                fontSize: 13.5, color: context.muted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${health.completedCount}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.navyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tip of the week
        NkCard(
          accentLeft: NkColors.amber,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: NkColors.amber, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tip of the week',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.navyText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tipOfTheWeek(now),
                      style: TextStyle(fontSize: 13.5, color: context.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        SectionHeading('Upcoming tasks',
            actionLabel: 'See all', onAction: onSeeAllPlan),
        const SizedBox(height: 10),
        if (nextTasks.isEmpty)
          NkCard(
            child: Text(
              'Nothing scheduled. Add a job from the Plan tab.',
              style: TextStyle(color: context.muted),
            ),
          ),
        for (final t in nextTasks) ...[
          TaskCard(task: t, onTap: () => onOpenTask(t), onDone: () => onQuickDone(t)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One task, one card: icon tile, title, due label, quick-done circle.
class TaskCard extends StatelessWidget {
  final TaskInstance task;
  final VoidCallback onTap;
  final VoidCallback onDone;

  const TaskCard(
      {super.key, required this.task, required this.onTap, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = task.isOverdue(now);
    final color = categoryColor(task.category);
    return NkCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(categoryIcon(task.category), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: context.navyText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dueLabel(task, now),
                  style: TextStyle(
                    fontSize: 13,
                    color: overdue ? NkColors.red : context.muted,
                    fontWeight: overdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 28),
            color: NkColors.green,
            tooltip: 'Mark done',
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}
