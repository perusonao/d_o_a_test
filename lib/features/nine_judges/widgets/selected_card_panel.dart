import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class SelectedCardPanel extends StatelessWidget {
  const SelectedCardPanel({required this.controller, super.key});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final index = controller.selectedSlot;
    return SizedBox(
      height: 23,
      child: Center(
        child: Text(
          controller.phase == TurnPhase.selectingActionTarget
              ? '${controller.selectedAction!.label}の対象を選択中'
              : index == null
              ? '人物とアクションを選択してください'
              : '${controller.positionLabel(index)}の人物を選択中',
          style: const TextStyle(fontSize: 9, color: Colors.white54),
        ),
      ),
    );
  }
}
