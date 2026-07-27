import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/card_assets.dart';
import 'package:flutter/material.dart';

/// Bottom action bar. Mirrors the mockup: a LIFE / DEATH / EYE trio on top and
/// the two one-shot actions (JUDGE and the reverse action) underneath.
class ActionPanel extends StatelessWidget {
  const ActionPanel({required this.controller, super.key});

  final NineJudgesController controller;

  ActionType get _reverseAction => controller.currentPlayer == Faction.savior
      ? ActionType.death
      : ActionType.life;

  @override
  Widget build(BuildContext context) {
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
          height: 64,
          child: Row(
            children: [
              for (final action in const [
                ActionType.life,
                ActionType.death,
                ActionType.eye,
              ]) ...[
                if (action != ActionType.life) const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(controller: controller, action: action),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  controller: controller,
                  action: ActionType.specialVerdict,
                  compact: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  controller: controller,
                  action: _reverseAction,
                  compact: true,
                  asReverse: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.controller,
    required this.action,
    this.compact = false,
    this.asReverse = false,
  });

  final NineJudgesController controller;
  final ActionType action;
  final bool compact;

  /// Renders the reverse-action shortcut (bottom row) rather than a plain
  /// verdict button, so it can carry its own label and one-shot status.
  final bool asReverse;

  @override
  Widget build(BuildContext context) {
    final faction = controller.currentPlayer;
    final enabled =
        controller.canSelectAction(action) ||
        controller.canSwitchAction(action);
    final selected = controller.selectedAction == action;
    final used = asReverse
        ? !controller.reverseActionAvailable(faction)
        : action == ActionType.specialVerdict
        ? !controller.specialVerdictAvailable(faction)
        : false;
    final colors = _colors(asReverse ? ActionType.eye : action);
    final title = asReverse ? '逆転アクション' : action.label;
    final subtitle = _subtitle(used);
    final iconAsset = asReverse
        ? CardAssets.reverseIcon
        : CardAssets.actionIcon(action);

    final content = compact
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Glyph(iconAsset, size: 22),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: used ? Colors.white54 : colors.accent,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Glyph(iconAsset, size: 26),
              Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: used ? Colors.white54 : colors.accent,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

    return Semantics(
      label: '$title $subtitle',
      button: true,
      enabled: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(colors.background, colors.accent, selected ? .4 : .16)!,
              colors.background,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
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
            key: Key('action-${asReverse ? 'reverse' : action.name}'),
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? () => controller.chooseAction(action) : null,
            child: Opacity(
              opacity: enabled || selected ? 1 : .4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(bool used) {
    if (used) return '✓ 使用済み';
    if (asReverse) return '残り1回';
    return switch (action) {
      ActionType.life => '命を与える',
      ActionType.death => '死を与える',
      ActionType.eye => '正体を見る',
      ActionType.specialVerdict => '即時裁定  •  残り1回',
    };
  }

  ({Color background, Color accent}) _colors(ActionType value) => switch (value) {
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
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.asset, {required this.size});
  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => Icon(Icons.circle, size: size),
  );
}
