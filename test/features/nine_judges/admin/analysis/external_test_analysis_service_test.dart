import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_filter.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/external_test_analysis_service.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('buildAnalysisReport — 基本集計', () {
    test('0件でもクラッシュせず全項目がnull/0になる', () {
      final report = buildAnalysisReport(
        pool: const [],
        filter: const AnalysisFilter(),
        projectId: 'nine-verdicts',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.reportInfo['gameCount'], 0);
      expect(report.summary['totalGames'], 0);
      expect(report.balance['saviorWinRate'], isNull);
      expect(report.findings, isEmpty);
      expect(report.feedback, isEmpty);
    });

    test('総ゲーム数・ユニークtesterId数・先手勝率・プレイヤー勝率・平均ターン・平均得点差を計算する', () {
      final pool = [
        buildRecord(
          gameId: 'g1',
          testerId: 't1',
          firstPlayer: 'savior',
          playerFaction: 'savior',
          winner: 'savior',
          totalTurns: 20,
          saviorScore: 25,
          executorScore: 20,
        ),
        buildRecord(
          gameId: 'g2',
          testerId: 't1',
          firstPlayer: 'savior',
          playerFaction: 'savior',
          winner: 'executor',
          totalTurns: 24,
          saviorScore: 18,
          executorScore: 27,
        ),
        buildRecord(
          gameId: 'g3',
          testerId: 't2',
          firstPlayer: 'executor',
          playerFaction: 'executor',
          winner: 'executor',
          totalTurns: 22,
          saviorScore: 15,
          executorScore: 30,
        ),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'nine-verdicts',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.summary['totalGames'], 3);
      expect(report.summary['uniqueTesterCount'], 2);
      // g1: firstPlayer savior, winner savior -> first player won.
      // g2: firstPlayer savior, winner executor -> first player lost.
      // g3: firstPlayer executor, winner executor -> first player won.
      expect(report.balance['firstPlayerWinRate'], closeTo(2 / 3, 1e-9));
      expect(report.summary['avgTurns'], closeTo((20 + 24 + 22) / 3, 1e-9));
      expect(report.summary['avgScoreDiff'], closeTo((5 + 9 + 15) / 3, 1e-9));
      expect(report.summary['medianScoreDiff'], 9.0);
      expect(report.summary['maxScoreDiff'], 15);
      // g1: playerFaction savior, winner savior -> player wins.
      // g2: playerFaction savior, winner executor -> player loses.
      // g3: playerFaction executor, winner executor -> player wins.
      expect(report.balance['playerWinRate'], closeTo(2 / 3, 1e-9));
    });

    test('評価はnullを分母から除外し、平均・中央値・分布を計算する', () {
      final pool = [
        buildRecord(gameId: 'g1', funRating: 5),
        buildRecord(gameId: 'g2', funRating: 3),
        buildRecord(gameId: 'g3', funRating: 3),
        buildRecord(gameId: 'g4', funRating: null),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      final overall = report.ratings['overall']! as Map<String, Object?>;
      final fun = overall['fun']! as Map<String, Object?>;
      expect(fun['n'], 3);
      expect(fun['average'], closeTo((5 + 3 + 3) / 3, 1e-9));
      expect(fun['median'], 3.0);
      final distribution = fun['distribution']! as Map<String, int>;
      expect(distribution['3'], 2);
      expect(distribution['5'], 1);
      expect(distribution['null'], 1);
    });

    test('endReason別件数を集計する(存在しない値をでっち上げない)', () {
      final pool = [
        buildRecord(gameId: 'g1'),
        buildRecord(gameId: 'g2'),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      // buildRecord's default GameSession has endReason == null (not set),
      // so the bucket key must be the explicit "(不明)" placeholder — never
      // a fabricated value like "noLegalActions".
      final counts = report.summary['endReasonCounts']! as Map<String, int>;
      expect(counts['(不明)'], 2);
    });
  });

  group('buildAnalysisReport — 初回/経験者・CPU難易度別', () {
    test('初回と経験者を分けて比較する', () {
      final pool = [
        buildRecord(gameId: 'g1', isFirstGame: true, playNumber: 1, funRating: 5),
        buildRecord(gameId: 'g2', isFirstGame: false, playNumber: 2, funRating: 2),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      final firstTime = report.firstGameComparison['firstTime']! as Map<String, Object?>;
      final experienced = report.firstGameComparison['experienced']! as Map<String, Object?>;
      expect(firstTime['sampleSize'], 1);
      expect(experienced['sampleSize'], 1);
      expect((firstTime['fun'] as Map)['average'], 5.0);
      expect((experienced['fun'] as Map)['average'], 2.0);
    });

    test('存在するcpuDifficultyのみ出力される', () {
      final pool = [
        buildRecord(gameId: 'g1', cpuDifficulty: 'balanced'),
        buildRecord(gameId: 'g2', cpuDifficulty: 'hard'),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.cpuDifficultyAnalysis.keys.toSet(), {'balanced', 'hard'});
      expect(report.cpuDifficultyAnalysis.containsKey('aggressive'), isFalse);
    });
  });

  group('buildAnalysisReport — KPI', () {
    test('チュートリアルKPIは常にDATA_INSUFFICIENTでその理由も含む', () {
      final report = buildAnalysisReport(
        pool: [buildRecord(gameId: 'g1')],
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      final tutorialKpi = report.kpis.firstWhere(
        (k) => k['metric'] == 'tutorialCompletionRate',
      );
      expect(tutorialKpi['status'], 'DATA_INSUFFICIENT');
      expect(tutorialKpi['reason'], contains('Firestoreへ送信されていません'));
    });

    test('各KPIにmetric/value/sampleSize/target/statusが含まれる', () {
      final report = buildAnalysisReport(
        pool: [buildRecord(gameId: 'g1', funRating: 5, ruleUnderstandingRating: 5)],
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      for (final kpi in report.kpis) {
        expect(kpi.containsKey('metric'), isTrue);
        expect(kpi.containsKey('value'), isTrue);
        expect(kpi.containsKey('sampleSize'), isTrue);
        expect(kpi.containsKey('target'), isTrue);
        expect(kpi.containsKey('status'), isTrue);
      }
    });
  });

  group('buildAnalysisReport — 自動検出された注目点', () {
    test('先手勝率が55%を超えると注目点が生成される', () {
      final pool = [
        for (var i = 0; i < 20; i++)
          buildRecord(
            gameId: 'g$i',
            testerId: 'tester-${i % 3}',
            firstPlayer: 'savior',
            winner: i < 15 ? 'savior' : 'executor', // 15/20 = 75%
          ),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(
        report.findings.any((f) => f.metric == 'firstPlayerWinRate'),
        isTrue,
      );
    });

    test('サンプル数不足のときは注目点として明記され、断定的な深刻度を避ける', () {
      final pool = [
        buildRecord(gameId: 'g1', testerId: 't1', firstPlayer: 'savior', winner: 'savior'),
        buildRecord(gameId: 'g2', testerId: 't1', firstPlayer: 'savior', winner: 'savior'),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.findings.any((f) => f.metric == 'uniqueTesterCount'), isTrue);
      // With very few unique testers every triggered finding should be
      // hedged down to "info", never "critical".
      expect(
        report.findings.every((f) => f.severity.name != 'critical'),
        isTrue,
      );
    });

    test('平常なバランスのデータでは目立った注目点が出ない', () {
      // 20 games, exactly balanced: savior/executor each win 10, the first
      // player wins exactly 10 of the 20 (5 as savior + 5 as executor).
      String firstPlayerFor(int i) => i < 10 ? 'savior' : 'executor';
      String winnerFor(int i) => switch (i) {
        >= 0 && < 5 => 'savior', // firstPlayer=savior, first wins
        >= 5 && < 10 => 'executor', // firstPlayer=savior, first loses
        >= 10 && < 15 => 'executor', // firstPlayer=executor, first wins
        _ => 'savior', // firstPlayer=executor, first loses
      };
      final pool = [
        for (var i = 0; i < 20; i++)
          buildRecord(
            gameId: 'g$i',
            testerId: 'tester-$i',
            firstPlayer: firstPlayerFor(i),
            winner: winnerFor(i),
            totalTurns: 22,
            funRating: 4,
            ruleUnderstandingRating: 4,
            replayIntentRating: 4,
            strategicDepthRating: 4,
          ),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.findings, isEmpty);
    });
  });

  group('buildAnalysisReport — EYE/JUDGE/reverse', () {
    test('actions未取得のゲームはEYE集計から除外されサンプル数が報告される', () {
      final pool = [
        buildRecord(gameId: 'g1'),
        buildRecord(
          gameId: 'g2',
          actionsLoaded: true,
          actions: [buildAction(actionType: 'eye', eyeCandidateCount: 2)],
        ),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.eyeAnalysis['sampleSize'], 1);
    });

    test('JUDGE使用率はactions不要でトップレベルフィールドから計算される', () {
      final pool = [
        buildRecord(
          gameId: 'g1',
          playerFaction: 'savior',
          saviorSpecialVerdictUsed: true,
          executorSpecialVerdictUsed: false,
        ),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.judgeAnalysis['playerUsageRate'], 1.0);
    });
  });
}
