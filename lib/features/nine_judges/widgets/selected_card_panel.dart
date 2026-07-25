import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';

class SelectedCardPanel extends StatelessWidget {
  const SelectedCardPanel({required this.controller, super.key});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final index = controller.selectedSlot;
    if (index == null) {
      return const SizedBox(height: 20);
    }
    final slot = controller.board[index];
    final person = slot.person;
    final attribute =
        controller.knowsAttribute(person, controller.currentPlayer)
        ? person.attribute.label
        : '?';
    return SizedBox(
      height: 20,
      child: Center(
        child: Text(
          '$attribute${person.rank} ｜ ${person.isAlive ? '生' : '死'} ｜ '
          '${person.hasLifeShield
              ? 'LIFE防護あり'
              : person.isJudged
              ? '判決済み'
              : '未判決'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
