import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Score breakdown: the health score split per category (area), worst
/// first, each with its score and the plain reason behind it. A short
/// card at the top explains how the scoring works.
class ScoreDetailScreen extends StatelessWidget {
  final AppState state;

  const ScoreDetailScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final health = state.health;
    final areas = state.healthByCategory;
    return Scaffold(
      appBar: AppBar(title: const Text('Score breakdown')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          NkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How this works',
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: context.navyText),
                ),
                const SizedBox(height: 8),
                Text(
                  'An area is one part of the home on your plan, like HVAC, Plumbing or Safety. Each one gets its own score here.',
                  style: TextStyle(color: context.muted, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every area starts at 100. An overdue job takes points off its area, safety jobs and costly-to-ignore jobs the most, and the longer a job waits, the more it loses. A job due in the next two weeks takes a point off too.',
                  style: TextStyle(color: context.muted, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  'Finishing a job puts its points straight back.',
                  style: TextStyle(color: context.muted, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  'The big score on Today is not an average of these areas. It uses the same rules across the whole home at once.',
                  style: TextStyle(color: context.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          NkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall ${health.score} · grade ${health.grade}',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.navyText),
                ),
                const SizedBox(height: 4),
                Text(
                  health.statusSentence,
                  style: TextStyle(color: context.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeading('By area'),
          const SizedBox(height: 10),
          if (areas.isEmpty)
            NkCard(
              child: Text('No jobs on the plan yet.',
                  style: TextStyle(color: context.muted)),
            ),
          for (final a in areas) ...[
            NkCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          categoryColor(a.category).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(categoryIcon(a.category),
                        color: categoryColor(a.category), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.category,
                            style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: context.navyText)),
                        Text(a.reason,
                            style:
                                TextStyle(fontSize: 13, color: context.muted)),
                      ],
                    ),
                  ),
                  Text(
                    '${a.score}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: a.score >= 70
                          ? NkColors.green
                          : a.score >= 50
                              ? NkColors.amber
                              : NkColors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(a.grade,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.muted)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
