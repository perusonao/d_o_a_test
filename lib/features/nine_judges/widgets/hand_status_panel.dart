import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class HandStatusPanel extends StatelessWidget {
  const HandStatusPanel({required this.controller, super.key});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final me = controller.isCpuGame
        ? controller.humanFaction
        : controller.currentPlayer;
    return Column(
      children: [
        _HandRow(
          key: const Key('own-hand'),
          label: controller.isCpuGame ? 'あなた' : me.label,
          hand: controller.inventoryFor(me),
          remainingActions: controller.actionsRemainingFor(me),
        ),
        _HandRow(
          key: const Key('opponent-hand'),
          label: controller.isCpuGame ? 'CPU' : me.opponent.label,
          hand: controller.inventoryFor(me.opponent),
          remainingActions: controller.actionsRemainingFor(me.opponent),
        ),
      ],
    );
  }
}

class _HandRow extends StatelessWidget {
  const _HandRow({
    required this.label,
    required this.hand,
    required this.remainingActions,
    super.key,
  });
  final String label;
  final ActionInventory hand;
  final int remainingActions;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 18,
    child: Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            '$label 残り$remainingActions手',
            key: Key('remaining-actions-$label'),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
        _count('LIFE', hand.life, const Color(0xFF64D58A)),
        _count('DEATH', hand.death, const Color(0xFFF0645A)),
        _count('EYE', hand.eye, const Color(0xFF9B83E6)),
        _count('JUDGE', hand.judge, const Color(0xFFD6B25E)),
      ],
    ),
  );

  Widget _count(String name, int value, Color color) => Expanded(
    child: Text(
      '$name $value',
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
    ),
  );
}
