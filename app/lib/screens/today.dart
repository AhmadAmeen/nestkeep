import 'package:flutter/material.dart';

import '../actions.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/animated_check.dart';
import '../widgets/avatar_menu.dart';
import '../widgets/done_dialog.dart';
import 'history.dart';
import 'score_detail.dart';

/// The Today screen: the approved front-page grid. One card per job,
/// generous spacing, nothing repeated.
class TodayScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onSeeAllPlan;
  final void Function(TaskInstance) onOpenTask;
  final Future<void> Function(TaskInstance, DoneResult) onQuickDone;
  final VoidCallback? onAvatarTap;

  const TodayScreen({
    super.key,
    required this.state,
    required this.onSeeAllPlan,
    required this.onOpenTask,
    required this.onQuickDone,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final home = state.activeHome!;
    final health = state.health;
    final now = DateTime.now();
    // The first upcoming job gets the Next up card; the list below
    // starts from the second so no job appears twice on this screen.
    final nextTasks = state.upcoming.skip(1).take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome home.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.navyText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    home.addressLine.isEmpty ? home.name : home.addressLine,
                    style: TextStyle(fontSize: 14, color: context.muted),
                  ),
                ],
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 27),
                  onPressed: onSeeAllPlan,
                ),
                if (state.overdue.isNotEmpty)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: NkColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${state.overdue.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            AvatarButton(state: state, onTap: onAvatarTap),
          ],
        ),
        const SizedBox(height: 18),

        // Health score + right column
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 55,
                child: NkCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ScoreDetailScreen(state: state),
                  )),
                  child: Column(
                    children: [
                      HealthRing(score: health.score, grade: health.grade),
                      const SizedBox(height: 10),
                      Text(
                        health.statusSentence,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: context.muted),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'See the breakdown',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.primary,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16, color: context.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 45,
                child: Column(
                  children: [
                    Expanded(
                      child: NkCard(
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: NkColors.amber, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${state.streakWeeks} week${state.streakWeeks == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: context.navyText,
                                    ),
                                  ),
                                  Text('streak',
                                      style: TextStyle(
                                          fontSize: 13, color: context.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: NkCard(
                        child: Row(
                          children: [
                            Icon(Icons.savings_outlined,
                                color: context.primary, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    money(state.spentThisYear),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: context.navyText,
                                    ),
                                  ),
                                  Text(
                                    'spent this year',
                                    style: TextStyle(
                                        fontSize: 13, color: context.muted),
                                  ),
                                  Text(
                                    'typical ${money(state.typicalYearSpend)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: NkColors.amber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Next up: the single most pressing job, with its two actions
        // right on the card.
        if (state.upcoming.isNotEmpty) ...[
          Builder(builder: (context) {
            final next = state.upcoming.first;
            return _NextUpCard(
              task: next,
              minutes: next.templateId == null
                  ? null
                  : state.templateById[next.templateId]?.minutes,
              now: now,
              onTap: () => onOpenTask(next),
              onDone: onQuickDone,
              onLater: () => snoozeTask(state, next, 1),
            );
          }),
          const SizedBox(height: 12),
        ],

        // Action needed / Completed pair
        Row(
          children: [
            Expanded(
              child: NkCard(
                onTap: onSeeAllPlan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: NkColors.red, size: 20),
                        const SizedBox(width: 6),
                        Text('Action needed',
                            style: TextStyle(
                                fontSize: 13.5, color: context.muted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${state.actionNeeded.length}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.navyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BounceOnIncrease(
                value: health.completedCount,
                child: NkCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HistoryScreen(state: state),
                  )),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: NkColors.green, size: 20),
                          const SizedBox(width: 6),
                          Text('Completed',
                              style: TextStyle(
                                  fontSize: 13.5, color: context.muted)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${health.completedCount}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.navyText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tip of the week
        NkCard(
          accentLeft: NkColors.amber,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: NkColors.amber, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tip of the week',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.navyText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tipOfTheWeek(now),
                      style: TextStyle(fontSize: 13.5, color: context.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        if (nextTasks.isNotEmpty || state.upcoming.isEmpty) ...[
          SectionHeading('Upcoming tasks',
              actionLabel: 'See all', onAction: onSeeAllPlan),
          const SizedBox(height: 10),
          if (state.upcoming.isEmpty)
            NkCard(
              child: Text(
                'Nothing scheduled. Add a job from the Plan tab.',
                style: TextStyle(color: context.muted),
              ),
            ),
          for (final t in nextTasks) ...[
            TaskCard(
                task: t,
                onTap: () => onOpenTask(t),
                onDone: (r) => onQuickDone(t, r)),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

/// One task, one card: icon tile, title, due label, quick-done circle.
/// [minutes] is the library job's typical duration when known; the
/// Plan passes it so rows can say how long a job takes.
///
/// Tapping the quick-done circle opens the same done dialog as the
/// task guide (build 23: one completion path everywhere) — the job
/// is only completed when the user confirms there. On a confirm, a
/// tick draws itself in place of the button, the card tints green
/// and glides away, and only then is [onDone] invoked with the
/// dialog's answers, so the state reload finds the row already
/// visually gone instead of snapping. Cancelling the dialog leaves
/// the card exactly as it was.
class TaskCard extends StatefulWidget {
  final TaskInstance task;
  final VoidCallback onTap;
  final Future<void> Function(DoneResult) onDone;
  final int? minutes;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onDone,
    this.minutes,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  bool _completing = false;
  bool _fired = false;
  bool _asking = false;
  DoneResult? _result;

  late final AnimationController _collapse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _shrink = Tween<double>(begin: 1, end: 0)
      .animate(CurvedAnimation(parent: _collapse, curve: Curves.easeInOut));
  late final Animation<double> _fade = Tween<double>(begin: 1, end: 0)
      .animate(CurvedAnimation(parent: _collapse, curve: Curves.easeIn));
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: Offset.zero, end: const Offset(0.08, -0.05))
          .animate(CurvedAnimation(parent: _collapse, curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    _collapse.addStatusListener((status) {
      if (status == AnimationStatus.completed) _fire();
    });
  }

  @override
  void dispose() {
    _collapse.dispose();
    super.dispose();
  }

  /// The tick asks first (build 23): the done dialog opens, and
  /// only a Save / Nothing there starts the tick animation and the
  /// completion. Backing out leaves the job untouched.
  Future<void> _startComplete() async {
    if (_completing || _asking) return;
    _asking = true;
    final result = await showDoneDialog(context);
    _asking = false;
    if (result == null || !mounted) return;
    _result = result;
    setState(() => _completing = true);
  }

  void _onCheckDrawn() {
    if (!mounted) return;
    _collapse.forward();
  }

  void _fire() {
    if (!mounted || _fired) return;
    _fired = true;
    final result = _result;
    if (result != null) widget.onDone(result);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final now = DateTime.now();
    final overdue = task.isOverdue(now);
    final color = categoryColor(task.category);
    final card = NkCard(
      onTap: _completing ? null : widget.onTap,
      color: _completing
          ? NkColors.green
              .withValues(alpha: context.isDark ? 0.22 : 0.12)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(categoryIcon(task.category), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: context.navyText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dueLabel(task, now)}'
                  '${widget.minutes != null ? ' · ~${widget.minutes} min' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: overdue ? NkColors.red : context.muted,
                    fontWeight: overdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (_completing)
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnimatedCheck(size: 36, onCompleted: _onCheckDrawn),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 28),
              color: NkColors.green,
              tooltip: 'Mark done',
              onPressed: _startComplete,
            ),
        ],
      ),
    );
    return SizeTransition(
      sizeFactor: _shrink,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: card),
      ),
    );
  }
}

/// The Next up card. Mark done opens the same done dialog as every
/// other completion path (build 23); on a confirm the same tick
/// plays in place of the buttons before the completion is applied.
/// When the following task takes over, the content cross-fades
/// instead of snapping.
class _NextUpCard extends StatefulWidget {
  final TaskInstance task;
  final int? minutes;
  final DateTime now;
  final VoidCallback onTap;
  final Future<void> Function(TaskInstance, DoneResult) onDone;
  final VoidCallback onLater;

  const _NextUpCard({
    required this.task,
    required this.minutes,
    required this.now,
    required this.onTap,
    required this.onDone,
    required this.onLater,
  });

  @override
  State<_NextUpCard> createState() => _NextUpCardState();
}

class _NextUpCardState extends State<_NextUpCard> {
  bool _completing = false;
  bool _fired = false;
  bool _asking = false;
  DoneResult? _result;

  @override
  void didUpdateWidget(_NextUpCard old) {
    super.didUpdateWidget(old);
    // A different task slid into the Next up slot (the completed one
    // rolled forward): start its card fresh.
    if (old.task.id != widget.task.id ||
        old.task.dueDate != widget.task.dueDate) {
      _completing = false;
      _fired = false;
      _result = null;
    }
  }

  /// Mark done asks first (build 23), like every quick tick: the
  /// done dialog opens, and only a confirm starts the animation
  /// and the completion.
  Future<void> _startComplete() async {
    if (_completing || _asking) return;
    _asking = true;
    final result = await showDoneDialog(context);
    _asking = false;
    if (result == null || !mounted) return;
    _result = result;
    setState(() => _completing = true);
  }

  void _onCheckDrawn() {
    if (!mounted || _fired) return;
    _fired = true;
    final result = _result;
    if (result != null) widget.onDone(widget.task, result);
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.task;
    return NkCard(
      onTap: _completing ? null : widget.onTap,
      color: _completing
          ? NkColors.green.withValues(alpha: context.isDark ? 0.22 : 0.12)
          : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Column(
          key: ValueKey(next.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXT UP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: context.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              next.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.navyText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${dueLabel(next, widget.now)}'
              '${widget.minutes != null ? ' · ~${widget.minutes} min' : ''}',
              style: TextStyle(fontSize: 13.5, color: context.muted),
            ),
            const SizedBox(height: 12),
            if (_completing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedCheck(size: 44, onCompleted: _onCheckDrawn),
                    const SizedBox(width: 10),
                    Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.navyText,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _startComplete,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        textStyle: const TextStyle(fontSize: 15),
                      ),
                      child: const Text('Mark done'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onLater,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        textStyle: const TextStyle(fontSize: 15),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Scales its child with a small bounce (1.0 -> 1.06 -> 1.0) whenever
/// [value] increases: the Completed card's way of showing a finished
/// task landing in the done list.
class _BounceOnIncrease extends StatefulWidget {
  final int value;
  final Widget child;

  const _BounceOnIncrease({required this.value, required this.child});

  @override
  State<_BounceOnIncrease> createState() => _BounceOnIncreaseState();
}

class _BounceOnIncreaseState extends State<_BounceOnIncrease>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: 1.06)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.06, end: 1)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 60,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(_BounceOnIncrease old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// One finished job, the way Plan's Completed section shows it: green
/// check, title, when it was done and what it cost. Shared with the
/// Plan calendar so a done job looks the same wherever it lands.
class DoneTaskCard extends StatelessWidget {
  final TaskInstance task;

  const DoneTaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final t = task;
    return NkCard(
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
                        fontWeight: FontWeight.w600, color: context.navyText)),
                Text(
                  'Done ${t.doneDate == null ? '' : '${t.doneDate!.month}/${t.doneDate!.day}/${t.doneDate!.year}'}'
                  '${t.costPaid != null && t.costPaid! > 0 ? ' · ${money(t.costPaid!)}' : ''}'
                  '${(t.doneBy ?? '').isNotEmpty ? ' · by ${t.doneBy}' : ''}',
                  style: TextStyle(fontSize: 13, color: context.muted),
                ),
                if ((t.doneNote ?? '').isNotEmpty)
                  Text(
                    t.doneNote!,
                    style: TextStyle(fontSize: 13, color: context.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
