import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';

class BoardGrid extends StatelessWidget {
  const BoardGrid({
    required this.controller,
    this.showScores = false,
    super.key,
  });

  final NineJudgesController controller;
  final bool showScores;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 3; column++) ...[
                  Expanded(child: _card(row * 3 + column)),
                  if (column < 2) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          if (row < 2) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _card(int index) {
    final slot = controller.board[index];
    return PersonCardWidget(
      key: Key('judge-slot-$index'),
      slot: slot,
      attributeVisible: controller.knowsAttribute(
        slot.person,
        controller.currentPlayer,
      ),
      numberVisible: controller.knowsNumber(index, controller.currentPlayer),
      selected: controller.selectedSlot == index,
      enabled: controller.canTarget(index),
      onTap: () => controller.selectSlot(index),
      scoreDetail: showScores
          ? controller.score.slotScores[slot.person.id]
          : null,
    );
  }
}
