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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 5.0;
      final itemWidth = (constraints.maxWidth - gap * 2) / 3;
      final itemHeight = (constraints.maxHeight - gap * 2) / 3;
      final ratio = itemHeight > 0 ? itemWidth / itemHeight : 1.0;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x52050508),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x44C8A34A)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: GridView.builder(
            key: const Key('nine-judges-board'),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: ratio,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              final person = controller.board[index].person;
              final viewer = controller.uiViewer;
              return PersonCardWidget(
                person: person,
                coordinate: controller.positionLabel(index),
                attributeVisible: controller.knowsAttribute(person, viewer),
                viewerEyeKnown: controller.eyeKnowsAttribute(index, viewer),
                opponentEyeKnown: controller.eyeKnowsAttribute(
                  index,
                  viewer.opponent,
                ),
                viewerLabel: controller.isCpuGame ? 'YOU' : viewer.label,
                opponentLabel: controller.isCpuGame
                    ? 'CPU'
                    : viewer.opponent.label,
                selected: controller.selectedSlot == index,
                cpuHighlighted: controller.lastCpuTargetIndex == index,
                enabled: controller.canTarget(index),
                onTap: () => controller.selectSlot(index),
                scoreDetail: showScores
                    ? controller.score.slotScores[person.id]
                    : null,
              );
            },
          ),
        ),
      );
    },
  );
}
