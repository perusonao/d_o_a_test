import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
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
          index == null
              ? '人物を選択してください'
              : '${controller.board[index].person.verdictState.label} / '
                    '介入${controller.board[index].person.verdictActionCount}回',
          style: const TextStyle(fontSize: 9, color: Colors.white54),
        ),
      ),
    );
  }
}
