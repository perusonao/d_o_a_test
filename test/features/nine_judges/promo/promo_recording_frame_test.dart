import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_recording_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('letterboxes a wide viewport into a centered 9:16 box', (
    tester,
  ) async {
    // A landscape/desktop-shaped window — far from 9:16 — so the frame must
    // shrink its child to fit height and center it, leaving background bars
    // on the sides instead of stretching the content edge to edge.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: PromoRecordingFrame(
          backgroundColor: Colors.black,
          child: ColoredBox(
            color: Colors.white,
            key: Key('frame-content'),
          ),
        ),
      ),
    );

    final contentSize = tester.getSize(find.byKey(const Key('frame-content')));
    expect(
      contentSize.width / contentSize.height,
      closeTo(PromoRecordingFrame.aspectRatio, 0.001),
    );
    // Height-constrained: the letterboxed box shouldn't just fill the wide
    // viewport's full width.
    expect(contentSize.width, lessThan(1600));
  });

  testWidgets('fills a viewport that is already 9:16', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: PromoRecordingFrame(
          child: ColoredBox(color: Colors.white, key: Key('frame-content')),
        ),
      ),
    );

    final contentSize = tester.getSize(find.byKey(const Key('frame-content')));
    expect(contentSize.width, closeTo(360, 0.5));
    expect(contentSize.height, closeTo(640, 0.5));
  });
}
