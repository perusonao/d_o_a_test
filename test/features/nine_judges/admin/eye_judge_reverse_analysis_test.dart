import 'package:dead_or_alive/features/nine_judges/admin/services/eye_judge_reverse_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('EyeAnalysis.compute', () {
    test('actions未取得のゲームは集計対象から除外される(sampleSizeで報告)', () {
      final records = [
        buildRecord(gameId: 'g1'), // actions not loaded
        buildRecord(
          gameId: 'g2',
          actionsLoaded: true,
          actions: [buildAction(actionType: 'eye', eyeCandidateCount: 2)],
        ),
      ];
      final eye = EyeAnalysis.compute(records);
      expect(eye.sampleSize, 1);
      expect(eye.avgUsesPerGame, closeTo(1.0, 1e-9));
      expect(eye.avgCandidateCount, closeTo(2.0, 1e-9));
    });

    test('プレイヤー側/CPU側のEYE使用回数を分けて集計する', () {
      final records = [
        buildRecord(
          gameId: 'g1',
          playerFaction: 'savior',
          cpuFaction: 'executor',
          actionsLoaded: true,
          actions: [
            buildAction(actionIndex: 0, faction: 'savior', actionType: 'eye'),
            buildAction(actionIndex: 1, faction: 'savior', actionType: 'eye'),
            buildAction(actionIndex: 2, faction: 'executor', actionType: 'eye'),
          ],
        ),
      ];
      final eye = EyeAnalysis.compute(records);
      expect(eye.avgUsesPerGamePlayerSide, closeTo(2.0, 1e-9));
      expect(eye.avgUsesPerGameCpuSide, closeTo(1.0, 1e-9));
    });

    test('0件のときクラッシュしない', () {
      final eye = EyeAnalysis.compute(const []);
      expect(eye.sampleSize, 0);
      expect(eye.avgUsesPerGame, isNull);
      expect(eye.usedUpToCapRate, isNull);
    });
  });

  group('JudgeAnalysis.compute', () {
    test('使用率・機会数はactions不要でトップレベルフィールドから計算される', () {
      final records = [
        buildRecord(
          gameId: 'g1',
          saviorSpecialVerdictUsed: true,
          executorSpecialVerdictUsed: false,
          judgeOpportunityCountSavior: 3,
          judgeOpportunityCountExecutor: 4,
        ),
        buildRecord(
          gameId: 'g2',
          saviorSpecialVerdictUsed: false,
          executorSpecialVerdictUsed: false,
          judgeOpportunityCountSavior: 5,
          judgeOpportunityCountExecutor: 2,
        ),
      ];
      final judge = JudgeAnalysis.compute(records);
      expect(judge.saviorUsageRate, closeTo(0.5, 1e-9));
      expect(judge.executorUsageRate, closeTo(0.0, 1e-9));
      expect(judge.usedGamesCount, 1);
      expect(judge.unusedGamesCount, 1);
      expect(judge.avgOpportunityCountSavior, closeTo(4.0, 1e-9));
    });

    test('欠損値は0とみなさず記録なし(null/0サンプル)として扱う', () {
      final records = [buildRecord(gameId: 'g1')];
      final judge = JudgeAnalysis.compute(records);
      expect(judge.saviorUsageRate, isNull);
      expect(judge.turnOfUseSampleSize, 0);
      expect(judge.avgTurnOfUse, isNull);
    });

    test('使用時の平均ターン・決定時間はactions取得済みゲームのspecialVerdictアクションから計算', () {
      final records = [
        buildRecord(
          gameId: 'g1',
          actionsLoaded: true,
          actions: [
            buildAction(
              actionType: 'specialVerdict',
              turnNumber: 8,
              turnDecisionTimeMs: 5000,
            ),
          ],
        ),
      ];
      final judge = JudgeAnalysis.compute(records);
      expect(judge.turnOfUseSampleSize, 1);
      expect(judge.avgTurnOfUse, closeTo(8.0, 1e-9));
      expect(judge.avgDecisionTimeMsOfUse, closeTo(5000.0, 1e-9));
    });
  });

  group('ReverseAnalysis.compute', () {
    test('勝者側/敗者側の使用率はwinnerとreverse使用フラグから計算される', () {
      final records = [
        buildRecord(
          gameId: 'g1',
          winner: 'savior',
          saviorReverseActionUsed: true,
          executorReverseActionUsed: false,
        ),
      ];
      final reverse = ReverseAnalysis.compute(records);
      expect(reverse.winnerSideUsageRate, closeTo(1.0, 1e-9));
      expect(reverse.loserSideUsageRate, closeTo(0.0, 1e-9));
    });

    test('reverseフィールドが無い旧ログは分母から除外される', () {
      final records = [buildRecord(gameId: 'g1')];
      final reverse = ReverseAnalysis.compute(records);
      expect(reverse.saviorUsageRate, isNull);
      expect(reverse.neitherUsedRate, isNull);
    });
  });
}
