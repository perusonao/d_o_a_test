import 'dart:math';

import 'package:flutter/material.dart';

/// Section ①/②: the opening ~2s of the showcase — big logo, gold glow,
/// drifting gold particles, then a short catch-copy line. Plays once; the
/// screen swaps it out for the live board once [onCatchCopyShown] fires.
class TitleSplashView extends StatefulWidget {
  const TitleSplashView({
    required this.titleDuration,
    required this.catchCopyDuration,
    required this.catchCopy,
    this.onTitleShown,
    this.onCatchCopyShown,
    super.key,
  });

  final Duration titleDuration;
  final Duration catchCopyDuration;
  final String catchCopy;
  final VoidCallback? onTitleShown;
  final VoidCallback? onCatchCopyShown;

  @override
  State<TitleSplashView> createState() => _TitleSplashViewState();
}

class _TitleSplashViewState extends State<TitleSplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.titleDuration + widget.catchCopyDuration,
  )..forward();
  late final List<_GoldParticle> _particles = [
    for (var i = 0; i < 24; i++) _GoldParticle(Random(i * 104729 + 3)),
  ];
  bool _catchCopyFired = false;

  double get _catchCopyStart =>
      widget.titleDuration.inMilliseconds /
      (widget.titleDuration + widget.catchCopyDuration).inMilliseconds;

  @override
  void initState() {
    super.initState();
    widget.onTitleShown?.call();
  }

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
      if (!_catchCopyFired && t >= _catchCopyStart) {
        _catchCopyFired = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onCatchCopyShown?.call(),
        );
      }
      final logoAppear = (t / 0.3).clamp(0.0, 1.0);
      final catchCopyLocalT = ((t - _catchCopyStart) / (1 - _catchCopyStart))
          .clamp(0.0, 1.0);

      return Container(
        color: const Color(0xFF06070C),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              painter: _GoldParticlePainter(t: t, particles: _particles),
              size: Size.infinite,
            ),
            Opacity(
              opacity: logoAppear,
              child: Transform.scale(
                scale: 0.9 + 0.1 * logoAppear,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFC7A24C,
                            ).withValues(alpha: 0.55 * logoAppear),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/branding/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '9人の審判',
                      style: TextStyle(
                        color: Color(0xFFC7A24C),
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'NINE VERDICTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (catchCopyLocalT > 0)
              Positioned(
                bottom: 140,
                child: Opacity(
                  opacity: catchCopyLocalT < 0.7
                      ? (catchCopyLocalT / 0.3).clamp(0.0, 1.0)
                      : 1.0,
                  child: Text(
                    widget.catchCopy,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _GoldParticle {
  _GoldParticle(Random random)
    : x = random.nextDouble(),
      startY = random.nextDouble(),
      speed = 0.05 + random.nextDouble() * 0.1,
      radius = 1.5 + random.nextDouble() * 2.5,
      phase = random.nextDouble();

  final double x;
  final double startY;
  final double speed;
  final double radius;
  final double phase;
}

class _GoldParticlePainter extends CustomPainter {
  _GoldParticlePainter({required this.t, required this.particles});
  final double t;
  final List<_GoldParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFC7A24C).withValues(alpha: 0.55);
    for (final particle in particles) {
      final y = (particle.startY - t * particle.speed) % 1.0;
      final wobble = sin((t + particle.phase) * 2 * pi) * 0.01;
      final dx = (particle.x + wobble) * size.width;
      final dy = y * size.height;
      canvas.drawCircle(Offset(dx, dy), particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GoldParticlePainter oldDelegate) => oldDelegate.t != t;
}
