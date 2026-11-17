import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Home history: everything that was done to this home, newest first,
/// with the month up top. This is the record a buyer or an insurer
/// actually wants to see, so it shows who did the work and what it cost.
class HistoryScreen extends StatelessWidget {
  final AppState state;

  const HistoryScreen({super.key, required this.state});

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
            NkCard(
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
                              style: TextStyle(
                                  fontSize: 13.5, color: context.navyText),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
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
