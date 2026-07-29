import 'package:dead_or_alive/features/nine_judges/characters/character_assets.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';

/// Section ②: ~1s cut-in shown only when SPECIAL VERDICT (JUDGE) confirms a
/// person — LIFE/DEATH confirmations keep the plain reveal (see
/// `_ConfirmationOverlay` in game_screen.dart). Calls [onDone] when finished
/// (auto after the animation, or immediately on tap), which the caller wires
/// to `NineJudgesController.confirmConfirmationReveal` exactly like the
/// plain reveal does — this widget only changes what's shown while waiting,
/// never the underlying confirmation flow. [instant] mirrors
/// `NineJudgesGameSettings.skipCpuDelays`.
class SpecialVerdictOverlay extends StatefulWidget {
  const SpecialVerdictOverlay({
    required this.actor,
    required this.onDone,
    this.instant = false,
    super.key,
  });

  final Faction actor;
  final VoidCallback onDone;
  final bool instant;

  @override
  State<SpecialVerdictOverlay> createState() => _SpecialVerdictOverlayState();
}

class _SpecialVerdictOverlayState extends State<SpecialVerdictOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: widget.instant
            ? Duration.zero
            : const Duration(milliseconds: 1000),
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
    final isSavior = widget.actor == Faction.savior;
    final accent = GameColors.faction(isSavior);
    final line = isSavior ? '救済は成された。' : '判決を執行する。';
    return GestureDetector(
      key: const Key('special-verdict-overlay'),
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final darken = (t / 0.15).clamp(0.0, 1.0);
          final portraitIn = ((t - 0.1) / 0.3).clamp(0.0, 1.0);
          final glow = ((t - 0.3) / 0.3).clamp(0.0, 1.0);
          final textIn = ((t - 0.55) / 0.3).clamp(0.0, 1.0);
          return ColoredBox(
            color: Colors.black.withValues(alpha: 0.78 * darken),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: glow,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                Opacity(
                  opacity: portraitIn,
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * portraitIn,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        CharacterAssets.portrait(widget.actor),
                        width: 190,
                        height: 240,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 70,
                  child: Opacity(
                    opacity: textIn,
                    child: Text(
                      line,
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
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
