import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class ActionPanel extends StatelessWidget {
  const ActionPanel({required this.controller, super.key});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == TurnPhase.selectingEyeInformation) {
      final options = controller.availableEyeInformation(
        controller.selectedSlot!,
        controller.currentPlayer,
      );
      return Column(
        key: const Key('eye-information-picker'),
        children: [
          const Text('何を確認しますか？', style: TextStyle(fontSize: 11)),
          Row(
            children: [
              if (options.contains(EyeInformation.attribute))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => controller.revealEyeInformation(
                      EyeInformation.attribute,
                    ),
                    child: const Text('属性を見る'),
                  ),
                ),
              if (options.length == 2) const SizedBox(width: 5),
              if (options.contains(EyeInformation.number))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        controller.revealEyeInformation(EyeInformation.number),
                    child: const Text('数字を見る'),
                  ),
                ),
            ],
          ),
          TextButton(
            onPressed: controller.cancelEyeInformation,
            child: const Text('キャンセル'),
          ),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            for (final action in const [
              ActionType.life,
              ActionType.death,
              ActionType.eye,
            ]) ...[
              Expanded(
                child: _ActionCard(controller: controller, action: action),
              ),
              if (action != ActionType.eye) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            key: const Key('judge-button'),
            onPressed: controller.canSelectAction(ActionType.judge)
                ? () => controller.chooseAction(ActionType.judge)
                : null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: const Color(0xFF29251D),
              disabledForegroundColor: Colors.white30,
              backgroundColor: const Color(0xFFD6B25E),
              foregroundColor: const Color(0xFF171208),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
                side: BorderSide(
                  color: controller.selectedAction == ActionType.judge
                      ? const Color(0xFFFFDF86)
                      : const Color(0xFFD6B25E),
                  width: controller.selectedAction == ActionType.judge ? 2 : 1,
                ),
              ),
              elevation: controller.canSelectAction(ActionType.judge) ? 5 : 0,
              padding: EdgeInsets.zero,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.balance, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'JUDGE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Text('現在の生死で判決', style: TextStyle(fontSize: 9, height: 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.controller, required this.action});

  final NineJudgesController controller;
  final ActionType action;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedAction == action;
    final enabled = controller.canSelectAction(action);
    final remaining = controller.currentInventory.remaining(action);
    final color = _color(action);
    return SizedBox(
      height: 59,
      child: Material(
        color: enabled
            ? color.withValues(alpha: 0.16)
            : const Color(0xFF18191C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(
            color: selected
                ? const Color(0xFFFFD76A)
                : enabled
                ? color.withValues(alpha: 0.8)
                : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: Key('action-${action.name}'),
          onTap: enabled ? () => controller.chooseAction(action) : null,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _icon(action),
                      size: 17,
                      color: enabled ? color : Colors.white30,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      action.label,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white30,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  _effect(action),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? Colors.white70 : Colors.white24,
                    fontSize: 8,
                  ),
                ),
                Text(
                  '残り $remaining',
                  style: TextStyle(
                    color: remaining == 0
                        ? Colors.redAccent
                        : const Color(0xFFD6B25E),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _icon(ActionType action) => switch (action) {
    ActionType.life => Icons.volunteer_activism,
    ActionType.death => Icons.dangerous_outlined,
    ActionType.eye => Icons.visibility_outlined,
    ActionType.judge => Icons.balance,
  };

  String _effect(ActionType action) => switch (action) {
    ActionType.life => '蘇生 / 防護',
    ActionType.death => '死亡 / 即確定',
    ActionType.eye => '秘密を見る',
    ActionType.judge => '現在の生死で判決',
  };

  Color _color(ActionType action) => switch (action) {
    ActionType.life => const Color(0xFF64D58A),
    ActionType.death => const Color(0xFFF0645A),
    ActionType.eye => const Color(0xFF9B83E6),
    ActionType.judge => const Color(0xFFD6B25E),
  };
}
