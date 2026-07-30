import 'package:dead_or_alive/features/nine_judges/admin/screens/admin_overview_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Widget-level coverage for the visitCount/playCount traffic cards added
/// this round (see AppStatsRepository / AdminPlaytestRepository.fetchVisitCount)
/// — durable, cross-device raw counters shown even when [records] is empty,
/// same pattern as AdminKpiTab's tutorialCompletionCount.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('records未取得でも訪問数・プレイ数カードは表示される', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AdminOverviewTab(
          records: [],
          visitCount: 100,
          playCount: 30,
        ),
      ),
    );

    expect(find.byKey(const Key('admin-overview-empty')), findsOneWidget);
    expect(find.byKey(const Key('admin-visit-count')), findsOneWidget);
    expect(find.byKey(const Key('admin-play-count')), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('取得中は「取得中…」を表示する', (tester) async {
    await tester.pumpWidget(wrap(const AdminOverviewTab(records: [])));
    // 2 traffic cards + the daily-trend section's own loading text.
    expect(find.text('取得中…'), findsNWidgets(3));
  });

  testWidgets('取得に失敗した場合は失敗文言を表示する', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AdminOverviewTab(
          records: [],
          visitCountFailed: true,
          playCountFailed: true,
        ),
      ),
    );
    expect(find.text('取得失敗'), findsNWidgets(2));
  });

  group('日別推移', () {
    testWidgets('訪問数・プレイ数を日付ごとに1行ずつ表示する', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AdminOverviewTab(
            records: [],
            dailyVisitCounts: [
              MapEntry('2026-07-29', 3),
              MapEntry('2026-07-30', 5),
            ],
            dailyPlayCounts: [
              MapEntry('2026-07-29', 1),
              MapEntry('2026-07-30', 2),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('admin-daily-trend-table')), findsOneWidget);
      expect(find.text('2026-07-29: 訪問3 / プレイ1'), findsOneWidget);
      expect(find.text('2026-07-30: 訪問5 / プレイ2'), findsOneWidget);
    });

    testWidgets('取得中はローディング文言を表示する', (tester) async {
      await tester.pumpWidget(wrap(const AdminOverviewTab(records: [])));
      expect(
        find.byKey(const Key('admin-daily-trend-loading')),
        findsOneWidget,
      );
    });

    testWidgets('取得に失敗した場合は失敗文言を表示する', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AdminOverviewTab(records: [], dailyCountsFailed: true),
        ),
      );
      expect(
        find.byKey(const Key('admin-daily-trend-failed')),
        findsOneWidget,
      );
    });
  });

  testWidgets('recordsがある場合も他のカードと並んで表示される', (tester) async {
    await tester.pumpWidget(
      wrap(
        AdminOverviewTab(
          records: [buildRecord()],
          visitCount: 5,
          playCount: 2,
        ),
      ),
    );

    expect(find.byKey(const Key('admin-overview-list')), findsOneWidget);
    expect(find.byKey(const Key('admin-visit-count')), findsOneWidget);
    expect(find.byKey(const Key('admin-play-count')), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
