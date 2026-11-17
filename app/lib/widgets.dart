import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'lifespan.dart';
import 'models.dart';
import 'theme.dart';

/// Shared building blocks in the approved card language: white (or dark
/// navy) rounded cards, generous padding, one job per element.

class NkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? accentLeft;

  /// Optional card background override (e.g. the light green tint a
  /// task card wears while its completion animation plays). Null keeps
  /// the theme's card colour.
  final Color? color;

  const NkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accentLeft,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: padding, child: child),
      ),
    );
    final Widget inner;
    if (accentLeft == null) {
      inner = card;
    } else {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accentLeft),
            Expanded(child: card),
          ],
        ),
      );
    }
    // A soft shadow under every card: subtle depth, kept light so dense
    // screens still read calm. Navy in light mode, black in dark.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : NkColors.lightNavy)
                .withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: inner,
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeading(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: context.navyText,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

/// The thick health ring with score + grade in the middle.
class HealthRing extends StatelessWidget {
  final int score;
  final String grade;
  final double size;

  const HealthRing({super.key, required this.score, required this.grade, this.size = 132});

  /// A healthy home (grade A or B) wears the user's app colour; a home
  /// that needs work keeps the warning colours, amber then red.
  Color _colorFor(BuildContext context) {
    if (grade == 'A' || grade == 'B') return context.primary;
    if (score >= 50) return NkColors.amber;
    return NkColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(score: score, color: color, track: context.line),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w800,
                  color: context.navyText,
                  height: 1,
                ),
              ),
              Text(
                grade,
                style: TextStyle(
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int score;
  final Color color;
  final Color track;

  _RingPainter({required this.score, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.105;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * (score / 100),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.score != score || old.color != color || old.track != track;
}

/// The small pill that says where an appliance is in its life:
/// Good shape / Monitor / Replace soon, in the band's colour.
class LifeChip extends StatelessWidget {
  final LifeStatus status;

  const LifeChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = lifeStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        lifeStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// The appliance life bar: fraction of expected life used, in the
/// status colour, on the standard track.
class LifeBar extends StatelessWidget {
  final Appliance appliance;
  final DateTime now;
  final double height;

  const LifeBar(
      {super.key, required this.appliance, required this.now, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final used = lifeUsed(appliance, now);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: used.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        backgroundColor: context.line,
        valueColor: AlwaysStoppedAnimation(
            lifeStatusColor(lifeStatus(appliance, now))),
      ),
    );
  }
}

/// The life bar plus its labels, as the appliance card wears it:
/// always on the card, dated or not. With no purchase date there is
/// no clock to show, so the track sits empty and the label says what
/// is missing instead of faking a percentage.
class ApplianceLifeSection extends StatelessWidget {
  final Appliance appliance;
  final DateTime now;

  const ApplianceLifeSection(
      {super.key, required this.appliance, required this.now});

  @override
  Widget build(BuildContext context) {
    final hasDate = appliance.purchaseDate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LifeBar(appliance: appliance, now: now, height: 6),
        const SizedBox(height: 5),
        if (hasDate)
          Row(
            children: [
              Expanded(
                child: Text(
                  lifeLabel(appliance, now),
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ),
              Text(
                lifeLeftLabel(appliance, now),
                style: TextStyle(fontSize: 12, color: context.muted),
              ),
            ],
          )
        else
          Text(
            'Add a purchase date to see its life',
            style: TextStyle(fontSize: 12, color: context.muted),
          ),
      ],
    );
  }
}

/// The owner's condition tag on an appliance card: a filled chip in
/// the condition's colour once set, a quiet outlined "Set condition"
/// until then. Tapping it opens [showConditionSheet]; the chip owns
/// its tap so the card underneath does not also navigate.
class ConditionChip extends StatelessWidget {
  final String? condition;
  final VoidCallback onTap;

  const ConditionChip({super.key, required this.condition, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final set = condition != null;
    final color = set ? conditionColor(condition!) : context.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: set ? color.withValues(alpha: 0.14) : null,
            border: set ? null : Border.all(color: context.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!set) ...[
                Icon(Icons.add, size: 12, color: color),
                const SizedBox(width: 3),
              ],
              Text(
                set ? conditionLabel(condition!) : 'Set condition',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The condition picker: the four tags plus "Not set" to clear.
/// [onSave] receives the picked value (null clears) and owns the
/// actual write; the sheet closes once the save lands.
Future<void> showConditionSheet(
  BuildContext context, {
  required String? current,
  required Future<void> Function(String? condition) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Six rows do not fit the default sheet height on short screens.
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How is it doing?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ctx.navyText)),
                const SizedBox(height: 2),
                Text('Your call, from looking at the machine.',
                    style: TextStyle(fontSize: 13, color: ctx.muted)),
              ],
            ),
          ),
          for (final value in conditionValues)
            ListTile(
              leading: Icon(Icons.circle, size: 14, color: conditionColor(value)),
              title: Text(conditionLabel(value)),
              trailing: current == value
                  ? const Icon(Icons.check, size: 19)
                  : null,
              onTap: () async {
                await onSave(value);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ListTile(
            leading: Icon(Icons.circle_outlined,
                size: 14, color: ctx.muted),
            title: const Text('Not set'),
            trailing:
                current == null ? const Icon(Icons.check, size: 19) : null,
            onTap: () async {
              await onSave(null);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'HVAC':
      return Icons.thermostat;
    case 'Plumbing':
      return Icons.water_drop_outlined;
    case 'Roof & Gutters':
      return Icons.roofing_outlined;
    case 'Exterior':
      return Icons.house_outlined;
    case 'Interior':
      return Icons.weekend_outlined;
    case 'Safety':
      return Icons.shield_outlined;
    case 'Appliances':
      return Icons.kitchen_outlined;
    case 'Seasonal':
      return Icons.calendar_month_outlined;
    default:
      return Icons.task_alt;
  }
}

Color categoryColor(String category) {
  switch (category) {
    case 'HVAC':
      return const Color(0xFFEF7D1A);
    case 'Plumbing':
      // Indigo, in the purple accent family (was the old royal blue
      // #2456D6 before build 11 unified the palette).
      return const Color(0xFF5457E8);
    case 'Roof & Gutters':
      return const Color(0xFF7A5AF8);
    case 'Exterior':
      return const Color(0xFF1FA97A);
    case 'Interior':
      return const Color(0xFFD6336C);
    case 'Safety':
      return const Color(0xFFE5484D);
    case 'Appliances':
      return const Color(0xFF0CA678);
    case 'Seasonal':
      return const Color(0xFFF5A623);
    default:
      return const Color(0xFF5A6B8A);
  }
}

String dueLabel(TaskInstance t, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
  final days = due.difference(today).inDays;
  if (days < 0) return 'Overdue by ${-days}d';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days <= 30) return 'In $days days';
  final months = (days / 30).round();
  return months <= 1 ? 'In about a month' : 'In about $months months';
}

String money(double v) {
  if (v == v.roundToDouble()) return '\$${v.toStringAsFixed(0)}';
  return '\$${v.toStringAsFixed(2)}';
}

/// Tips rotate deterministically by ISO week so every user sees the same
/// tip in the same week and it changes weekly.
const weeklyTips = [
  'A \$15 furnace filter changed on time can cut heating energy use by 5 to 15 percent.',
  'Know where your main water shut-off valve is before you ever need it. A burst pipe loses a bathtub of water every few minutes.',
  'Test smoke and CO alarms monthly. Most failures are just dead batteries.',
  'Take a photo of every appliance nameplate. Model and serial numbers are gold when ordering parts.',
  'Clean dryer vents once a year. Lint build-up is a leading cause of house fires.',
  'Run water in rarely used drains monthly. Dry traps let sewer gas into the house.',
  'Keep receipts for big purchases in one place. Warranty claims live or die on proof of purchase date.',
  'Seal one drafty window each fall. A tube of caulk costs a few dollars and pays back in one season.',
  'Check under every sink twice a year. Slow drips quietly rot cabinets and floors.',
  'Label your breaker panel properly once. Future you, standing in the dark, says thanks.',
];

String tipOfTheWeek(DateTime now) {
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  final week = (dayOfYear / 7).floor();
  return weeklyTips[week % weeklyTips.length];
}
