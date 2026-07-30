import 'package:flutter/material.dart';

/// Overlays [text] (from `promo_script.json`'s `captions`) near the bottom
/// of the screen — purely an overlay layered on top via [Stack] by the
/// caller; never touches the game UI beneath it.
class PromoCaptionOverlay extends StatelessWidget {
  const PromoCaptionOverlay({required this.text, super.key});

  final String? text;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: text == null
          ? const SizedBox.shrink(key: ValueKey('promo-caption-empty'))
          : Align(
              key: ValueKey('promo-caption-$text'),
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96, left: 24, right: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      text!,
                      key: const Key('promo-caption-text'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}
