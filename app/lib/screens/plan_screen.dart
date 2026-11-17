import 'package:flutter/material.dart';

import '../actions.dart';
import '../app_state.dart';
import '../db.dart';
import '../models.dart';
import '../plan.dart';
import '../reminders.dart';
import '../sync.dart';
import '../theme.dart';
import '../widgets.dart';
import 'job_picker.dart';
import 'today.dart';

/// The Plan tab: everything on the plan, grouped by urgency, plus the
/// completed history. Custom jobs are a Pro feature (the built-in seasonal
/// plan is free forever).
class PlanScreen extends StatelessWidget {
  final AppState state;
  final void Function(TaskInstance) onOpenTask;
  final VoidCallback onOpenPaywall;

  const PlanScreen({
    super.key,
    required this.state,
    required this.onOpenTask,
    required this.onOpenPaywall,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = state.upcoming;
    final overdue = upcoming.where((t) => t.isOverdue(now)).toList();
    final soon = upcoming
        .where((t) => !t.isOverdue(now) && t.dueDate.difference(now).inDays <= 30)
        .toList();
    final later = upcoming
        .where((t) => !t.isOverdue(now) && t.dueDate.difference(now).inDays > 30)
        .toList();
    final done = state.tasks.where((t) => t.status == TaskStatus.done).toList()
      ..sort((a, b) => (b.doneDate ?? b.dueDate).compareTo(a.doneDate ?? a.dueDate));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Your plan',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.navyText)),
            ),
            FilledButton.icon(
              onPressed: () => _addCustom(context),
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Add job'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'The jobs you ticked, plus your own. Tap any job for the full guide.',
          style: TextStyle(color: context.muted),
        ),
        const SizedBox(height: 14),
        NkCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.selectionFor(state.activeHome!.id!).length} jobs in your plan',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.navyText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your ticked library jobs. Change them any time.',
                      style: TextStyle(fontSize: 13, color: context.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _chooseJobs(context),
                child: const Text('Choose jobs',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (overdue.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeading('Overdue'),
          const SizedBox(height: 10),
          for (final t in overdue) ...[
            TaskCard(
                task: t,
                minutes: t.templateId == null
                    ? null
                    : state.templateById[t.templateId]?.minutes,
                onTap: () => onOpenTask(t),
                onDone: () => completeTask(state, t)),
            const SizedBox(height: 10),
          ],
        ],
        if (soon.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeading('Due in the next 30 days'),
          const SizedBox(height: 10),
          for (final t in soon) ...[
            TaskCard(
                task: t,
                minutes: t.templateId == null
                    ? null
                    : state.templateById[t.templateId]?.minutes,
                onTap: () => onOpenTask(t),
                onDone: () => completeTask(state, t)),
            const SizedBox(height: 10),
          ],
        ],
        if (later.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeading('Later'),
          const SizedBox(height: 10),
          for (final t in later) ...[
            TaskCard(
                task: t,
                minutes: t.templateId == null
                    ? null
                    : state.templateById[t.templateId]?.minutes,
                onTap: () => onOpenTask(t),
                onDone: () => completeTask(state, t)),
            const SizedBox(height: 10),
          ],
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeading('Completed'),
          const SizedBox(height: 10),
          for (final t in done.take(20))
            NkCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: NkColors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.navyText)),
                        Text(
                          'Done ${t.doneDate == null ? '' : _shortDate(t.doneDate!)}'
                          '${t.costPaid != null && t.costPaid! > 0 ? ' · ${money(t.costPaid!)}' : ''}'
                          '${(t.doneBy ?? '').isNotEmpty ? ' · by ${t.doneBy}' : ''}',
                          style: TextStyle(fontSize: 13, color: context.muted),
                        ),
                        if ((t.doneNote ?? '').isNotEmpty)
                          Text(
                            t.doneNote!,
                            style:
                                TextStyle(fontSize: 13, color: context.muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _shortDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  /// Open the job picker with the current ticks; on save, apply the
  /// diff (new ticks join the plan, unticked jobs leave it) and refresh.
  Future<void> _chooseJobs(BuildContext context) async {
    final homeId = state.activeHome!.id!;
    final current = await state.selectedTemplateIds(homeId);
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => JobPickerScreen(
          templates: state.templates,
          initialSelection: current,
        ),
      ),
    );
    if (result == null) return;
    await applyPlanSelection(
      homeId: homeId,
      newSelection: result,
      templates: state.templates,
      currentTasks: state.tasks,
      now: DateTime.now(),
    );
    await state.reload();
    await Reminders.reschedule(state.tasks, state.appliances);
    SyncService.syncNow();
  }

  Future<void> _addCustom(BuildContext context) async {
    if (!state.isPro &&
        activeCustomJobs(state.tasks) >= freeCustomJobLimit) {
      onOpenPaywall();
      return;
    }
    final result = await showDialog<_CustomJob>(
      context: context,
      builder: (_) => const _CustomJobDialog(),
    );
    if (result == null) return;
    final now = DateTime.now();
    await AppDb.insertTask(TaskInstance(
      homeId: state.activeHome!.id!,
      title: result.title,
      category: result.category,
      dueDate: result.dueDate,
      updatedAt: now,
    ));
    await state.reload();
    await Reminders.reschedule(state.tasks, state.appliances);
    SyncService.syncNow();
  }
}

class _CustomJob {
  final String title;
  final String category;
  final DateTime dueDate;
  _CustomJob(this.title, this.category, this.dueDate);
}

class _CustomJobDialog extends StatefulWidget {
  const _CustomJobDialog();

  @override
  State<_CustomJobDialog> createState() => _CustomJobDialogState();
}

class _CustomJobDialogState extends State<_CustomJobDialog> {
  final _title = TextEditingController();
  String _category = 'Interior';
  DateTime _due = DateTime.now().add(const Duration(days: 7));

  static const categories = [
    'HVAC', 'Plumbing', 'Roof & Gutters', 'Exterior', 'Interior',
    'Safety', 'Appliances', 'Seasonal',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a custom job'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Job name'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due date'),
            subtitle: Text('${_due.month}/${_due.day}/${_due.year}'),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _due,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (picked != null) setState(() => _due = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.pop(
                context, _CustomJob(_title.text.trim(), _category, _due));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
