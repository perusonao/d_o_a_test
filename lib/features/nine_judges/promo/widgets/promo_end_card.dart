import 'package:dead_or_alive/features/nine_judges/promo/models/promo_script.dart';
import 'package:flutter/material.dart';

/// Section④/⑤'s branded outro: logo art + "無料でプレイ" + a question-style
/// CTA. Shown as a full overlay — the one deliberate exception to "never
/// hide the board" (see [PromoEndCardCue]'s own doc comment).
class PromoEndCard extends StatelessWidget {
  const PromoEndCard({required this.cue, super.key});

  final PromoEndCardCue cue;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('promo-end-card'),
    color: Colors.black,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(cue.logoAsset, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          cue.freeToPlayText,
          style: const TextStyle(
            color: Color(0xFFF2E0A8),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cue.ctaText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
