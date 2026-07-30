import 'package:dead_or_alive/features/nine_judges/admin/simulation/screens/admin_simulation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('設定・実行・集計結果・エクスポートまで一通り表示される', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AdminSimulationScreen()),
      ),
    );

    expect(find.text('① Simulation設定'), findsOneWidget);
    expect(find.text('② ルール設定'), findsOneWidget);
    expect(find.text('③ Simulation実行'), findsOneWidget);

    // Smallest trial count so the widget test finishes quickly.
    await tester.tap(find.text('100'));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('simulation-start')));
    await tester.tap(find.byKey(const Key('simulation-start')));
    await tester.pump();
    // The run yields every 25 games via Future.delayed(Duration.zero); pump
    // repeatedly (real async, not fakeAsync) until it settles.
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.text('④ 集計結果'), findsOneWidget);
    expect(find.text('⑤ カード使用率'), findsOneWidget);
    expect(find.text('⑥ ボーナス分析'), findsOneWidget);
    expect(find.byKey(const Key('simulation-export-csv')), findsOneWidget);
    expect(find.byKey(const Key('simulation-export-json')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('プリセットボタンでルールフラグが切り替わる', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AdminSimulationScreen()),
      ),
    );
    await tester.tap(find.text('100'));
    await tester.pump();
    final presetButton = find.byKey(
      const Key('simulation-preset-③ JUDGE自由（SPECIAL VERDICTなし）'),
    );
    await tester.ensureVisible(presetButton);
    await tester.tap(presetButton);
    await tester.pump();
    expect(
      find.text('JUDGEは全状態で使用可能（現行: 審議中のみ）'),
      findsOneWidget,
    );
    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const Key('simulation-toggle-JUDGEは全状態で使用可能（現行: 審議中のみ）')),
    );
    expect(checkbox.value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
