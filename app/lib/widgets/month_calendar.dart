import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../widgets.dart';

/// Midnight at the start of [d]'s day: the key every calendar
/// grouping uses.
DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// The month grid both calendars share (Plan since build 15, History
/// since build 21): Monday-first weeks, the month stepped with
/// chevrons, today ringed, the tapped day filled, and up to three
/// dots under a day in the colours the caller assigns to it. The grid
/// owns the displayed month and the selected day (today at first) and
/// reports taps; what a day means, and what is listed underneath the
/// grid, stays with the caller.
class MonthCalendarGrid extends StatefulWidget {
  /// The dot colours to draw under [day] (at most three are shown).
  final List<Color> Function(DateTime day) dotsForDay;

  /// Called with the day key whenever the user taps a day.
  final ValueChanged<DateTime> onSelectedChanged;

  const MonthCalendarGrid({
    super.key,
    required this.dotsForDay,
    required this.onSelectedChanged,
  });

  @override
  State<MonthCalendarGrid> createState() => _MonthCalendarGridState();
}

class _MonthCalendarGridState extends State<MonthCalendarGrid> {
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

  void _select(DateTime day) {
    setState(() => _selected = day);
    widget.onSelectedChanged(day);
  }

  @override
  Widget build(BuildContext context) {
    final today = dayKey(DateTime.now());
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

    return NkCard(
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
                    child: _cell(context, cells[r * 7 + c], today: today),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime? day, {
    required DateTime today,
  }) {
    if (day == null) return const SizedBox(height: 44);
    final isSelected = day == _selected;
    final isToday = day == today;
    final dots = widget.dotsForDay(day).take(3).toList();

    return InkWell(
      onTap: () => _select(day),
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
