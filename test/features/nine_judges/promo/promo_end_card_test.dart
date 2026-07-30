import 'package:dead_or_alive/features/nine_judges/promo/models/promo_script.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_end_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the logo, free-to-play text and CTA text from its cue', (
    tester,
  ) async {
    const cue = PromoEndCardCue(
      at: 12.5,
      freeToPlayText: '無料でプレイ',
      ctaText: 'あなたなら誰を裁く？',
    );
    await tester.pumpWidget(const MaterialApp(home: PromoEndCard(cue: cue)));

    expect(find.byKey(const Key('promo-end-card')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('無料でプレイ'), findsOneWidget);
    expect(find.text('あなたなら誰を裁く？'), findsOneWidget);
  });
}
