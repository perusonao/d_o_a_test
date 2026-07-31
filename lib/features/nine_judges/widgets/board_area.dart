import 'package:dead_or_alive/features/nine_judges/effects/card_action_effect.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';
import 'package:flutter/material.dart';

/// The 3x3 board as the hero of the screen: portrait cards sized to fill the
/// available space, framed by row numbers (1..3) down the left and column
/// letters (A..C) along the bottom — the coordinate scheme the mockup uses.
class BoardArea extends StatelessWidget {
  const BoardArea({
    required this.controller,
    required this.onTargetTap,
    this.effectIndex,
    this.effectAction,
    this.effectSerial = 0,
    this.onEffectDone,
    super.key,
  });

  final NineJudgesController controller;
  final ValueChanged<int> onTargetTap;

  /// Section ④: the board slot (if any) currently showing a brief,
  /// non-blocking LIFE/DEATH/EYE flash (see [CardActionEffect]) — set by
  /// the real game screen right after that action resolves, cleared again
  /// via [onEffectDone] once the flash finishes on its own. [effectSerial]
  /// changes on every trigger (even a repeat of the same slot/action) so the
  /// effect widget always remounts and restarts instead of being reused.
  final int? effectIndex;
  final ActionType? effectAction;
  final int effectSerial;
  final VoidCallback? onEffectDone;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const gap = GameMetrics.cardGap;
      final gridMaxW = c.maxWidth - GameMetrics.rowGutter;
      final gridMaxH = c.maxHeight - GameMetrics.colGutter;
      // Fill the width, then fall back to a height cap so all nine cards fit.
      var cellW = (gridMaxW - gap * 2) / 3;
      var cellH = cellW / GameMetrics.cardAspect;
      if (cellH * 3 + gap * 2 > gridMaxH) {
        cellH = (gridMaxH - gap * 2) / 3;
        cellW = cellH * GameMetrics.cardAspect;
      }
      final gridW = cellW * 3 + gap * 2;
      final gridH = cellH * 3 + gap * 2;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RowNumbers(cellH: cellH, gap: gap, height: gridH),
                SizedBox(
                  width: gridW,
                  height: gridH,
                  child: GridView.builder(
                    key: const Key('nine-judges-board'),
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: gap,
                      mainAxisSpacing: gap,
                      childAspectRatio: cellW / cellH,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) => _card(index),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            _ColumnLetters(cellW: cellW, gap: gap, width: gridW),
          ],
        ),
      );
    },
  );

  Widget _card(int index) {
    final person = controller.board[index].person;
    final viewer = controller.uiViewer;
    // Only JUDGE gets a tap-through on an illegal target — see
    // person_card_widget.dart's `allowTapWhenDisabled` doc comment for why:
    // a tap on any other action's illegal target still silently does
    // nothing, unchanged from before.
    final judgeTargeting =
        controller.phase == TurnPhase.selectingActionTarget &&
        controller.selectedAction == ActionType.specialVerdict;
    final card = PersonCardWidget(
      person: person,
      coordinate: controller.positionLabel(index),
      attributeVisible: controller.knowsAttribute(person, viewer),
      viewerEyeKnown: controller.eyeKnowsAttribute(index, viewer),
      opponentEyeKnown: controller.eyeKnowsAttribute(index, viewer.opponent),
      viewerLabel: controller.isCpuGame ? 'YOU' : viewer.label,
      opponentLabel: controller.isCpuGame ? 'CPU' : viewer.opponent.label,
      selected: controller.selectedSlot == index,
      cpuHighlighted: controller.lastCpuTargetIndex == index,
      enabled: controller.canTarget(index),
      targeting: controller.phase == TurnPhase.selectingActionTarget,
      allowTapWhenDisabled: judgeTargeting,
      onTap: () => onTargetTap(index),
    );
    if (index != effectIndex || effectAction == null) return card;
    return Stack(
      children: [
        card,
        Positioned.fill(
          child: CardActionEffect(
            key: ValueKey('card-effect-$effectSerial'),
            action: effectAction!,
            onDone: onEffectDone ?? () {},
          ),
        ),
      ],
    );
  }
}

class _RowNumbers extends StatelessWidget {
  const _RowNumbers({
    required this.cellH,
    required this.gap,
    required this.height,
  });
  final double cellH;
  final double gap;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: GameMetrics.rowGutter,
    height: height,
    child: Column(
      children: [
        for (var r = 0; r < 3; r++) ...[
          if (r > 0) SizedBox(height: gap),
          SizedBox(
            height: cellH,
            child: Center(child: _CoordLabel('${r + 1}')),
          ),
        ],
      ],
    ),
  );
}

class _ColumnLetters extends StatelessWidget {
  const _ColumnLetters({
    required this.cellW,
    required this.gap,
    required this.width,
  });
  final double cellW;
  final double gap;
  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: GameMetrics.rowGutter),
    child: SizedBox(
      width: width,
      height: GameMetrics.colGutter - 2,
      child: Row(
        children: [
          for (var col = 0; col < 3; col++) ...[
            if (col > 0) SizedBox(width: gap),
            SizedBox(
              width: cellW,
              child: Center(child: _CoordLabel(String.fromCharCode(65 + col))),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CoordLabel extends StatelessWidget {
  const _CoordLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: GameColors.gold,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
    ),
  );
}
