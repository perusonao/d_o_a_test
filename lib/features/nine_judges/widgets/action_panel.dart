import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/card_assets.dart';
import 'package:flutter/material.dart';

/// Bottom action bar. LIFE / DEATH carry their own normal/SPECIAL status, so
/// the player never has to reconcile two buttons with the same action name.
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
        if (controller.phase == TurnPhase.selectingActionTarget) ...[
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
          // Player feedback: "一撃ジャッジが生死ついてないとこしか打てないのを
          // 理解してから、ゲームが分かりました" — spelling out *which* states
          // are legal right next to the button, not just relying on the
          // board's own dim/bright per-card treatment.
          if (controller.selectedAction == ActionType.specialVerdict)
            const _JudgeTargetLegend(),
        ],
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
                  child: _ActionButton(
                    controller: controller,
                    action: action,
                    asReverse: action == _reverseAction,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          width: double.infinity,
          child: _ActionButton(
            controller: controller,
            action: ActionType.specialVerdict,
            compact: true,
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

  /// Marks the faction's opposite LIFE/DEATH as its one-use SPECIAL action.
  final bool asReverse;

  @override
  Widget build(BuildContext context) {
    final faction = controller.currentPlayer;
    final enabled =
        controller.canSelectAction(action) ||
        controller.canSwitchAction(action);
    final selected = controller.selectedAction == action;
    final eyeRemaining = action == ActionType.eye
        ? controller.eyeUsesRemaining(faction)
        : null;
    final used = asReverse
        ? !controller.reverseActionAvailable(faction)
        : action == ActionType.specialVerdict
        ? !controller.specialVerdictAvailable(faction)
        : eyeRemaining == 0;
    final colors = _colors(action);
    final title = action.label;
    final subtitle = _subtitle(used, eyeRemaining: eyeRemaining);
    final iconAsset = CardAssets.actionIcon(action);

    // Stacking icon+title above the subtitle (rather than cramming both into
    // one row) means neither short line ever needs to be ellipsized, even for
    // the longer "SPECIAL DEATH" / "SPECIAL LIFE" labels.
    final content = compact
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Glyph(iconAsset, action: action, size: 18),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
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
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Glyph(iconAsset, action: action, size: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  if (asReverse) ...[
                    const SizedBox(width: 4),
                    Container(
                      key: Key('special-badge-${action.name}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: .7),
                        ),
                      ),
                      child: const Text(
                        'SPECIAL',
                        style: TextStyle(
                          fontSize: 6,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ],
                ],
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

    // Disabled buttons get a flat, neutral-grey frame (not just a faded
    // version of their colour) so "can't tap this" reads at a glance instead
    // of looking like a dim-but-still-colourful active button.
    final borderColor = selected
        ? Colors.white
        : enabled
        ? colors.accent
        : const Color(0x33FFFFFF);
    final tintAmount = selected
        ? .4
        : enabled
        ? .16
        : 0.0;

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
              Color.lerp(colors.background, colors.accent, tintAmount)!,
              colors.background,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: selected ? 2.1 : 1.1),
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

  String _subtitle(bool used, {int? eyeRemaining}) {
    if (used) return '使用済み';
    if (asReverse) return '1回限定・残り1回';
    // JUDGE and the special (reverse) action are always rendered compact;
    // keep their status short so it never risks truncation.
    if (compact) return '残り1回';
    if (action == ActionType.eye && eyeRemaining != null) {
      return '残り$eyeRemaining回';
    }
    return switch (action) {
      ActionType.life => '命を与える',
      ActionType.death => '死を与える',
      ActionType.eye => '正体を見る',
      ActionType.specialVerdict => '残り1回',
    };
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
}

/// Section (this round): a one-glance "which cards can I actually pick"
/// legend shown only while JUDGE is the selected action — the board itself
/// already dims illegal targets (see person_card_widget.dart), but nothing
/// used to label what bright vs. dim *means* until now.
class _JudgeTargetLegend extends StatelessWidget {
  const _JudgeTargetLegend();

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('judge-target-legend'),
    padding: const EdgeInsets.only(bottom: 4),
    child: const Row(
      children: [
        _LegendChip(
          color: Color(0xFFFFD76A),
          icon: Icons.check_circle,
          label: '審議中：使用できる',
        ),
        SizedBox(width: 10),
        _LegendChip(
          color: Color(0xFF8A8272),
          icon: Icons.block,
          label: 'それ以外：使用できない',
        ),
      ],
    ),
  );
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.asset, {required this.action, required this.size});
  final String asset;
  final ActionType action;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: Key('action-icon-area-${action.name}'),
    width: size,
    height: size,
    child: Center(
      // act_eye.png is already clipped at its source canvas' top edge. Use a
      // complete vector eye in the same fixed stage rather than scaling a
      // permanently truncated bitmap.
      child: action == ActionType.eye
          ? Icon(
              Icons.visibility_outlined,
              key: const Key('action-eye-icon-complete'),
              size: size * .88,
              color: AppTheme.eye,
            )
          : Image.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Icon(Icons.circle, size: size),
            ),
    ),
  );
}
