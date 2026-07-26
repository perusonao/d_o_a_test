import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class ActionPanel extends StatelessWidget {
  const ActionPanel({required this.controller, super.key});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (controller.currentPlayer == Faction.savior) ActionType.life,
      if (controller.currentPlayer == Faction.executor) ActionType.death,
      ActionType.eye,
      ActionType.specialVerdict,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(child: _button(actions[i])),
              ],
            ],
          ),
        ),
        if (controller.phase == TurnPhase.selectingActionTarget)
          SizedBox(
            height: 24,
            child: TextButton.icon(
              key: const Key('cancel-action'),
              onPressed: controller.cancelActionSelection,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.close, size: 13),
              label: const Text('選択解除', style: TextStyle(fontSize: 10)),
            ),
          ),
      ],
    );
  }

  Widget _button(ActionType action) {
    final enabled =
        controller.canSelectAction(action) ||
        controller.canSwitchAction(action);
    final selected = controller.selectedAction == action;
    final subtitle = switch (action) {
      ActionType.life => '生を与える',
      ActionType.death => '死を与える',
      ActionType.eye => '属性を調査',
      ActionType.specialVerdict => controller.specialVerdictStatus(
        controller.currentPlayer,
      ),
    };
    return Material(
      color: selected ? const Color(0xFF493B1D) : const Color(0xFF201D18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: selected ? const Color(0xFFFFD76A) : const Color(0xFF806A36),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        key: Key('action-${action.name}'),
        onTap: enabled ? () => controller.chooseAction(action) : null,
        child: Opacity(
          opacity: enabled || selected ? 1 : .35,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                action.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(subtitle, style: const TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}
