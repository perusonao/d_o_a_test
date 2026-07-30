import 'package:flutter/material.dart';

/// Overlays [text] (from `promo_script.json`'s `captions`) as white text
/// with a black outline — no background box — so it never visually hides
/// the board underneath, only the letters themselves sit on top of it.
/// Positioned in a thin band near the bottom edge, clear of the 3x3 grid.
class PromoCaptionOverlay extends StatelessWidget {
  const PromoCaptionOverlay({required this.text, super.key});

  final String? text;

  static const _style = TextStyle(fontSize: 19, fontWeight: FontWeight.w900);

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: text == null
          ? const SizedBox.shrink(key: ValueKey('promo-caption-empty'))
          : Align(
              key: ValueKey('promo-caption-$text'),
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28, left: 20, right: 20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Black stroke behind, white fill in front — readable
                    // over any board artwork without a covering box.
                    Text(
                      text!,
                      textAlign: TextAlign.center,
                      style: _style.copyWith(
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4
                          ..color = Colors.black,
                      ),
                    ),
                    Text(
                      text!,
                      key: const Key('promo-caption-text'),
                      textAlign: TextAlign.center,
                      style: _style.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
