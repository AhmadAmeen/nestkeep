import 'models.dart';

/// The Health Score formula — one function, fully transparent, unit-tested.
///
/// Start at 100 and deduct for work that is waiting:
///  - Overdue SAFETY task:        -8, plus -1 per week overdue (max -14 each)
///  - Overdue task whose cost of ignoring is $1,000+: -5, plus -1 per week
///    overdue (max -10 each)
///  - Any other overdue task:     -3, plus -1 per two weeks overdue (max -6)
///  - Task due within 14 days:    -1 each, at most -5 in total
/// Score is clamped to 0..100. Completing a task removes its deduction,
/// which is how the score recovers. Nothing else moves the number.
class HealthResult {
  final int score;
  final String grade; // A, B, C, D, F
  final String statusSentence;
  final int overdueCount;
  final int dueSoonCount;
  final int completedCount;

  const HealthResult({
    required this.score,
    required this.grade,
    required this.statusSentence,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.completedCount,
  });
}

String gradeFor(int score) {
  if (score >= 90) return 'A';
  if (score >= 80) return 'B';
  if (score >= 70) return 'C';
  if (score >= 60) return 'D';
  return 'F';
}

HealthResult computeHealth(
  List<TaskInstance> instances,
  Map<String, TaskTemplate> templates,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  var deduction = 0;
  var dueSoonDeduction = 0;
  var overdue = 0;
  var dueSoon = 0;
  var completed = 0;
  TaskInstance? topSafety;
  TaskInstance? topCostly;
  var topCostlyIgnore = -1;

  for (final t in instances) {
    if (t.status == TaskStatus.done) {
      completed++;
      continue;
    }
    if (t.status != TaskStatus.upcoming) continue;
    final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    final days = today.difference(due).inDays;
    final tpl = t.templateId == null ? null : templates[t.templateId];
    final isSafety = tpl?.isSafety ?? t.category == 'Safety';
    final ignore = tpl?.ignoreCost ?? 0;
    if (days > 0) {
      overdue++;
      final weeks = (days / 7).ceil();
      if (isSafety) {
        deduction += (8 + weeks).clamp(0, 14);
        topSafety ??= t;
      } else if (ignore >= 1000) {
        deduction += (5 + weeks).clamp(0, 10);
        if (ignore > topCostlyIgnore) {
          topCostlyIgnore = ignore;
          topCostly = t;
        }
      } else {
        deduction += (3 + (weeks / 2).floor()).clamp(0, 6);
        if (ignore > topCostlyIgnore) {
          topCostlyIgnore = ignore;
          topCostly = t;
        }
      }
    } else if (days >= -14) {
      dueSoon++;
      if (dueSoonDeduction < 5) dueSoonDeduction += 1;
    }
  }

  final score = (100 - deduction - dueSoonDeduction).clamp(0, 100);
  final String sentence;
  if (topSafety != null) {
    sentence = 'A safety check needs attention: ${topSafety.title}.';
  } else if (overdue > 0 && topCostly != null) {
    sentence = '$overdue ${overdue == 1 ? 'job is' : 'jobs are'} overdue. '
        'Start with ${topCostly.title}.';
  } else if (overdue > 0) {
    sentence = '$overdue ${overdue == 1 ? 'job is' : 'jobs are'} overdue.';
  } else if (dueSoon > 0) {
    sentence = 'Nothing overdue. $dueSoon ${dueSoon == 1 ? 'job' : 'jobs'} '
        'coming up in the next two weeks.';
  } else {
    sentence = 'Your home is in good shape. Nothing needs you right now.';
  }

  return HealthResult(
    score: score,
    grade: gradeFor(score),
    statusSentence: sentence,
    overdueCount: overdue,
    dueSoonCount: dueSoon,
    completedCount: completed,
  );
}

/// One category's slice of the health score: same deduction rules as
/// [computeHealth], applied to that category's jobs alone, plus the plain
/// reason the number is what it is.
class CategoryHealth {
  final String category;
  final int score;
  final String grade;
  final String reason;
  final int overdueCount;
  final int dueSoonCount;

  const CategoryHealth({
    required this.category,
    required this.score,
    required this.grade,
    required this.reason,
    required this.overdueCount,
    required this.dueSoonCount,
  });
}

List<CategoryHealth> computeHealthByCategory(
  List<TaskInstance> instances,
  Map<String, TaskTemplate> templates,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final byCategory = <String, List<TaskInstance>>{};
  for (final t in instances) {
    byCategory.putIfAbsent(t.category, () => []).add(t);
  }
  final results = <CategoryHealth>[];
  for (final entry in byCategory.entries) {
    var deduction = 0;
    var dueSoonDeduction = 0;
    var overdue = 0;
    var dueSoon = 0;
    var hasOverdueSafety = false;
    for (final t in entry.value) {
      if (t.status != TaskStatus.upcoming) continue;
      final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      final days = today.difference(due).inDays;
      final tpl = t.templateId == null ? null : templates[t.templateId];
      final isSafety = tpl?.isSafety ?? t.category == 'Safety';
      final ignore = tpl?.ignoreCost ?? 0;
      if (days > 0) {
        overdue++;
        if (isSafety) hasOverdueSafety = true;
        final weeks = (days / 7).ceil();
        if (isSafety) {
          deduction += (8 + weeks).clamp(0, 14);
        } else if (ignore >= 1000) {
          deduction += (5 + weeks).clamp(0, 10);
        } else {
          deduction += (3 + (weeks / 2).floor()).clamp(0, 6);
        }
      } else if (days >= -14) {
        dueSoon++;
        if (dueSoonDeduction < 5) dueSoonDeduction += 1;
      }
    }
    final score = (100 - deduction - dueSoonDeduction).clamp(0, 100);
    final String reason;
    if (overdue > 0 && hasOverdueSafety) {
      reason = '$overdue overdue, including a safety job';
    } else if (overdue > 0) {
      reason = '$overdue overdue';
    } else if (dueSoon > 0) {
      reason = '$dueSoon due in the next two weeks';
    } else {
      reason = 'All clear';
    }
    results.add(CategoryHealth(
      category: entry.key,
      score: score,
      grade: gradeFor(score),
      reason: reason,
      overdueCount: overdue,
      dueSoonCount: dueSoon,
    ));
  }
  results.sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    return byScore != 0 ? byScore : a.category.compareTo(b.category);
  });
  return results;
}

/// Streak = consecutive weeks, counting back from this week (or last week if
/// nothing is done yet this week), with at least one completed task each.
int computeStreakWeeks(List<TaskInstance> instances, DateTime now) {
  final doneWeeks = <int>{};
  for (final t in instances) {
    if (t.status == TaskStatus.done && t.doneDate != null) {
      doneWeeks.add(_weekKey(t.doneDate!));
    }
  }
  if (doneWeeks.isEmpty) return 0;
  var cursor = DateTime(now.year, now.month, now.day);
  // Move to Monday of this week.
  cursor = cursor.subtract(Duration(days: cursor.weekday - 1));
  if (!doneWeeks.contains(_weekKey(cursor))) {
    cursor = cursor.subtract(const Duration(days: 7));
    if (!doneWeeks.contains(_weekKey(cursor))) return 0;
  }
  var streak = 0;
  while (doneWeeks.contains(_weekKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return streak;
}

int _weekKey(DateTime d) {
  final monday = d.subtract(Duration(days: d.weekday - 1));
  return monday.year * 10000 + monday.month * 100 + monday.day;
}
