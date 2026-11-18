import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestkeep/models.dart';
import 'package:nestkeep/screens/plan_calendar.dart';
import 'package:nestkeep/theme.dart';

TaskInstance _task({
  required DateTime due,
  TaskStatus status = TaskStatus.upcoming,
  DateTime? doneDate,
  String title = 'Job',
}) => TaskInstance(
  homeId: 1,
  title: title,
  category: 'Interior',
  dueDate: due,
  status: status,
  doneDate: doneDate,
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  final now = DateTime(2026, 11, 17, 10, 30);

  group('groupTasksByDay', () {
    test('open jobs land on their due day', () {
      final days = groupTasksByDay([
        _task(due: DateTime(2026, 11, 20), title: 'Later job'),
        _task(due: DateTime(2026, 11, 20, 18, 45), title: 'Same day job'),
        _task(due: DateTime(2026, 12, 1), title: 'December job'),
      ]);
      final day = days[DateTime(2026, 11, 20)]!;
      expect(day.upcoming.map((t) => t.title), ['Later job', 'Same day job']);
      expect(
        days[DateTime(2026, 12, 1)]!.upcoming.single.title,
        'December job',
      );
      expect(day.allDone, isFalse);
    });

    test('a past-due open job flags its day overdue; due today does not', () {
      final days = groupTasksByDay([
        _task(due: DateTime(2026, 11, 16)),
        _task(due: DateTime(2026, 11, 17)),
        _task(due: DateTime(2026, 11, 25)),
      ]);
      expect(days[DateTime(2026, 11, 16)]!.hasOverdue(now), isTrue);
      expect(days[DateTime(2026, 11, 17)]!.hasOverdue(now), isFalse);
      expect(days[DateTime(2026, 11, 25)]!.hasOverdue(now), isFalse);
    });

    test('done jobs land on the day they were done, not the due day', () {
      final days = groupTasksByDay([
        _task(
          due: DateTime(2026, 11, 1),
          status: TaskStatus.done,
          doneDate: DateTime(2026, 11, 10),
        ),
      ]);
      expect(days.containsKey(DateTime(2026, 11, 1)), isFalse);
      final day = days[DateTime(2026, 11, 10)]!;
      expect(day.done, hasLength(1));
      expect(day.allDone, isTrue);
      expect(day.hasOverdue(now), isFalse);
    });

    test('a done job with no done date falls back to its due day', () {
      final days = groupTasksByDay([
        _task(due: DateTime(2026, 11, 5), status: TaskStatus.done),
      ]);
      expect(days[DateTime(2026, 11, 5)]!.done, hasLength(1));
    });

    test('a day with open and done jobs is not all done', () {
      final days = groupTasksByDay([
        _task(due: DateTime(2026, 11, 17)),
        _task(
          due: DateTime(2026, 11, 17),
          status: TaskStatus.done,
          doneDate: DateTime(2026, 11, 17),
        ),
      ]);
      final day = days[DateTime(2026, 11, 17)]!;
      expect(day.upcoming, hasLength(1));
      expect(day.done, hasLength(1));
      expect(day.allDone, isFalse);
    });

    test('skipped jobs are not grouped', () {
      final days = groupTasksByDay([
        _task(due: DateTime(2026, 11, 17), status: TaskStatus.skipped),
      ]);
      expect(days, isEmpty);
    });
  });

  group('nextJobAfter', () {
    test('finds the first open job due after the day', () {
      final tasks = [
        _task(due: DateTime(2026, 11, 25), title: 'Second'),
        _task(due: DateTime(2026, 11, 20), title: 'First'),
        _task(
          due: DateTime(2026, 11, 19),
          status: TaskStatus.done,
          doneDate: DateTime(2026, 11, 19),
          title: 'Done one',
        ),
      ];
      expect(nextJobAfter(tasks, DateTime(2026, 11, 18))!.title, 'First');
      expect(nextJobAfter(tasks, DateTime(2026, 11, 21))!.title, 'Second');
    });

    test('falls back to the earliest open job, and null when none', () {
      final tasks = [_task(due: DateTime(2026, 11, 20), title: 'Only')];
      expect(nextJobAfter(tasks, DateTime(2026, 11, 28))!.title, 'Only');
      expect(nextJobAfter(const [], DateTime(2026, 11, 18)), isNull);
    });
  });

  testWidgets('calendar shows the month and today\'s jobs underneath', (
    tester,
  ) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        theme: nkLightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlanCalendarView(
              tasks: [_task(due: today, title: 'Due today job')],
              templateById: const {},
              onOpenTask: (_) {},
              onDone: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Due today job'), findsOneWidget);
    // The selected day starts on today, so its heading is up too.
    expect(find.text('Nothing due this day.'), findsNothing);
  });
}
