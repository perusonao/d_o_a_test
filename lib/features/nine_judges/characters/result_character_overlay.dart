import 'package:dead_or_alive/features/nine_judges/characters/character_assets.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';

/// Section ③: ~3s character beat shown once when the result screen first
/// appears — the winning faction's character with a short victory line, or
/// (when [isVictory] is false, i.e. a CPU-game human loss) the human's own
/// faction with an encouraging line instead. Skippable by tapping anywhere.
/// [instant] mirrors `NineJudgesGameSettings.skipCpuDelays`.
class ResultCharacterOverlay extends StatefulWidget {
  const ResultCharacterOverlay({
    required this.faction,
    required this.message,
    required this.isVictory,
    required this.onDone,
    this.instant = false,
    super.key,
  });

  final Faction faction;
  final String message;
  final bool isVictory;
  final VoidCallback onDone;
  final bool instant;

  @override
  State<ResultCharacterOverlay> createState() =>
      _ResultCharacterOverlayState();
}

class _ResultCharacterOverlayState extends State<ResultCharacterOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: widget.instant
            ? Duration.zero
            : const Duration(milliseconds: 3000),
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
    final isSavior = widget.faction == Faction.savior;
    final accent = GameColors.faction(isSavior);
    return GestureDetector(
      key: const Key('result-character-overlay'),
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final fadeIn = (t / 0.15).clamp(0.0, 1.0);
          final fadeOut = 1.0 - ((t - 0.85) / 0.15).clamp(0.0, 1.0);
          final opacity = fadeIn * fadeOut;
          final textIn = ((t - 0.25) / 0.25).clamp(0.0, 1.0);
          return ColoredBox(
            color: GameColors.background,
            child: Opacity(
              opacity: opacity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      CharacterAssets.portrait(widget.faction),
                      width: 220,
                      height: 280,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: textIn,
                    child: Text(
                      widget.isVictory
                          ? (isSavior ? 'WINNER 救済者' : 'WINNER 執行者')
                          : '次の審判へ',
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: textIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'タップで結果画面へ',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
