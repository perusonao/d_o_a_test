import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/person_card_widget.dart';
import 'package:flutter/material.dart';

class BoardGrid extends StatefulWidget {
  const BoardGrid({
    required this.controller,
    this.showScores = false,
    this.onTargetTap,
    this.spotlightIndex,
    this.spotlightLabel,
    super.key,
  });
  final NineJudgesController controller;
  final bool showScores;
  final ValueChanged<int>? onTargetTap;

  /// Section ②(tutorial): when set, [spotlightIndex]'s card is glow-bordered
  /// and gets a "ここをタップ" callout, while every other card dims — used
  /// only by the tutorial to make the one correct target unmissable. `null`
  /// (the default, used everywhere else — ResultScreen, real gameplay) keeps
  /// rendering exactly as before.
  final int? spotlightIndex;
  final String? spotlightLabel;

  @override
  State<BoardGrid> createState() => _BoardGridState();
}

class _BoardGridState extends State<BoardGrid>
    with SingleTickerProviderStateMixin {
  // Assigned eagerly in initState (not a lazy `late final` initializer) —
  // otherwise, whenever spotlightIndex stays null for this widget's whole
  // life, `_pulse` is never touched until dispose() reads it there for the
  // first time, constructing an AnimationController (and looking up
  // TickerMode via the widget's context) after the element is already
  // deactivated, which throws.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.spotlightIndex != null) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant BoardGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final spotlighting = widget.spotlightIndex != null;
    if (spotlighting && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!spotlighting && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 5.0;
      final itemWidth = (constraints.maxWidth - gap * 2) / 3;
      final itemHeight = (constraints.maxHeight - gap * 2) / 3;
      final ratio = itemHeight > 0 ? itemWidth / itemHeight : 1.0;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x52050508),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x44C8A34A)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: GridView.builder(
            key: const Key('nine-judges-board'),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: ratio,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              final controller = widget.controller;
              final person = controller.board[index].person;
              final viewer = controller.uiViewer;
              final card = PersonCardWidget(
                person: person,
                coordinate: controller.positionLabel(index),
                attributeVisible: controller.knowsAttribute(person, viewer),
                viewerEyeKnown: controller.eyeKnowsAttribute(index, viewer),
                opponentEyeKnown: controller.eyeKnowsAttribute(
                  index,
                  viewer.opponent,
                ),
                viewerLabel: controller.isCpuGame ? 'YOU' : viewer.label,
                opponentLabel: controller.isCpuGame
                    ? 'CPU'
                    : viewer.opponent.label,
                selected: controller.selectedSlot == index,
                cpuHighlighted: controller.lastCpuTargetIndex == index,
                enabled: controller.canTarget(index),
                targeting: controller.phase == TurnPhase.selectingActionTarget,
                onTap: () =>
                    (widget.onTargetTap ?? controller.selectSlot).call(index),
                scoreDetail: widget.showScores
                    ? controller.score.slotScores[person.id]
                    : null,
              );
              final spotlightIndex = widget.spotlightIndex;
              if (spotlightIndex == null) return card;
              if (index != spotlightIndex) {
                return IgnorePointer(child: Opacity(opacity: 0.32, child: card));
              }
              // The tutorial's spotlighted card is never actually
              // "targetable" by the real rules engine here (selectedAction
              // is only ever set transiently inside performTutorialAction,
              // see tutorial_screen.dart), so PersonCardWidget's own
              // enabled-gated InkWell (enabled: controller.canTarget(index))
              // stays disabled the whole time — an outer, always-live
              // GestureDetector is what actually makes tapping the
              // spotlighted card advance the lesson.
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTargetTap == null
                    ? null
                    : () => widget.onTargetTap!(index),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            GameMetrics.cardRadius + 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: GameColors.gold.withValues(
                                alpha: 0.55 + 0.35 * _pulse.value,
                              ),
                              blurRadius: 10 + 10 * _pulse.value,
                              spreadRadius: 1 + 2 * _pulse.value,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      if (widget.spotlightLabel != null)
                        Positioned(
                          top: -10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              key: const Key('tutorial-spotlight-callout'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: GameColors.gold,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x99000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.spotlightLabel!,
                                style: const TextStyle(
                                  color: Color(0xFF1A1200),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  child: card,
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
