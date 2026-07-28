import 'package:dead_or_alive/features/nine_judges/showcase/widgets/showcase_effects.dart';
import 'package:flutter/material.dart';

/// Section ⑤: win/loss screen — confetti + big score for a win, a red
/// flash + dim for a loss/draw, so the outcome reads instantly.
class ResultBannerView extends StatelessWidget {
  const ResultBannerView({
    required this.winnerLabel,
    required this.isPlayerWin,
    required this.saviorScore,
    required this.executorScore,
    required this.duration,
    super.key,
  });

  final String winnerLabel;
  final bool isPlayerWin;
  final int saviorScore;
  final int executorScore;
  final Duration duration;

  static const _gold = Color(0xFFC7A24C);
  static const _red = Color(0xFFE0554F);

  @override
  Widget build(BuildContext context) {
    final accent = isPlayerWin ? _gold : _red;
    return Container(
      color: const Color(0xFF06070C),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isPlayerWin)
            ParticleBurstEffect(
              duration: duration,
              colors: const [_gold, Colors.white, Color(0xFFE8D9A8)],
              particleCount: 48,
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 0),
              duration: duration,
              builder: (context, value, _) => Container(
                color: _red.withValues(alpha: value),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPlayerWin ? 'WINNER' : 'GAME SET',
                style: TextStyle(
                  color: accent,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                winnerLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '救済者 $saviorScore  -  $executorScore 執行者',
                style: const TextStyle(color: Colors.white70, fontSize: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section ⑥: rating screen, enlarged with a thank-you message. Shown as a
/// mocked/illustrative rating (the showcase never submits a real playtest).
class RatingShowcaseView extends StatelessWidget {
  const RatingShowcaseView({super.key});

  static const _blue = Color(0xFF55B3FF);
  static const _gold = Color(0xFFC7A24C);

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF06070C),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '今回のプレイはいかがでしたか？',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 36),
        _stars('楽しさ', 4),
        const SizedBox(height: 24),
        _stars('再プレイ意向', 5),
        const SizedBox(height: 36),
        const Text(
          'ご協力ありがとうございます！',
          style: TextStyle(color: _blue, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _stars(String label, int filled) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 16)),
      const SizedBox(height: 8),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              i < filled ? Icons.star : Icons.star_border,
              color: _gold,
              size: 40,
            ),
        ],
      ),
    ],
  );
}
