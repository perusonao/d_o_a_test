import 'package:dead_or_alive/features/nine_judges/characters/character_assets.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';

/// Section ①: ~2s confrontation shown after "ゲーム開始" and before the
/// board, so a first-time player immediately feels "I am the savior/
/// executor judging these nine people" before a single card is dealt.
/// Skippable by tapping anywhere; [instant] (mirrors
/// `NineJudgesGameSettings.skipCpuDelays`) finishes on the next frame
/// instead of animating, so automated/test contexts never leave a running
/// animation behind.
class CharacterIntroOverlay extends StatefulWidget {
  const CharacterIntroOverlay({
    required this.humanFaction,
    required this.onDone,
    this.instant = false,
    super.key,
  });

  /// Null for hotseat (no single "you" to personalize the reveal for).
  final Faction? humanFaction;
  final VoidCallback onDone;
  final bool instant;

  @override
  State<CharacterIntroOverlay> createState() => _CharacterIntroOverlayState();
}

class _CharacterIntroOverlayState extends State<CharacterIntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: widget.instant
            ? Duration.zero
            : const Duration(milliseconds: 2000),
      )..forward();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faction = widget.humanFaction;
    final isSavior = faction == Faction.savior;
    return GestureDetector(
      key: const Key('character-intro-overlay'),
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final fadeIn = (t / 0.2).clamp(0.0, 1.0);
          final standIn = ((t - 0.2) / 0.35).clamp(0.0, 1.0);
          final textIn = ((t - 0.55) / 0.25).clamp(0.0, 1.0);
          return ColoredBox(
            color: GameColors.background,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: fadeIn,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Portrait(
                        faction: Faction.savior,
                        emphasized: faction == null || isSavior,
                        standIn: standIn,
                      ),
                      const SizedBox(width: 12),
                      _Portrait(
                        faction: Faction.executor,
                        emphasized: faction == null || !isSavior,
                        standIn: standIn,
                      ),
                    ],
                  ),
                ),
                if (faction != null)
                  Positioned(
                    bottom: 64,
                    child: Opacity(
                      opacity: textIn,
                      child: _RevealText(faction: faction),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  child: Opacity(
                    opacity: fadeIn,
                    child: const Text(
                      'タップでスキップ',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.faction,
    required this.emphasized,
    required this.standIn,
  });

  final Faction faction;
  final bool emphasized;
  final double standIn;

  @override
  Widget build(BuildContext context) {
    final scale = emphasized ? 1.0 + 0.08 * standIn : 1.0 - 0.06 * standIn;
    final opacity = emphasized ? 1.0 : 1.0 - 0.55 * standIn;
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            CharacterAssets.portrait(faction),
            width: 150,
            height: 190,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _RevealText extends StatelessWidget {
  const _RevealText({required this.faction});
  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final color = GameColors.faction(faction == Faction.savior);
    final line = faction == Faction.savior
        ? '9人を救済へ導いてください。'
        : '9人へ裁きを執行してください。';
    return Column(
      children: [
        const Text('あなたは', style: TextStyle(color: Colors.white70, fontSize: 14)),
        Text(
          '【${faction.label}】',
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(line, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}
