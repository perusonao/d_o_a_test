import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';
import 'package:flutter/material.dart';

class BoardGrid extends StatelessWidget {
  const BoardGrid({
    required this.controller,
    this.showScores = false,
    super.key,
  });
  final NineJudgesController controller;
  final bool showScores;

  @override
  Widget build(BuildContext context) => GridView.builder(
    key: const Key('nine-judges-board'),
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 5,
      mainAxisSpacing: 5,
      childAspectRatio: .88,
    ),
    itemCount: 9,
    itemBuilder: (context, index) {
      final person = controller.board[index].person;
      return PersonCardWidget(
        person: person,
        attributeVisible: controller.knowsAttribute(
          person,
          controller.currentPlayer,
        ),
        attributeEyeKnown: controller.eyeKnowsAttribute(
          index,
          controller.currentPlayer,
        ),
        selected: controller.selectedSlot == index,
        cpuHighlighted: controller.lastCpuTargetIndex == index,
        enabled: controller.canTarget(index),
        onTap: () => controller.selectSlot(index),
        scoreDetail: showScores ? controller.score.slotScores[person.id] : null,
      );
    },
  );
}
