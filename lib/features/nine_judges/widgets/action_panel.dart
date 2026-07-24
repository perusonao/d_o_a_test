import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class ActionPanel extends StatelessWidget {
  const ActionPanel({required this.controller, super.key});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final selectingJudge = controller.phase == TurnPhase.selectingJudgeTarget;
    return Column(
      children: [
        Row(
          children: [
            for (final action in ActionType.values) ...[
              Expanded(
                child: SizedBox(
                  height: 48,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          action.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${_shortEffect(action)} ｜ 残り ${controller.currentInventory.remaining(action)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (action != ActionType.eye) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: FilledButton(
            key: const Key('judge-button'),
            onPressed: controller.phase == TurnPhase.awaitingJudge
                ? controller.beginJudge
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: selectingJudge
                  ? const Color(0xFFD6B25E)
                  : const Color(0xFF66552D),
              foregroundColor: Colors.black,
            ),
            child: Text(selectingJudge ? '判決する人物を選択' : 'JUDGEしてターン終了'),
          ),
        ),
      ],
    );
  }

  String _shortEffect(ActionType action) => switch (action) {
    ActionType.life => '蘇生 / 防護',
    ActionType.death => '死亡 / 即確定',
    ActionType.eye => '数字を見る',
  };
}
