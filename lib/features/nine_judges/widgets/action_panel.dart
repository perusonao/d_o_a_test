import 'package:dead_or_alive/app/theme.dart';
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
        if (controller.phase == TurnPhase.selectingActionTarget)
          SizedBox(
            height: 22,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${controller.selectedAction?.label}の対象を選択',
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('cancel-action'),
                  onPressed: controller.cancelActionSelection,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.close, size: 12),
                  label: const Text('解除', style: TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(child: _ActionButton(controller, actions[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.controller, this.action);

  final NineJudgesController controller;
  final ActionType action;

  @override
  Widget build(BuildContext context) {
    final enabled =
        controller.canSelectAction(action) ||
        controller.canSwitchAction(action);
    final selected = controller.selectedAction == action;
    final reverse = controller.isReverseAction(
      action,
      controller.currentPlayer,
    );
    final used = reverse
        ? !controller.reverseActionAvailable(controller.currentPlayer)
        : action == ActionType.specialVerdict
        ? !controller.specialVerdictAvailable(controller.currentPlayer)
        : false;
    final colors = _colors(action);
    final subtitle = used
        ? '✓ 使用済み'
        : reverse
        ? 'SPECIAL ●1'
        : action == ActionType.specialVerdict
        ? '残り1回'
        : switch (action) {
            ActionType.life => '命を与える',
            ActionType.death => '死を与える',
            ActionType.eye => '正体を見る',
            ActionType.specialVerdict => '',
          };

    return Semantics(
      label: '${action.label} $subtitle',
      button: true,
      enabled: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                colors.background,
                colors.accent,
                selected ? .38 : .16,
              )!,
              colors.background,
            ],
          ),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? Colors.white : colors.accent,
            width: selected ? 2.1 : 1.1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: colors.accent.withValues(alpha: .4),
                blurRadius: 10,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('action-${action.name}'),
            borderRadius: BorderRadius.circular(9),
            onTap: enabled ? () => controller.chooseAction(action) : null,
            child: Opacity(
              opacity: enabled || selected ? 1 : .38,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icon(action), size: 17, color: colors.accent),
                    Text(
                      action.label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .3,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: used ? Colors.white54 : colors.accent,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ({Color background, Color accent}) _colors(ActionType value) =>
      switch (value) {
        ActionType.life => (
          background: const Color(0xFF092B36),
          accent: const Color(0xFF55D9ED),
        ),
        ActionType.death => (
          background: const Color(0xFF3B1115),
          accent: AppTheme.executor,
        ),
        ActionType.eye => (
          background: const Color(0xFF281445),
          accent: AppTheme.eye,
        ),
        ActionType.specialVerdict => (
          background: const Color(0xFF332713),
          accent: const Color(0xFFFFD76A),
        ),
      };

  IconData _icon(ActionType value) => switch (value) {
    ActionType.life => Icons.favorite,
    ActionType.death => Icons.dangerous,
    ActionType.eye => Icons.visibility,
    ActionType.specialVerdict => Icons.balance,
  };
}
