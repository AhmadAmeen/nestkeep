import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'today.dart';

/// The Plan tab's calendar: the same jobs, laid out by date. A month
/// grid with a dot per job under the day, and the tapped day's jobs
/// listed underneath in the usual cards.

/// Midnight at the start of [d]'s day: the key every grouping uses.
DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

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
  late DateTime _month; // first of the displayed month
  late DateTime _selected; // the tapped day

  @override
  void initState() {
    super.initState();
    final today = dayKey(DateTime.now());
    _month = DateTime(today.year, today.month);
    _selected = today;
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dayKey(now);
    final byDay = groupTasksByDay(widget.tasks);
    final selectedDay = byDay[_selected] ?? const CalendarDay();

    final first = _month;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    // Monday-first: DateTime.weekday is Mon=1..Sun=7.
    final leadBlanks = first.weekday - 1;
    final cells = <DateTime?>[
      for (var i = 0; i < leadBlanks; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(first.year, first.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NkCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                    onPressed: () => _moveMonth(-1),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(first),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.navyText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                    onPressed: () => _moveMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final label in const [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ])
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.muted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (var r = 0; r < cells.length ~/ 7; r++)
                Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: _cell(
                          context,
                          cells[r * 7 + c],
                          byDay,
                          today: today,
                          now: now,
                        ),
                      ),
                  ],
                ),
            ],
          ),
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

  Widget _cell(
    BuildContext context,
    DateTime? day,
    Map<DateTime, CalendarDay> byDay, {
    required DateTime today,
    required DateTime now,
  }) {
    if (day == null) return const SizedBox(height: 44);
    final data = byDay[day] ?? const CalendarDay();
    final isSelected = day == _selected;
    final isToday = day == today;

    final dots = <Color>[];
    if (!data.isEmpty) {
      if (data.allDone) {
        for (var i = 0; i < data.done.length && i < 3; i++) {
          dots.add(NkColors.green);
        }
      } else {
        if (data.hasOverdue(now)) dots.add(NkColors.red);
        for (var i = 0; i < data.upcoming.length && dots.length < 3; i++) {
          dots.add(context.primary);
        }
      }
    }

    return InkWell(
      onTap: () => setState(() => _selected = day),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? context.primary : null,
                border: !isSelected && isToday
                    ? Border.all(
                        color: context.primary.withValues(alpha: 0.55),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isToday
                      ? context.primary
                      : context.navyText,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 5,
              child: dots.isEmpty
                  ? null
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final color in dots)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1.2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
