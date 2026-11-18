import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/month_calendar.dart';
import 'today.dart';

export '../widgets/month_calendar.dart' show dayKey;

/// The Plan tab's calendar: the same jobs, laid out by date. A month
/// grid with a dot per job under the day, and the tapped day's jobs
/// listed underneath in the usual cards. The grid itself is the
/// shared [MonthCalendarGrid] (History's calendar uses it too).

/// Everything that belongs to one calendar day.
class CalendarDay {
  /// Jobs due this day that still need doing, in plan order.
  final List<TaskInstance> upcoming;

  /// Jobs finished this day (by the day they were done).
  final List<TaskInstance> done;

  const CalendarDay({this.upcoming = const [], this.done = const []});

  bool get isEmpty => upcoming.isEmpty && done.isEmpty;

  /// Every job this day had is finished.
  bool get allDone => upcoming.isEmpty && done.isNotEmpty;

  /// A job due this day is overdue: still open and its day has passed.
  bool hasOverdue(DateTime now) => upcoming.any((t) => t.isOverdue(now));
}

/// Group [tasks] onto calendar days. Open jobs land on their due day;
/// finished jobs land on the day they were done (falling back to the
/// due day when no done date was recorded), the same rule Plan's
/// Completed section sorts by. Skipped jobs are not shown, as in the
/// list. Pure: the widget and the tests share this.
Map<DateTime, CalendarDay> groupTasksByDay(List<TaskInstance> tasks) {
  final due = <DateTime, List<TaskInstance>>{};
  final done = <DateTime, List<TaskInstance>>{};
  for (final t in tasks) {
    switch (t.status) {
      case TaskStatus.upcoming:
        due.putIfAbsent(dayKey(t.dueDate), () => []).add(t);
      case TaskStatus.done:
        done.putIfAbsent(dayKey(t.doneDate ?? t.dueDate), () => []).add(t);
      case TaskStatus.skipped:
        break;
    }
  }
  final days = <DateTime, CalendarDay>{};
  for (final k in {...due.keys, ...done.keys}) {
    final u = [...(due[k] ?? const <TaskInstance>[])]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final d = [...(done[k] ?? const <TaskInstance>[])]
      ..sort(
        (a, b) => (b.doneDate ?? b.dueDate).compareTo(a.doneDate ?? a.dueDate),
      );
    days[k] = CalendarDay(upcoming: u, done: d);
  }
  return days;
}

/// The next open job due after [day] (or the earliest open job at all,
/// when nothing is due later). Null when the plan has no open jobs.
TaskInstance? nextJobAfter(List<TaskInstance> tasks, DateTime day) {
  final open = tasks.where((t) => t.status == TaskStatus.upcoming).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  if (open.isEmpty) return null;
  for (final t in open) {
    if (dayKey(t.dueDate).isAfter(dayKey(day))) return t;
  }
  return open.first;
}

class PlanCalendarView extends StatefulWidget {
  final List<TaskInstance> tasks;
  final Map<String, TaskTemplate> templateById;
  final void Function(TaskInstance) onOpenTask;
  final void Function(TaskInstance) onDone;

  const PlanCalendarView({
    super.key,
    required this.tasks,
    required this.templateById,
    required this.onOpenTask,
    required this.onDone,
  });

  @override
  State<PlanCalendarView> createState() => _PlanCalendarViewState();
}

class _PlanCalendarViewState extends State<PlanCalendarView> {
  late DateTime _selected; // the tapped day

  @override
  void initState() {
    super.initState();
    _selected = dayKey(DateTime.now());
  }

  /// The dots under one day, Plan's rules: green per finished job
  /// when the day is all done; otherwise a red dot when anything due
  /// is overdue, then an accent dot per open job.
  List<Color> _dotsFor(
    BuildContext context,
    Map<DateTime, CalendarDay> byDay,
    DateTime now,
    DateTime day,
  ) {
    final data = byDay[day] ?? const CalendarDay();
    if (data.isEmpty) return const [];
    if (data.allDone) {
      return [for (var i = 0; i < data.done.length && i < 3; i++) NkColors.green];
    }
    final dots = <Color>[
      if (data.hasOverdue(now)) NkColors.red,
      for (var i = 0; i < data.upcoming.length && i < 3; i++) context.primary,
    ];
    return dots.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final byDay = groupTasksByDay(widget.tasks);
    final selectedDay = byDay[_selected] ?? const CalendarDay();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonthCalendarGrid(
          dotsForDay: (day) => _dotsFor(context, byDay, now, day),
          onSelectedChanged: (day) => setState(() => _selected = day),
        ),
        const SizedBox(height: 18),
        SectionHeading(DateFormat('EEE d MMM').format(_selected)),
        const SizedBox(height: 10),
        if (selectedDay.isEmpty) ...[
          NkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing due this day.',
                  style: TextStyle(color: context.muted),
                ),
                if (nextJobAfter(widget.tasks, _selected) != null) ...[
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final next = nextJobAfter(widget.tasks, _selected)!;
                      return Text(
                        'Next job: ${next.title} · '
                        '${DateFormat('EEE d MMM').format(next.dueDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.navyText,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
        for (final t in selectedDay.upcoming) ...[
          TaskCard(
            task: t,
            minutes: t.templateId == null
                ? null
                : widget.templateById[t.templateId]?.minutes,
            onTap: () => widget.onOpenTask(t),
            onDone: () => widget.onDone(t),
          ),
          const SizedBox(height: 10),
        ],
        for (final t in selectedDay.done) ...[
          DoneTaskCard(task: t),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
