import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/month_calendar.dart';

/// Home history: everything that was done to this home, newest first,
/// with the month up top. This is the record a buyer or an insurer
/// actually wants to see, so it shows who did the work and what it cost.
///
/// A List / Calendar switch sits under the stats (build 21, the same
/// pattern as Plan): the calendar lays the finished jobs out by the
/// day they were done on the shared month grid, green dots under the
/// days that have completions, and tapping a day lists that day's
/// jobs underneath in the same rows as the list. The list stays the
/// default.
class HistoryScreen extends StatefulWidget {
  final AppState state;

  const HistoryScreen({super.key, required this.state});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _calendar = false;
  late DateTime _selectedDay;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _selectedDay = dayKey(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final done = state.tasks.where((t) => t.status == TaskStatus.done).toList()
      ..sort((a, b) =>
          (b.doneDate ?? b.dueDate).compareTo(a.doneDate ?? a.dueDate));
    final thisMonth = done
        .where((t) =>
            t.doneDate != null &&
            t.doneDate!.year == now.year &&
            t.doneDate!.month == now.month)
        .toList();
    final spentThisMonth = state.expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (s, e) => s + e.amount);
    // Finished jobs by the day they were done (the due day stands in
    // when no done date was recorded, the rule Plan's calendar uses).
    final byDay = <DateTime, List<TaskInstance>>{};
    for (final t in done) {
      byDay.putIfAbsent(dayKey(t.doneDate ?? t.dueDate), () => []).add(t);
    }
    final selectedJobs = byDay[_selectedDay] ?? const <TaskInstance>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Home history')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          NkCard(
            child: Row(
              children: [
                _stat(context, '${thisMonth.length}', 'done this month'),
                _divider(context),
                _stat(context, money(spentThisMonth), 'spent this month'),
                _divider(context),
                _stat(context, '${done.length}', 'done all time'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.view_agenda_outlined, size: 18),
                label: Text('List'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.calendar_month_outlined, size: 18),
                label: Text('Calendar'),
              ),
            ],
            selected: {_calendar},
            onSelectionChanged: (s) => setState(() => _calendar = s.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: context.primary.withValues(alpha: 0.14),
              selectedForegroundColor: context.primary,
            ),
          ),
          if (!_calendar) ...[
            const SizedBox(height: 20),
            const SectionHeading('Timeline'),
            const SizedBox(height: 10),
            if (done.isEmpty)
              NkCard(
                child: Text(
                  'Nothing finished yet. When you mark a job done, it lands here with the date, the cost, and who did it.',
                  style: TextStyle(color: context.muted, height: 1.4),
                ),
              ),
            for (final t in done) ...[
              _row(context, t),
              const SizedBox(height: 10),
            ],
          ],
          if (_calendar) ...[
            const SizedBox(height: 16),
            MonthCalendarGrid(
              dotsForDay: (day) => [
                for (var i = 0;
                    i < (byDay[day]?.length ?? 0) && i < 3;
                    i++)
                  NkColors.green,
              ],
              onSelectedChanged: (day) =>
                  setState(() => _selectedDay = day),
            ),
            const SizedBox(height: 18),
            SectionHeading(DateFormat('EEE d MMM').format(_selectedDay)),
            const SizedBox(height: 10),
            if (selectedJobs.isEmpty)
              NkCard(
                child: Text(
                  'Nothing finished this day.',
                  style: TextStyle(color: context.muted),
                ),
              ),
            for (final t in selectedJobs) ...[
              _row(context, t),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  /// One finished job's row, shared by the timeline and the
  /// calendar's day list so both read the same.
  Widget _row(BuildContext context, TaskInstance t) {
    return NkCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: categoryColor(t.category).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryIcon(t.category),
                color: categoryColor(t.category), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: context.navyText)),
                Text(
                  _metaLine(t),
                  style: TextStyle(fontSize: 13, color: context.muted),
                ),
                if ((t.doneNote ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      t.doneNote!,
                      style:
                          TextStyle(fontSize: 13.5, color: context.navyText),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine(TaskInstance t) {
    final parts = <String>[
      if (t.doneDate != null)
        '${t.doneDate!.month}/${t.doneDate!.day}/${t.doneDate!.year}',
      if (t.costPaid != null && t.costPaid! > 0) money(t.costPaid!),
      if ((t.doneBy ?? '').isNotEmpty) 'by ${t.doneBy}',
    ];
    return parts.join(' · ');
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.navyText)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.muted)),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(width: 1, height: 40, color: context.line);
  }
}
