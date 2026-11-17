import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'finding_jobs.dart';

/// How often a library job repeats, in plain words for the picker rows.
String jobFrequencyLabel(int frequencyMonths) {
  if (frequencyMonths <= 1) return 'Monthly';
  if (frequencyMonths == 12) return 'Yearly';
  return 'Every $frequencyMonths months';
}

/// The one-line summary under a job's title in the picker: how often it
/// runs, how long it takes, what doing it yourself typically costs.
/// Empty parts are simply left out.
String jobMetaLine(TaskTemplate t) {
  final parts = <String>[
    jobFrequencyLabel(t.frequencyMonths),
    if (t.minutes > 0) '~${t.minutes} min',
    if (t.diyCost > 0) 'DIY ~\$${t.diyCost}' else 'Free to DIY',
  ];
  return parts.join(' · ');
}

/// The grouped job picker: every library job by category, a checkbox per
/// job and per group, and tap-to-expand steps so people see exactly what
/// they are signing up for. Only ticked jobs ever enter the plan.
///
/// Groups start collapsed to just their heading: the whole group can be
/// ticked or unticked right there, and tapping the heading opens it to
/// the individual jobs.
///
/// Controlled: the parent owns the selection set and gets every change
/// through [onChanged]. Renders as a plain column, so it drops into any
/// scrolling parent (the onboarding wizard) as easily as a full screen.
class JobPickerList extends StatefulWidget {
  final List<TaskTemplate> templates;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const JobPickerList({
    super.key,
    required this.templates,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<JobPickerList> createState() => _JobPickerListState();
}

class _JobPickerListState extends State<JobPickerList> {
  String? _expandedId;

  /// Categories currently opened up to their job rows. Empty at first:
  /// every group starts collapsed to its heading.
  final Set<String> _openGroups = {};

  /// Groups in the order their category first appears in the library.
  Map<String, List<TaskTemplate>> get _groups {
    final map = <String, List<TaskTemplate>>{};
    for (final t in widget.templates) {
      map.putIfAbsent(t.category, () => []).add(t);
    }
    return map;
  }

  void _setSelected(String id, bool on) {
    final next = {...widget.selected};
    if (on) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.onChanged(next);
  }

  void _setGroup(List<TaskTemplate> group, bool on) {
    final next = {...widget.selected};
    for (final t in group) {
      if (on) {
        next.add(t.id);
      } else {
        next.remove(t.id);
      }
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          _groupCard(context, entry.key, entry.value),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _groupCard(
      BuildContext context, String category, List<TaskTemplate> group) {
    final onCount = group.where((t) => widget.selected.contains(t.id)).length;
    final bool? groupValue =
        onCount == 0 ? false : (onCount == group.length ? true : null);
    final color = categoryColor(category);
    final open = _openGroups.contains(category);
    return NkCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The heading itself is the expand control: tapping it
              // (anywhere but the checkbox) opens or closes the group.
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    if (open) {
                      _openGroups.remove(category);
                    } else {
                      _openGroups.add(category);
                    }
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(categoryIcon(category),
                            color: color, size: 21),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: context.navyText,
                              ),
                            ),
                            Text(
                              '$onCount of ${group.length} on',
                              style: TextStyle(
                                  fontSize: 12.5, color: context.muted),
                            ),
                            if (!open)
                              Text(
                                'Tap to see sub tasks',
                                style: TextStyle(
                                    fontSize: 11.5, color: context.muted),
                              ),
                          ],
                        ),
                      ),
                      Icon(open ? Icons.expand_less : Icons.expand_more,
                          color: context.muted),
                    ],
                  ),
                ),
              ),
              // The group checkbox works straight from the collapsed
              // heading: it ticks or unticks the whole group at once.
              Checkbox(
                value: groupValue,
                tristate: true,
                activeColor: context.primary,
                onChanged: (v) => _setGroup(group, v ?? false),
              ),
            ],
          ),
          if (open) ...[
            const Divider(height: 1),
            for (final t in group) _jobRow(context, t),
          ],
        ],
      ),
    );
  }

  Widget _jobRow(BuildContext context, TaskTemplate t) {
    final on = widget.selected.contains(t.id);
    final expanded = _expandedId == t.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: on,
              activeColor: context.primary,
              onChanged: (v) => _setSelected(t.id, v ?? false),
            ),
            Expanded(
              child: InkWell(
                onTap: () =>
                    setState(() => _expandedId = expanded ? null : t.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: context.navyText,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        jobMetaLine(t),
                        style: TextStyle(fontSize: 12.5, color: context.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              color: context.muted,
              tooltip: expanded ? 'Hide the steps' : 'See the steps',
              onPressed: () =>
                  setState(() => _expandedId = expanded ? null : t.id),
            ),
          ],
        ),
        if (expanded) _stepsBlock(context, t),
      ],
    );
  }

  /// The expanded view: why the job matters, then its steps as the
  /// subtask list, in the same numbered style as the task guide.
  Widget _stepsBlock(BuildContext context, TaskTemplate t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.why,
            style: TextStyle(color: context.muted, height: 1.4, fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < t.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: context.primary,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10.5),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      t.steps[i],
                      style: TextStyle(
                          height: 1.35, fontSize: 13.5, color: context.navyText),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The full-screen picker used from the Plan tab. Pops with the new
/// selection set on Save, or null when the user backs out.
///
/// Opening it first plays the short "Finding jobs for you" loader
/// ([FindingJobsView], about 3 seconds) before the picker itself shows;
/// pass [showLoader] false to skip straight to the list.
class JobPickerScreen extends StatefulWidget {
  final List<TaskTemplate> templates;
  final Set<String> initialSelection;
  final bool showLoader;

  const JobPickerScreen({
    super.key,
    required this.templates,
    required this.initialSelection,
    this.showLoader = true,
  });

  @override
  State<JobPickerScreen> createState() => _JobPickerScreenState();
}

class _JobPickerScreenState extends State<JobPickerScreen> {
  late Set<String> _selected = {...widget.initialSelection};
  late bool _loading = widget.showLoader;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose your jobs')),
        body: FindingJobsView(
          onDone: () {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your jobs')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Tick the jobs you want in your plan. Tap a job to see its steps.',
            style: TextStyle(color: context.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          JobPickerList(
            templates: widget.templates,
            selected: _selected,
            onChanged: (s) => setState(() => _selected = s),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selected.length} job${_selected.length == 1 ? '' : 's'} ticked',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: context.navyText),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
