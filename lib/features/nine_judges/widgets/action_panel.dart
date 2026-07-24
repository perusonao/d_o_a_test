import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class ActionPanel extends StatelessWidget {
  const ActionPanel({required this.controller, super.key});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final judgeReady = controller.phase == TurnPhase.awaitingJudge;
    final selectingJudge = controller.phase == TurnPhase.selectingJudgeTarget;
    return Column(
      children: [
        Row(
          children: [
            for (final action in ActionType.values) ...[
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
            onPressed: judgeReady ? controller.beginJudge : null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: const Color(0xFF29251D),
              disabledForegroundColor: Colors.white30,
              backgroundColor: const Color(0xFFD6B25E),
              foregroundColor: const Color(0xFF171208),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
                side: BorderSide(
                  color: selectingJudge
                      ? const Color(0xFFFFDF86)
                      : const Color(0xFFD6B25E),
                  width: selectingJudge ? 2 : 1,
                ),
              ),
              elevation: judgeReady ? 5 : 0,
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
                Text('この人物の生死を確定する', style: TextStyle(fontSize: 9, height: 1)),
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
  };

  String _effect(ActionType action) => switch (action) {
    ActionType.life => '蘇生 / 防護',
    ActionType.death => '死亡 / 即確定',
    ActionType.eye => '数字を見る',
  };

  Color _color(ActionType action) => switch (action) {
    ActionType.life => const Color(0xFF64D58A),
    ActionType.death => const Color(0xFFF0645A),
    ActionType.eye => const Color(0xFF9B83E6),
  };
}
