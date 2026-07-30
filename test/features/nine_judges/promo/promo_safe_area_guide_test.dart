import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_safe_area_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recording is the generic top-10%/bottom-15% preset', () {
    expect(PromoSafeArea.recording.top, closeTo(0.10, 0.001));
    expect(PromoSafeArea.recording.bottom, closeTo(0.15, 0.001));
    expect(
      PromoSafeArea.forPlatform(PromoSafePlatform.recording),
      same(PromoSafeArea.recording),
    );
  });

  testWidgets('hides entirely when visible is false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PromoSafeAreaGuide(
            platform: PromoSafePlatform.recording,
            visible: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('promo-safe-area-guide')), findsNothing);
  });

  testWidgets('renders a guide box when visible is true', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PromoSafeAreaGuide(
            platform: PromoSafePlatform.recording,
            visible: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('promo-safe-area-guide')), findsOneWidget);
  });
}
