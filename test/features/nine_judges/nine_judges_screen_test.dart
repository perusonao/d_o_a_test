import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';

void main() {
  testWidgets('360x640で盤面と操作をスクロールなしで表示する', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: NineJudgesGameScreen()));

    expect(find.byType(Scrollable), findsNothing);
    expect(find.byKey(const Key('judge-slot-0')), findsOneWidget);
    expect(find.byKey(const Key('judge-slot-8')), findsOneWidget);
    expect(find.byKey(const Key('save-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
