import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class ActionPanel extends StatelessWidget {
  const ActionPanel({required this.controller, super.key});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (controller.currentPlayer == Faction.savior) ...[
        ActionType.life,
        ActionType.death,
      ] else ...[
        ActionType.death,
        ActionType.life,
      ],
      ActionType.eye,
      ActionType.specialVerdict,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 58,
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
      ActionType.life =>
        controller.isReverseAction(action, controller.currentPlayer)
            ? controller.reverseActionAvailable(controller.currentPlayer)
                  ? '●1'
                  : '使用済み'
            : '生へ',
      ActionType.death =>
        controller.isReverseAction(action, controller.currentPlayer)
            ? controller.reverseActionAvailable(controller.currentPlayer)
                  ? '●1'
                  : '使用済み'
            : '死へ',
      ActionType.eye => '属性を調査',
      ActionType.specialVerdict =>
        controller.specialVerdictAvailable(controller.currentPlayer)
            ? '残り1'
            : '使用済み',
    };
    final color = switch (action) {
      ActionType.life => const Color(0xFF173723),
      ActionType.death => const Color(0xFF421D1D),
      ActionType.eye => const Color(0xFF29204A),
      ActionType.specialVerdict => const Color(0xFF493B1D),
    };
    final accent = switch (action) {
      ActionType.life => const Color(0xFF68D893),
      ActionType.death => const Color(0xFFF0645A),
      ActionType.eye => const Color(0xFF9B83E8),
      ActionType.specialVerdict => const Color(0xFFFFD76A),
    };
    final icon = switch (action) {
      ActionType.life => Icons.favorite_outline,
      ActionType.death => Icons.close,
      ActionType.eye => Icons.visibility_outlined,
      ActionType.specialVerdict => Icons.gavel,
    };
    return Material(
      color: selected ? Color.lerp(color, Colors.white, .12) : color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: selected ? Colors.white : accent,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: accent),
                  const SizedBox(width: 2),
                  Text(
                    action.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(subtitle, style: const TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }
}
