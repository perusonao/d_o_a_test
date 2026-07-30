import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_recording_start_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping the button invokes onStart exactly once', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PromoRecordingStartOverlay(onStart: () => callCount++),
      ),
    );

    expect(find.byKey(const Key('promo-recording-start')), findsOneWidget);
    expect(find.text('録画開始'), findsOneWidget);

    await tester.tap(find.byKey(const Key('promo-recording-start')));
    await tester.pump();

    expect(callCount, 1);
  });
}
