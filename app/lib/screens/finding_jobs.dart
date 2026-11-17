import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The "Finding jobs for you" moment shown just before the job picker,
/// in onboarding and from Plan -> Choose jobs alike. A short staged
/// checklist ticks itself in over about 3.5 seconds — the big-app feel
/// of work being done for you — then [onDone] fires exactly once.
/// All timers are cancelled on dispose, so leaving early is safe.
class FindingJobsView extends StatefulWidget {
  final VoidCallback onDone;

  const FindingJobsView({super.key, required this.onDone});

  /// The staged checklist lines, in the order they tick in.
  static const lines = [
    'Looking at your home\'s systems',
    'Matching jobs to your home',
    'Estimating times and costs',
  ];

  /// Total time on screen before [onDone] fires.
  static const totalDuration = Duration(milliseconds: 3500);

  @override
  State<FindingJobsView> createState() => _FindingJobsViewState();
}

class _FindingJobsViewState extends State<FindingJobsView> {
  final List<Timer> _timers = [];
  int _doneCount = 0;

  @override
  void initState() {
    super.initState();
    // One line ticks in roughly every second; a short beat after the
    // last check lands, hand over to the picker.
    for (var i = 0; i < FindingJobsView.lines.length; i++) {
      _timers.add(Timer(Duration(milliseconds: 1000 * (i + 1)), () {
        if (mounted) setState(() => _doneCount = i + 1);
      }));
    }
    _timers.add(Timer(FindingJobsView.totalDuration, () {
      if (mounted) widget.onDone();
    }));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon.png', width: 88, height: 88),
            const SizedBox(height: 26),
            Text(
              'Finding jobs for you',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: context.navyText,
              ),
            ),
            const SizedBox(height: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < FindingJobsView.lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: _indicator(context, i, accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            FindingJobsView.lines[i],
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: i <= _doneCount
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: i <= _doneCount
                                  ? context.navyText
                                  : context.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Spinner while a line is being "worked on", a check once it is
  /// done, a hollow circle while it waits its turn.
  Widget _indicator(BuildContext context, int i, Color accent) {
    if (i < _doneCount) {
      return Icon(Icons.check_circle, size: 22, color: accent);
    }
    if (i == _doneCount) {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
      );
    }
    return Icon(Icons.circle_outlined, size: 22, color: context.line);
  }
}
