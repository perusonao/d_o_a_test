import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_game_detail_view.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('onViewTesterHistoryを渡すとボタンが表示され、testerIdつきで呼ばれる', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminGameDetailView(
            record: buildRecord(testerId: 'tester-xyz'),
            anonymizer: TesterAnonymizer(),
            actionsLoading: false,
            onViewTesterHistory: (id) => tapped = id,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('view-tester-history')), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-tester-history')));
    expect(tapped, 'tester-xyz');
  });

  testWidgets('onViewTesterHistoryを渡さない場合はボタンが表示されない(既定の後方互換)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminGameDetailView(
            record: buildRecord(testerId: 'tester-xyz'),
            anonymizer: TesterAnonymizer(),
            actionsLoading: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('view-tester-history')), findsNothing);
  });

  testWidgets('testerIdが無いゲームではボタンを表示しない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminGameDetailView(
            record: buildRecord(testerId: null),
            anonymizer: TesterAnonymizer(),
            actionsLoading: false,
            onViewTesterHistory: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('view-tester-history')), findsNothing);
  });
}
