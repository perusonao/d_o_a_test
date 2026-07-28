import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Section ⑦: the final 2-3s "テストプレイヤー募集中" card — the whole point
/// of the showcase, so it needs to read clearly even paused on a single
/// frame (a viewer scrubbing the video should be able to screenshot this).
class RecruitmentCardView extends StatelessWidget {
  const RecruitmentCardView({required this.gameUrl, super.key});

  final String gameUrl;

  static const _gold = Color(0xFFC7A24C);

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF06070C),
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Rule(),
        const SizedBox(height: 18),
        const Text('🧑‍⚖️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        const Text(
          'テストプレイヤー募集中',
          style: TextStyle(
            color: _gold,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        const _Rule(),
        const SizedBox(height: 20),
        const _CheckLine('ブラウザですぐ遊べます'),
        const _CheckLine('1ゲーム約5分'),
        const _CheckLine('あなたの意見でゲームが進化します'),
        const SizedBox(height: 20),
        const _Rule(),
        const SizedBox(height: 20),
        Text(
          gameUrl,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: QrImageView(
            data: gameUrl,
            version: QrVersions.auto,
            size: 150,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const _Rule(),
      ],
    ),
  );
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check, color: Color(0xFF4FCB84), size: 20),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 17)),
      ],
    ),
  );
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 220,
    child: Divider(color: RecruitmentCardView._gold, thickness: 1),
  );
}
