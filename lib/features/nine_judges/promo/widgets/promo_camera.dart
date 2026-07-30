import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/promo/controllers/promo_timeline.dart';
import 'package:flutter/widgets.dart';

/// Applies [state] (zoom/pan/fade/shake) to [child] as pure paint-time
/// transforms — never edits [child]'s widget tree, so the real board/card
/// widgets underneath are completely unmodified. Shake uses a deterministic
/// function of [PromoCameraState.elapsedSeconds] (never [Random]) so the
/// same script always produces byte-for-byte the same motion.
class PromoCameraView extends StatelessWidget {
  const PromoCameraView({required this.state, required this.child, super.key});

  final PromoCameraState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shake = state.shakeIntensity;
    final shakeOffset = shake <= 0
        ? Offset.zero
        : Offset(
            sin(state.elapsedSeconds * 40) * 4 * shake,
            cos(state.elapsedSeconds * 53) * 4 * shake,
          );
    return Opacity(
      opacity: state.opacity.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(state.dx * 40, state.dy * 40) + shakeOffset,
        child: Transform.scale(scale: state.scale, child: child),
      ),
    );
  }
}
