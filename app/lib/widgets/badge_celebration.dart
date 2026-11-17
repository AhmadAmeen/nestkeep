import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../badges.dart';
import '../theme.dart';

/// The full-screen celebration shown once when a badge is earned: the
/// badge springs in inside a gold ring, a short confetti burst goes off
/// behind it, and the badge's own line explains what just happened.
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

class _BadgeCelebrationOverlayState extends State<BadgeCelebrationOverlay>
    with TickerProviderStateMixin {
  static const _goldLight = Color(0xFFF6C453);
  static const _goldDeep = Color(0xFFE8A33D);

  late final AnimationController _scale;
  late final AnimationController _confetti;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
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
    _scale.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final iconColor = badge.isProBadge ? _goldDeep : context.primary;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim backdrop; tapping it dismisses, like tapping anywhere.
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
          // Confetti burst, behind the badge, above the backdrop.
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
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
                          child: Icon(badge.icon, size: 52, color: iconColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'BADGE EARNED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color:
                          Color.lerp(context.primary, Colors.white, 0.35),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    badge.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.blurb,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.5,
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 30),
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
        ],
      ),
    );
  }
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
