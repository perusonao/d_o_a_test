import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_kpi_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Widget-level coverage for the tutorial-completion-count card added this
/// round (see AdminPlaytestRepository.fetchTutorialCompletionCount) — the
/// pure aggregation logic (buildAdminKpiReport itself) is already covered
/// by admin_kpi_test.dart.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  // The KPI tab's ListView holds many cards (report KPIs + EYE/JUDGE/reverse
  // analysis sections) — a normal test viewport's lazy sliver wouldn't
  // materialize the tutorial-completion card at all. A tall physical size
  // avoids needing to scroll to reach it.
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('取得中はローディング文言を表示する', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      wrap(AdminKpiTab(records: [buildRecord()])),
    );
    expect(find.byKey(const Key('tutorial-completion-count')), findsOneWidget);
    expect(find.text('取得中…'), findsOneWidget);
  });

  testWidgets('取得できた件数を表示する', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      wrap(
        AdminKpiTab(records: [buildRecord()], tutorialCompletionCount: 7),
      ),
    );
    expect(find.text('7 人が完了'), findsOneWidget);
  });

  testWidgets('取得に失敗した場合は失敗文言を表示する', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      wrap(
        AdminKpiTab(
          records: [buildRecord()],
          tutorialCompletionFailed: true,
        ),
      ),
    );
    expect(find.text('取得に失敗しました'), findsOneWidget);
  });

  testWidgets('playtestsが0件でもチュートリアル完了数カードは表示される', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      wrap(AdminKpiTab(records: const [], tutorialCompletionCount: 3)),
    );
    expect(find.byKey(const Key('admin-kpi-empty')), findsOneWidget);
    expect(find.text('3 人が完了'), findsOneWidget);
  });
}
