import 'package:dead_or_alive/features/nine_judges/admin/services/admin_overview_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('AdminOverviewStats.compute', () {
    test('0件のときクラッシュせず全項目がnull/0になる', () {
      final stats = AdminOverviewStats.compute(const []);
      expect(stats.totalGames, 0);
      expect(stats.uniqueTesterCount, 0);
      expect(stats.avgTurns, isNull);
      expect(stats.saviorWinRate, isNull);
      expect(stats.abandonmentRate, isNull);
      expect(stats.abandonmentSampleSize, 0);
    });

    test('総ゲーム数・ユニークtesterId数・勝率・平均ターン・平均スコア差', () {
      final records = [
        buildRecord(gameId: 'g1', testerId: 't1', winner: 'savior', totalTurns: 20, saviorScore: 25, executorScore: 20),
        buildRecord(gameId: 'g2', testerId: 't1', winner: 'executor', totalTurns: 24, saviorScore: 18, executorScore: 27),
        buildRecord(gameId: 'g3', testerId: 't2', winner: 'savior', totalTurns: 22, saviorScore: 30, executorScore: 15),
      ];
      final stats = AdminOverviewStats.compute(records.map((r) => r.session).toList());
      expect(stats.totalGames, 3);
      expect(stats.uniqueTesterCount, 2);
      expect(stats.saviorWinRate, closeTo(2 / 3, 1e-9));
      expect(stats.executorWinRate, closeTo(1 / 3, 1e-9));
      expect(stats.avgTurns, closeTo((20 + 24 + 22) / 3, 1e-9));
      expect(stats.avgScoreDiff, closeTo((5 + 9 + 15) / 3, 1e-9));
    });

    test('先手/後手勝率はdrawを除いて計算される', () {
      final records = [
        buildRecord(gameId: 'g1', firstPlayer: 'savior', winner: 'savior'),
        buildRecord(gameId: 'g2', firstPlayer: 'savior', winner: 'executor'),
        buildRecord(gameId: 'g3', firstPlayer: 'executor', winner: 'draw'),
      ];
      final stats = AdminOverviewStats.compute(records.map((r) => r.session).toList());
      // g3 is a draw and excluded from the decisive-game denominator (2).
      expect(stats.firstPlayerWinRate, closeTo(1 / 2, 1e-9));
      expect(stats.secondPlayerWinRate, closeTo(1 / 2, 1e-9));
    });

    test('初回プレイヤー数とリピーター数はテスターごとに分類される', () {
      final records = [
        // t1: only ever seen as a first game -> counted as first-time.
        buildRecord(gameId: 'g1', testerId: 't1', isFirstGame: true, playNumber: 1),
        // t2: has a later game loaded -> counted as a repeater.
        buildRecord(gameId: 'g2', testerId: 't2', isFirstGame: true, playNumber: 1),
        buildRecord(gameId: 'g3', testerId: 't2', isFirstGame: false, playNumber: 2),
      ];
      final stats = AdminOverviewStats.compute(records.map((r) => r.session).toList());
      expect(stats.uniqueTesterCount, 2);
      expect(stats.firstTimePlayerCount, 1);
      expect(stats.repeaterCount, 1);
    });

    test('評価平均はnullを分母から除外しnを報告する', () {
      final records = [
        buildRecord(gameId: 'g1', funRating: 5),
        buildRecord(gameId: 'g2', funRating: 3),
        buildRecord(gameId: 'g3', funRating: null),
      ];
      final stats = AdminOverviewStats.compute(records.map((r) => r.session).toList());
      final fun = stats.ratings['fun']!;
      expect(fun.n, 2);
      expect(fun.average, closeTo(4.0, 1e-9));
    });

    test('旧ログでratingが全て無いゲームでもクラッシュしない', () {
      final records = [buildRecord(gameId: 'g1')];
      final stats = AdminOverviewStats.compute(records.map((r) => r.session).toList());
      for (final key in AdminOverviewStats.ratingKeys) {
        expect(stats.ratings[key]!.n, 0);
        expect(stats.ratings[key]!.average, isNull);
      }
    });

    test('離脱率はgameAbandonedが記録されているゲームのみを分母にする', () {
      final records = [
        buildRecord(gameId: 'g1', gameAbandoned: true),
        buildRecord(gameId: 'g2', gameAbandoned: false),
        buildRecord(gameId: 'g3', gameAbandoned: null),
      ];
      final stats = AdminOverviewStats.compute(records.map((r) => r.session).toList());
      expect(stats.abandonmentSampleSize, 2);
      expect(stats.abandonmentRate, closeTo(0.5, 1e-9));
    });

    test('平均プレイ時間はfinishedAtとstartedAtの差から分単位で計算される', () {
      final started = DateTime(2026, 1, 1, 10, 0);
      final records = [
        buildRecord(
          gameId: 'g1',
          startedAt: started,
          finishedAt: started.add(const Duration(minutes: 10)),
        ),
      ];
      final stats = AdminOverviewStats.compute(records.map((r) => r.session).toList());
      expect(stats.avgGameDurationMinutes, closeTo(10.0, 1e-6));
    });
  });
}
