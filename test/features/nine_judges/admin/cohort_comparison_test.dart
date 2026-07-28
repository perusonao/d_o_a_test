import 'package:dead_or_alive/features/nine_judges/admin/services/cohort_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('FirstTimeVsExperienced.compute', () {
    test('データが無ければ両コホートともデータ不足', () {
      final result = FirstTimeVsExperienced.compute(const []);
      expect(result.firstTime.hasEnoughData, isFalse);
      expect(result.experienced.hasEnoughData, isFalse);
    });

    test('isFirstGameとplayNumberのいずれかで初回/経験者を判定する', () {
      final records = [
        buildRecord(gameId: 'g1', isFirstGame: true, playNumber: 1),
        // isFirstGame missing but playNumber says first game.
        buildRecord(gameId: 'g2', isFirstGame: null, playNumber: 1),
        // isFirstGame missing but playNumber says experienced.
        buildRecord(gameId: 'g3', isFirstGame: null, playNumber: 3),
        buildRecord(gameId: 'g4', isFirstGame: false, playNumber: 2),
      ];
      final result = FirstTimeVsExperienced.compute(records);
      expect(result.firstTime.sampleSize, 2);
      expect(result.experienced.sampleSize, 2);
    });

    test('プレイヤー勝率はwinner==playerFactionで計算される', () {
      final records = [
        buildRecord(gameId: 'g1', playNumber: 1, playerFaction: 'savior', winner: 'savior'),
        buildRecord(gameId: 'g2', playNumber: 1, playerFaction: 'savior', winner: 'executor'),
      ];
      final result = FirstTimeVsExperienced.compute(records);
      expect(result.firstTime.playerWinRate, closeTo(0.5, 1e-9));
    });

    test('JUDGE使用率はプレイヤー側のフィールドのみ・null除外で計算される', () {
      final records = [
        buildRecord(
          gameId: 'g1',
          playNumber: 1,
          playerFaction: 'savior',
          saviorSpecialVerdictUsed: true,
        ),
        buildRecord(
          gameId: 'g2',
          playNumber: 1,
          playerFaction: 'executor',
          executorSpecialVerdictUsed: false,
        ),
        // no record for savior/executor usage -> excluded from denominator.
        buildRecord(gameId: 'g3', playNumber: 1),
      ];
      final result = FirstTimeVsExperienced.compute(records);
      expect(result.firstTime.judgeUsageRate, closeTo(0.5, 1e-9));
    });

    test('actions未取得ならavgEyeUsageはnull(データ不足)になる', () {
      final records = [buildRecord(gameId: 'g1', playNumber: 1)];
      final result = FirstTimeVsExperienced.compute(records);
      expect(result.firstTime.avgEyeUsage, isNull);
      expect(result.firstTime.avgEyeUsageSampleSize, 0);
    });

    test('actions取得済みのゲームのみでavgEyeUsageを集計する', () {
      final records = [
        buildRecord(
          gameId: 'g1',
          playNumber: 1,
          actionsLoaded: true,
          actions: [buildAction(actionType: 'eye'), buildAction(actionIndex: 1, actionType: 'eye')],
        ),
        // Not yet opened in the detail view -> excluded from the average.
        buildRecord(gameId: 'g2', playNumber: 1),
      ];
      final result = FirstTimeVsExperienced.compute(records);
      expect(result.firstTime.avgEyeUsageSampleSize, 1);
      expect(result.firstTime.avgEyeUsage, closeTo(2.0, 1e-9));
    });
  });
}
