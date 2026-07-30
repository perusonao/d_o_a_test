import 'package:flutter/material.dart';

/// Which SNS platform's safe area a [PromoSafeAreaGuide] draws. Insets are
/// fractions of the viewport — rough, commonly-cited figures for each
/// platform's own UI chrome (profile/like/share rail, caption band, etc.)
/// so a recording's captions/action never land where that platform would
/// cover them. [recording] is the generic default — not tuned to any one
/// platform's chrome, just "top ~10% for title/captions, bottom ~15% for
/// CTA/logo/QR" — safe enough to crop for any of the others afterward.
enum PromoSafePlatform { recording, x, tiktok, youtubeShorts }

class PromoSafeArea {
  const PromoSafeArea({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final double top;
  final double bottom;
  final double left;
  final double right;

  static const recording = PromoSafeArea(
    top: .10,
    bottom: .15,
    left: .04,
    right: .04,
  );
  static const x = PromoSafeArea(top: .06, bottom: .10, left: .04, right: .04);
  static const tiktok = PromoSafeArea(
    top: .12,
    bottom: .20,
    left: .05,
    right: .05,
  );
  static const youtubeShorts = PromoSafeArea(
    top: .10,
    bottom: .18,
    left: .05,
    right: .05,
  );

  static PromoSafeArea forPlatform(PromoSafePlatform platform) =>
      switch (platform) {
        PromoSafePlatform.recording => recording,
        PromoSafePlatform.x => x,
        PromoSafePlatform.tiktok => tiktok,
        PromoSafePlatform.youtubeShorts => youtubeShorts,
      };
}

/// A thin, non-interactive guide rectangle marking [platform]'s safe area —
/// a recording aid only (never affects layout/hit-testing of anything
/// beneath it), toggle off before the final take if unwanted in-frame.
class PromoSafeAreaGuide extends StatelessWidget {
  const PromoSafeAreaGuide({
    required this.platform,
    this.visible = true,
    super.key,
  });

  final PromoSafePlatform platform;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final area = PromoSafeArea.forPlatform(platform);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              width * area.left,
              height * area.top,
              width * area.right,
              height * area.bottom,
            ),
            child: DecoratedBox(
              key: const Key('promo-safe-area-guide'),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.amberAccent.withValues(alpha: .6),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
