import 'package:flutter/material.dart';

/// Wraps [child] in a phone-shaped, distraction-free recording frame: a
/// centered 9:16 box on solid [backgroundColor], letterboxed with that same
/// solid color on whichever axis the actual recording window doesn't match
/// 9:16 — so a screen recording taken from *any* browser window shape reads
/// as "a phone app was recorded" rather than "a browser recorded a game".
///
/// Deliberately generic and not tied to [PromoPlayerScreen] or the game
/// board specifically: any future auto-play recording screen (tutorial
/// video, character-intro video, update-announcement video, …) can reuse
/// this same frame around its own content.
class PromoRecordingFrame extends StatelessWidget {
  const PromoRecordingFrame({
    required this.child,
    this.backgroundColor = Colors.black,
    super.key,
  });

  final Widget child;
  final Color backgroundColor;

  static const aspectRatio = 9 / 16;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: backgroundColor,
    child: Center(
      child: AspectRatio(aspectRatio: aspectRatio, child: child),
    ),
  );
}
