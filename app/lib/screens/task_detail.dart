import 'package:flutter/material.dart';

import '../actions.dart';
import '../app_state.dart';
import '../calendar.dart';
import '../models.dart';
import '../plan.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/animated_check.dart';
import '../widgets/done_dialog.dart';

/// The task guide: why it matters, what it costs either way, the steps and
/// what you need. No shopping links anywhere, by design.
class TaskDetailScreen extends StatefulWidget {
  final AppState state;
  final TaskInstance task;

  const TaskDetailScreen({super.key, required this.state, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  /// True between the done dialog's confirm and the pop back: the
  /// action area shows the drawing tick instead of the buttons.
  bool _completing = false;

  AppState get state => widget.state;
  TaskInstance get task => widget.task;

  TaskTemplate? get tpl =>
      task.templateId == null ? null : state.templateById[task.templateId];

  Future<void> _markDone(BuildContext context) async {
    if (_completing) return;
    final result = await showDoneDialog(context);
    // Dismissing the dialog without saving is a cancel: nothing is
    // completed and nothing animates.
    if (result == null || !context.mounted) return;
    setState(() => _completing = true);
    // Let the tick draw itself before the completion lands and the
    // screen pops back to the list.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    await completeTask(
      state,
      task,
      costPaid: result.cost,
      doneBy: result.doneBy,
      doneNote: result.note,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = tpl;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Task guide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: categoryColor(task.category).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(categoryIcon(task.category),
                    color: categoryColor(task.category), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.navyText,
                      ),
                    ),
                    Text(
                      '${task.category} · ${dueLabel(task, now)}',
                      style: TextStyle(
                        color: task.isOverdue(now)
                            ? NkColors.red
                            : context.muted,
                        fontWeight: task.isOverdue(now)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (t != null &&
              state.profileFor(task.homeId) != null &&
              planReason(t, state.profileFor(task.homeId)!) != null) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 19, color: NkColors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'In your plan because '
                    '${planReason(t, state.profileFor(task.homeId)!)}.',
                    style: TextStyle(fontSize: 13.5, color: context.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (t != null) ...[
            NkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Why it matters',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: context.navyText)),
                  const SizedBox(height: 6),
                  Text(t.why, style: TextStyle(color: context.muted, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: NkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Do it yourself',
                            style: TextStyle(fontSize: 13, color: context.muted)),
                        const SizedBox(height: 4),
                        Text(t.diyCost == 0 ? 'Free' : 'about \$${t.diyCost}',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: context.navyText)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cost of ignoring',
                            style: TextStyle(fontSize: 13, color: context.muted)),
                        const SizedBox(height: 4),
                        Text('up to \$${t.ignoreCost}',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: NkColors.red)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NkCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _fact(Icons.timer_outlined, '${t.minutes} min'),
                  _fact(Icons.signal_cellular_alt, t.difficulty),
                  _fact(Icons.repeat, 'Every ${t.frequencyMonths} mo'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            NkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to do it',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: context.navyText)),
                  const SizedBox(height: 10),
                  for (var i = 0; i < t.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(t.steps[i],
                                style: TextStyle(height: 1.4, color: context.navyText)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            NkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What you need',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: context.navyText)),
                  const SizedBox(height: 8),
                  for (final n in t.needs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check, size: 16, color: NkColors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(n)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ] else
            NkCard(
              child: Text('A custom job you added. Mark it done when it is done.',
                  style: TextStyle(color: context.muted)),
            ),
          const SizedBox(height: 20),
          if (_completing)
            const Center(child: AnimatedCheck(size: 54))
          else
            FilledButton.icon(
              onPressed: () => _markDone(context),
              icon: const Icon(Icons.check),
              label: const Text('Mark done'),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _completing
                      ? null
                      : () async {
                          await snoozeTask(state, task, 7);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  child: const Text('Remind in a week'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _completing
                      ? null
                      : () async {
                          await skipTask(state, task);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  child: const Text('Skip this time'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _completing
                ? null
                : () async {
                    final ok = await addJobToCalendar(
                      title: task.title,
                      dueDate: task.dueDate,
                      description: jobDescription(task, tpl),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Opening your calendar. The job is prefilled; you save it there.'
                            : 'No calendar app found on this phone.'),
                      ));
                    }
                  },
            icon: const Icon(Icons.event_outlined, size: 19),
            label: const Text('Add to calendar'),
          ),
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}


