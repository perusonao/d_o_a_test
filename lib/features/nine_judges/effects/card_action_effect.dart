import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';

/// Section ④: a brief (~550ms), non-blocking flash over the target card the
/// instant a LIFE/DEATH/EYE action resolves during real play — LIFE glows
/// white-gold, DEATH sends out a dark-purple shockwave, EYE pulses a
/// blue-white ripple to draw the eye toward the just-revealed card. Wrapped
/// in [IgnorePointer] and never awaited by the caller, so it can never delay
/// the next turn or intercept a tap — unlike [SpecialVerdictOverlay]/the
/// plain confirmation overlay in game_screen.dart, which deliberately block
/// until dismissed, this widget is purely decorative and self-dismissing.
class CardActionEffect extends StatefulWidget {
  const CardActionEffect({required this.action, required this.onDone, super.key});

  final ActionType action;
  final VoidCallback onDone;

  @override
  State<CardActionEffect> createState() => _CardActionEffectState();
}

class _CardActionEffectState extends State<CardActionEffect>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 550);
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _duration)..forward();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _CardActionPainter(progress: _controller.value, action: widget.action),
        size: Size.infinite,
      ),
    ),
  );
}

class _CardActionPainter extends CustomPainter {
  _CardActionPainter({required this.progress, required this.action});
  final double progress;
  final ActionType action;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    switch (action) {
      case ActionType.life:
        _paintGlow(canvas, size, center, GameColors.life);
      case ActionType.death:
        _paintShockwave(canvas, size, center, GameColors.death);
      case ActionType.eye:
        _paintRipple(canvas, size, center, GameColors.eye);
      case ActionType.specialVerdict:
        break;
    }
  }

  void _paintGlow(Canvas canvas, Size size, Offset center, Color color) {
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final radius = size.shortestSide * (0.35 + 0.25 * progress);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity * 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + 10 * progress),
    );
  }

  void _paintShockwave(Canvas canvas, Size size, Offset center, Color color) {
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final radius = progress * size.shortestSide * 0.6;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 + 3 * (1 - progress),
    );
    if (progress < 0.35) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = color.withValues(alpha: (0.35 - progress) / 0.35 * 0.3),
      );
    }
  }

  void _paintRipple(Canvas canvas, Size size, Offset center, Color color) {
    for (var ring = 0; ring < 2; ring++) {
      final ringProgress = (progress - ring * 0.25).clamp(0.0, 1.0);
      if (ringProgress <= 0) continue;
      final radius = ringProgress * size.shortestSide * 0.45;
      final opacity = (1 - ringProgress) * 0.65;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CardActionPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.action != action;
}
