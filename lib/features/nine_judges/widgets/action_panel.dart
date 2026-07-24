import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class ActionPanel extends StatelessWidget {
  const ActionPanel({required this.controller, super.key});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final selectingSave = controller.phase == TurnPhase.selectingSave;
    return Column(
      children: [
        Row(
          children: [
            for (final action in ActionType.values) ...[
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    key: Key('action-${action.name}'),
                    onPressed: controller.canSelectAction(action)
                        ? () => controller.chooseAction(action)
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: controller.selectedAction == action
                          ? const BorderSide(color: Color(0xFFD6B25E), width: 2)
                          : null,
                    ),
                    child: Text(
                      '${action.label} ${controller.currentInventory.remaining(action)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
              if (action != ActionType.judge) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: FilledButton(
            key: const Key('save-button'),
            onPressed:
                controller.phase == TurnPhase.awaitingSave ||
                    (!NineJudgesConfig.forceSaveEachTurn &&
                        controller.phase == TurnPhase.selectingAction)
                ? controller.beginSave
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: selectingSave
                  ? const Color(0xFFD6B25E)
                  : const Color(0xFF66552D),
              foregroundColor: Colors.black,
            ),
            child: Text(selectingSave ? 'SAVE対象を選択中' : 'SAVEしてターン終了'),
          ),
        ),
        if (!NineJudgesConfig.forceSaveEachTurn) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: TextButton(
              onPressed: controller.phase == TurnPhase.awaitingSave
                  ? controller.endTurnWithoutSave
                  : null,
              child: const Text('SAVEせずターン終了'),
            ),
          ),
        ],
      ],
    );
  }
}
