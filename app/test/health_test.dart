import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/health.dart';
import 'package:nestkeep/models.dart';

TaskTemplate tpl(String id, {bool safety = false, int ignore = 100}) =>
    TaskTemplate(
      id: id,
      category: safety ? 'Safety' : 'HVAC',
      title: 'Job $id',
      frequencyMonths: 6,
      seasons: const [],
      diyCost: 10,
      ignoreCost: ignore,
      difficulty: 'Easy',
      minutes: 15,
      why: 'why',
      steps: const ['s'],
      needs: const ['n'],
    );

TaskInstance inst(TaskTemplate t, DateTime due, {TaskStatus status = TaskStatus.upcoming}) =>
    TaskInstance(
      homeId: 1,
      templateId: t.id,
      title: t.title,
      category: t.category,
      dueDate: due,
      status: status,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 11, 16);

  test('perfect home scores 100 / A', () {
    final t = tpl('a');
    final r = computeHealth([inst(t, now.add(const Duration(days: 60)))],
        {'a': t}, now);
    expect(r.score, 100);
    expect(r.grade, 'A');
    expect(r.overdueCount, 0);
  });

  test('overdue safety task costs at least 9 (8 + 1 week)', () {
    final t = tpl('s', safety: true);
    final r = computeHealth(
        [inst(t, now.subtract(const Duration(days: 3)))], {'s': t}, now);
    expect(r.score, 91);
    expect(r.statusSentence, contains('safety'));
  });

  test('overdue costly task uses the costly band', () {
    final t = tpl('c', ignore: 5000);
    final r = computeHealth(
        [inst(t, now.subtract(const Duration(days: 14)))], {'c': t}, now);
    // 5 + 2 weeks = 7
    expect(r.score, 93);
  });

  test('routine overdue task uses the light band and caps', () {
    final t = tpl('r', ignore: 50);
    final r = computeHealth(
        [inst(t, now.subtract(const Duration(days: 90)))], {'r': t}, now);
    // 3 + floor(13/2)=6 -> capped at 6
    expect(r.score, 94);
  });

  test('due soon deducts 1 each, capped at 5', () {
    final ts = [for (var i = 0; i < 8; i++) tpl('t$i')];
    final instances = [
      for (final t in ts) inst(t, now.add(const Duration(days: 5)))
    ];
    final r = computeHealth(instances, {for (final t in ts) t.id: t}, now);
    expect(r.score, 95);
    expect(r.dueSoonCount, 8);
  });

  test('completed tasks restore the score and count', () {
    final t = tpl('s', safety: true);
    final r = computeHealth(
      [inst(t, now.subtract(const Duration(days: 30)), status: TaskStatus.done)],
      {'s': t},
      now,
    );
    expect(r.score, 100);
    expect(r.completedCount, 1);
  });

  test('grade bands', () {
    expect(gradeFor(95), 'A');
    expect(gradeFor(85), 'B');
    expect(gradeFor(75), 'C');
    expect(gradeFor(65), 'D');
    expect(gradeFor(20), 'F');
  });

  test('streak counts consecutive weeks with completions', () {
    TaskInstance doneOn(DateTime d) => TaskInstance(
          homeId: 1,
          templateId: 'a',
          title: 'x',
          category: 'HVAC',
          dueDate: d,
          status: TaskStatus.done,
          doneDate: d,
          updatedAt: d,
        );
    // now is Mon 2026-11-16. Completions this week, last week, week before.
    final instances = [
      doneOn(DateTime(2026, 11, 16)),
      doneOn(DateTime(2026, 11, 10)),
      doneOn(DateTime(2026, 11, 3)),
    ];
    expect(computeStreakWeeks(instances, now), 3);
    expect(computeStreakWeeks([doneOn(DateTime(2026, 10, 1))], now), 0);
  });
}
