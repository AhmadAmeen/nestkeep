import 'package:flutter/material.dart';

import '../theme.dart';

/// A green disc in which a white tick draws itself: the disc pops in
/// over the first 40% of the run, the tick strokes over the rest.
/// Plays once when inserted; [onCompleted] fires when the drawing is
/// done, so callers can chain what happens next (collapse, pop, ...).
class AnimatedCheck extends StatefulWidget {
  final double size;
  final VoidCallback? onCompleted;

  const AnimatedCheck({super.key, this.size = 54, this.onCompleted});

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onCompleted?.call();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _AnimatedCheckPainter(_controller.value),
      ),
    );
  }
}

class _AnimatedCheckPainter extends CustomPainter {
  final double progress;

  _AnimatedCheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Phase 1 (0 -> 0.4): the disc scales and fades in, with a small
    // overshoot so it lands with a pop.
    final discT =
        Curves.easeOutBack.transform((progress / 0.4).clamp(0.0, 1.0));
    if (discT > 0) {
      final paint = Paint()
        ..color = NkColors.green.withValues(alpha: discT.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          center, (size.width / 2) * (0.55 + 0.45 * discT), paint);
    }

    // Phase 2 (0.4 -> 1): the tick path draws itself, short stroke
    // first, then the long rising stroke.
    final tickT = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    if (tickT > 0) {
      final path = Path()
        ..moveTo(size.width * 0.30, size.height * 0.53)
        ..lineTo(size.width * 0.44, size.height * 0.67)
        ..lineTo(size.width * 0.71, size.height * 0.36);
      final metric = path.computeMetrics().first;
      final partial = metric.extractPath(0, metric.length * tickT);
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(partial, paint);
    }
  }

  @override
  bool shouldRepaint(_AnimatedCheckPainter old) => old.progress != progress;
}
