import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../badges.dart';
import '../theme.dart';

/// The full-screen celebration shown once when a badge is earned: the
/// badge springs in inside a gold ring, overlapping the top edge of an
/// opaque panel that carries every word of the celebration, and a short
/// confetti burst goes off behind the panel. Nothing is drawn over the
/// raw screen, so the text can never collide with the page behind it.
/// Shown by the Shell, one at a time, from AppState.pendingCelebrations.
class BadgeCelebrationOverlay extends StatefulWidget {
  final BadgeResult badge;
  final VoidCallback onDismiss;

  const BadgeCelebrationOverlay({
    super.key,
    required this.badge,
    required this.onDismiss,
  });

  @override
  State<BadgeCelebrationOverlay> createState() =>
      _BadgeCelebrationOverlayState();
}

const _goldLight = Color(0xFFF6C453);
const _goldDeep = Color(0xFFE8A33D);

class _BadgeCelebrationOverlayState extends State<BadgeCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    // A fixed seed keeps the burst the same shape on every run, so the
    // painter never has to guess whether a particle moved.
    final rng = math.Random(11);
    _particles = [for (var i = 0; i < 64; i++) _Particle.random(rng)];
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim backdrop; tapping it dismisses.
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.60)),
            ),
          ),
          // Confetti burst, behind the panel, above the backdrop.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    progress: _confetti.value,
                    particles: _particles,
                    palette: [
                      context.primary,
                      _goldLight,
                      Colors.white,
                      _goldDeep,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: BadgePanel(badge: widget.badge, onDismiss: widget.onDismiss),
          ),
        ],
      ),
    );
  }
}

/// The celebration's panel itself: the badge circle springing in
/// over the top edge of the opaque card that carries the words.
/// Shared by the earn-moment overlay above and by the badge detail
/// dialog (build 24: tapping an earned badge in Profile reopens
/// this same panel, without the confetti).
class BadgePanel extends StatefulWidget {
  final BadgeResult badge;
  final VoidCallback onDismiss;

  const BadgePanel({super.key, required this.badge, required this.onDismiss});

  @override
  State<BadgePanel> createState() => _BadgePanelState();
}

class _BadgePanelState extends State<BadgePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final iconColor = badge.isProBadge ? _goldDeep : context.primary;
    return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The opaque panel: every word of the celebration
                    // lives on this solid card, so nothing can collide
                    // with the screen behind it. The top margin leaves
                    // room for the badge circle to overlap the edge.
                    Container(
                      margin: const EdgeInsets.only(top: 55),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? NkColors.darkCard
                            : NkColors.lightCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.line),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: context.isDark ? 0.45 : 0.22),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 71, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'BADGE EARNED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.2,
                                color: context.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              badge.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: context.navyText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              badge.blurb,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: context.muted,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: widget.onDismiss,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 44, vertical: 14),
                              ),
                              child: const Text('Nice'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The badge circle, overlapping the panel's top edge.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _scale,
                            curve: Curves.elasticOut,
                          ),
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_goldLight, _goldDeep],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _goldDeep.withValues(alpha: 0.45),
                                  blurRadius: 34,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.isDark
                                      ? NkColors.darkCard
                                      : Colors.white,
                                ),
                                child: Icon(badge.icon,
                                    size: 52, color: iconColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

/// Show one earned badge's detail (build 24): the same panel as
/// the earn moment — circle art, name, description — in a dialog,
/// without the confetti. Used when a badge on the Profile shelf is
/// tapped. The dialog's own backdrop dims the screen; the panel
/// carries its card styling itself.
Future<void> showBadgeDetail(BuildContext context, BadgeResult badge) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: BadgePanel(
        badge: badge,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    ),
  );
}

/// One confetti piece: a radial burst from the badge, pulled down by
/// gravity, swaying and spinning as it falls. [slot] picks the colour
/// from the painter's palette.
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final int slot;
  final double swayPhase;
  final double swayAmp;
  final double spin;
  final bool circle;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.slot,
    required this.swayPhase,
    required this.swayAmp,
    required this.spin,
    required this.circle,
  });

  factory _Particle.random(math.Random rng) => _Particle(
        angle: rng.nextDouble() * math.pi * 2,
        speed: 120 + rng.nextDouble() * 260,
        size: 5 + rng.nextDouble() * 6,
        slot: rng.nextInt(4),
        swayPhase: rng.nextDouble() * math.pi * 2,
        swayAmp: 6 + rng.nextDouble() * 16,
        spin: (rng.nextDouble() - 0.5) * 9,
        circle: rng.nextBool(),
      );
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final List<Color> palette;

  _ConfettiPainter({
    required this.progress,
    required this.particles,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2.2; // seconds since the burst
    final origin = Offset(size.width / 2, size.height * 0.40);
    final fade = progress < 0.7 ? 1.0 : 1.0 - (progress - 0.7) / 0.3;
    final paint = Paint();
    for (final p in particles) {
      final x = origin.dx +
          math.cos(p.angle) * p.speed * t +
          math.sin(t * 3 + p.swayPhase) * p.swayAmp * t;
      final y = origin.dy + math.sin(p.angle) * p.speed * t + 260 * t * t;
      if (y > size.height + 20) continue;
      paint.color =
          palette[p.slot].withValues(alpha: fade.clamp(0.0, 1.0).toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + p.spin * t);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.62),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
