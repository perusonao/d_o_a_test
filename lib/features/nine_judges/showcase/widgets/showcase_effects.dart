import 'dart:math';

import 'package:flutter/material.dart';

/// Section ③/④/⑤/⑨ of the recruitment-video request: reusable, self-playing
/// visual effects layered as `Stack` overlays by demo_showcase_screen.dart.
/// Kept restrained (a few colors, thin strokes) to match the app's existing
/// dark-gold "高級感" look (see widgets/game_style.dart) rather than a
/// generic bright effects pack.

/// Expanding blue ripple rings + a light beam toward [targetAlignment] —
/// "EYEで情報を見ている" (section ③). Plays once over [duration] then stays
/// on its last frame (the caller removes it from the tree when done).
class EyeRippleEffect extends StatefulWidget {
  const EyeRippleEffect({
    required this.duration,
    this.targetAlignment = Alignment.center,
    super.key,
  });

  final Duration duration;
  final Alignment targetAlignment;

  @override
  State<EyeRippleEffect> createState() => _EyeRippleEffectState();
}

class _EyeRippleEffectState extends State<EyeRippleEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _EyeRipplePainter(
          progress: _controller.value,
          targetAlignment: widget.targetAlignment,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _EyeRipplePainter extends CustomPainter {
  _EyeRipplePainter({required this.progress, required this.targetAlignment});
  final double progress;
  final Alignment targetAlignment;

  static const _blue = Color(0xFF55B3FF);

  @override
  void paint(Canvas canvas, Size size) {
    final center = targetAlignment.alongSize(size);
    for (var ring = 0; ring < 3; ring++) {
      final ringProgress = (progress - ring * 0.15).clamp(0.0, 1.0);
      if (ringProgress <= 0) continue;
      final radius = ringProgress * size.shortestSide * 0.28;
      final opacity = (1 - ringProgress) * 0.7;
      final paint = Paint()
        ..color = _blue.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius, paint);
    }
    final beamOpacity = (1 - progress) * 0.5;
    if (beamOpacity > 0) {
      final beamPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            _blue.withValues(alpha: 0),
            _blue.withValues(alpha: beamOpacity),
          ],
        ).createShader(Rect.fromPoints(Offset(center.dx, 0), center))
        ..strokeWidth = 6;
      canvas.drawLine(Offset(center.dx, 0), center, beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EyeRipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Gold shockwave ring + screen shake — "JUDGEで運命を確定" (section ④), the
/// showcase's flashiest moment. Wrap the whole scene in [JudgeShake] and
/// overlay this on top at the same time.
class JudgeShockwaveEffect extends StatefulWidget {
  const JudgeShockwaveEffect({required this.duration, super.key});
  final Duration duration;

  @override
  State<JudgeShockwaveEffect> createState() => _JudgeShockwaveEffectState();
}

class _JudgeShockwaveEffectState extends State<JudgeShockwaveEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          CustomPaint(painter: _ShockwavePainter(progress: _controller.value), size: Size.infinite),
    ),
  );
}

class _ShockwavePainter extends CustomPainter {
  _ShockwavePainter({required this.progress});
  final double progress;

  static const _gold = Color(0xFFC7A24C);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = progress * size.shortestSide * 0.75;
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = _gold.withValues(alpha: opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 + 4 * (1 - progress);
    canvas.drawCircle(center, radius, paint);
    // A soft radial flash at the very start of the shockwave.
    if (progress < 0.3) {
      final flashOpacity = (0.3 - progress) / 0.3 * 0.35;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _gold.withValues(alpha: flashOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Wraps [child] in a brief screen-shake — section ④/⑨'s "画面揺れ", kept
/// small so it reads as impact rather than a glitch.
class JudgeShake extends StatefulWidget {
  const JudgeShake({required this.child, required this.duration, super.key});
  final Widget child;
  final Duration duration;

  @override
  State<JudgeShake> createState() => _JudgeShakeState();
}

class _JudgeShakeState extends State<JudgeShake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = _controller.value;
      final decay = (1 - t);
      final dx = sin(t * pi * 10) * 6 * decay;
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
    child: widget.child,
  );
}

/// Gold/confetti particle burst — victory (section ⑤) or a bonus-score
/// moment. Colors default to gold; pass [colors] for a multi-color confetti
/// look.
class ParticleBurstEffect extends StatefulWidget {
  const ParticleBurstEffect({
    required this.duration,
    this.colors = const [Color(0xFFC7A24C)],
    this.particleCount = 36,
    super.key,
  });

  final Duration duration;
  final List<Color> colors;
  final int particleCount;

  @override
  State<ParticleBurstEffect> createState() => _ParticleBurstEffectState();
}

class _Particle {
  _Particle(Random random, List<Color> colors)
    : angle = random.nextDouble() * 2 * pi,
      speed = 0.3 + random.nextDouble() * 0.7,
      size = 4 + random.nextDouble() * 5,
      color = colors[random.nextInt(colors.length)],
      spin = random.nextDouble() * 4 - 2;

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
}

class _ParticleBurstEffectState extends State<ParticleBurstEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final List<_Particle> _particles = [
    for (var i = 0; i < widget.particleCount; i++) _Particle(Random(i * 7919 + 1), widget.colors),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _ParticlePainter(progress: _controller.value, particles: _particles),
        size: Size.infinite,
      ),
    ),
  );
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress, required this.particles});
  final double progress;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.4);
    final maxDistance = size.shortestSide * 0.6;
    for (final particle in particles) {
      final travel = progress * particle.speed;
      final distance = travel * maxDistance;
      final gravity = progress * progress * size.height * 0.35;
      final dx = origin.dx + cos(particle.angle) * distance;
      final dy = origin.dy + sin(particle.angle) * distance + gravity;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = particle.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(particle.spin * progress * pi);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: particle.size, height: particle.size * 1.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}

/// Centered two-line caption ("EYE" / "属性を確認") with a fade+scale-in,
/// used by both the EYE and JUDGE spotlight beats.
class EffectCaption extends StatefulWidget {
  const EffectCaption({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.duration,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Duration duration;

  @override
  State<EffectCaption> createState() => _EffectCaptionState();
}

class _EffectCaptionState extends State<EffectCaption> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value;
      final appear = (t / 0.25).clamp(0.0, 1.0);
      final fade = t > 0.75 ? (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0) : 1.0;
      final scale = 0.85 + 0.15 * appear;
      return Center(
        child: Opacity(
          opacity: appear * fade,
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                border: Border.all(color: widget.accent, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.accent,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A gentle zoom-in on [child] — section ⑨'s "軽いズーム / カード拡大", kept
/// subtle (max ~1.12x) to stay "高級感" rather than a cartoonish punch-in.
class CameraZoom extends StatefulWidget {
  const CameraZoom({
    required this.child,
    required this.duration,
    this.maxScale = 1.12,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final double maxScale;

  @override
  State<CameraZoom> createState() => _CameraZoomState();
}

class _CameraZoomState extends State<CameraZoom> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: widget.maxScale), weight: 1),
    TweenSequenceItem(tween: Tween(begin: widget.maxScale, end: widget.maxScale), weight: 2),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
    child: widget.child,
  );
}
