import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

/// Section②'s "得点・勝敗": a compact, always-visible score readout so a
/// viewer can see points land the instant a scripted action confirms
/// someone — the real game screen's own score display is a private widget
/// there, so this is a small, promo-only readout built from the same
/// public [NineJudgesController.scores], never a copy of game rules/UI.
class PromoScoreBanner extends StatelessWidget {
  const PromoScoreBanner({required this.controller, super.key});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _score('救済者', controller.scores[Faction.savior] ?? 0, const Color(0xFFF2E0A8)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '-',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                _score('執行者', controller.scores[Faction.executor] ?? 0, const Color(0xFFB388FF)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _score(String label, int value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(color: color, fontSize: 10)),
      Text(
        '$value',
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}
