import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class HandStatusPanel extends StatelessWidget {
  const HandStatusPanel({required this.controller, super.key});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 25,
    child: Row(
      children: [
        Expanded(child: _status(Faction.savior)),
        const SizedBox(width: 6),
        Expanded(child: _status(Faction.executor)),
      ],
    ),
  );

  Widget _status(Faction faction) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      '${faction.label}　審判 '
      '${controller.specialVerdictAvailable(faction) ? '1' : '使用済み'}',
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
    ),
  );
}
