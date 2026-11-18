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
import '../widgets/avatar_menu.dart';
import '../widgets/category_picker.dart';
import 'job_picker.dart';
import 'plan_calendar.dart';
import 'today.dart';

/// The Plan tab: everything on the plan, grouped by urgency, plus the
/// completed history. A List / Calendar switch sits under the summary
/// card; the calendar shows the same jobs by date. Custom jobs are a
/// Pro feature (the built-in seasonal plan is free forever).
class PlanScreen extends StatefulWidget {
  final AppState state;
  final void Function(TaskInstance) onOpenTask;
  final VoidCallback onOpenPaywall;
  final VoidCallback? onAvatarTap;

  const PlanScreen({
    super.key,
    required this.state,
    required this.onOpenTask,
    required this.onOpenPaywall,
    this.onAvatarTap,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _calendar = false;

  AppState get state => widget.state;
  void Function(TaskInstance) get onOpenTask => widget.onOpenTask;
  VoidCallback get onOpenPaywall => widget.onOpenPaywall;

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
            const SizedBox(width: 10),
            AvatarButton(state: state, onTap: widget.onAvatarTap),
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
        if (_calendar) ...[
          const SizedBox(height: 16),
          PlanCalendarView(
            tasks: state.tasks,
            templateById: state.templateById,
            onOpenTask: onOpenTask,
            onDone: (t, r) => completeTask(state, t,
                costPaid: r.cost, doneBy: r.doneBy, doneNote: r.note),
          ),
        ],
        if (!_calendar) ...[
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
                onDone: (r) => completeTask(state, t,
                    costPaid: r.cost, doneBy: r.doneBy, doneNote: r.note)),
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
                onDone: (r) => completeTask(state, t,
                    costPaid: r.cost, doneBy: r.doneBy, doneNote: r.note)),
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
                onDone: (r) => completeTask(state, t,
                    costPaid: r.cost, doneBy: r.doneBy, doneNote: r.note)),
            const SizedBox(height: 10),
          ],
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeading('Completed'),
          const SizedBox(height: 10),
          for (final t in done.take(20)) ...[
            DoneTaskCard(task: t),
            const SizedBox(height: 10),
          ],
        ],
        ],
      ],
    );
  }

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
      builder: (_) =>
          _CustomJobDialog(state: state, onOpenPaywall: onOpenPaywall),
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
    if (context.mounted) showTicker(context, 'Task added');
  }
}

class _CustomJob {
  final String title;
  final String category;
  final DateTime dueDate;
  _CustomJob(this.title, this.category, this.dueDate);
}

class _CustomJobDialog extends StatefulWidget {
  final AppState state;
  final VoidCallback onOpenPaywall;

  const _CustomJobDialog(
      {required this.state, required this.onOpenPaywall});

  @override
  State<_CustomJobDialog> createState() => _CustomJobDialogState();
}

class _CustomJobDialogState extends State<_CustomJobDialog> {
  final _title = TextEditingController();
  String _category = 'Interior';
  DateTime _due = DateTime.now().add(const Duration(days: 7));

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
          // The shared category picker (build 24), same as the
          // expense form: built-ins, the user's own categories,
          // and the Pro-gated way to add another.
          CategoryField(
            value: _category,
            onTap: () async {
              final picked = await showCategoryPicker(
                context,
                state: widget.state,
                current: _category,
                onOpenPaywall: widget.onOpenPaywall,
              );
              if (picked != null) setState(() => _category = picked);
            },
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
