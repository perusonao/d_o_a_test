import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_evaluator.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/heuristic_cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Section 14/15: difficulty-tiered choice variance — HeuristicCpuStrategy no
/// longer always takes the literal best-scoring candidate; it samples among
/// the top-ranked ones according to CpuProfile.selectionWeights, using the
/// same shared/seeded Random every other CPU decision uses (so a fixed seed
/// still reproduces the exact same sequence of choices).
void main() {
  CpuGameView twoSlotView() => CpuGameView(
    faction: Faction.savior,
    slots: [
      CpuSlotView(
        index: 0,
        person: const PersonCard(
          id: 'p0',
          attribute: PersonAttribute.good,
          verdictState: VerdictState.deliberating,
        ),
        knownAttribute: PersonAttribute.good,
      ),
      CpuSlotView(
        index: 1,
        person: const PersonCard(
          id: 'p1',
          attribute: PersonAttribute.neutral,
          verdictState: VerdictState.deliberating,
        ),
        knownAttribute: PersonAttribute.neutral,
      ),
    ],
    legalTargets: const {
      ActionType.life: [0, 1],
    },
    currentBonus: 5,
    specialVerdictAvailable: false,
  );

  test('同じseedなら同じ候補列に対して常に同じ選択結果になる(再現性)', () {
    final view = twoSlotView();
    final decisionA = HeuristicCpuStrategy(
      CpuProfile.balanced,
      Random(42),
    ).decideAction(view);
    final decisionB = HeuristicCpuStrategy(
      CpuProfile.balanced,
      Random(42),
    ).decideAction(view);

    expect(decisionA.action, decisionB.action);
    expect(decisionA.targetIndex, decisionB.targetIndex);
    expect(decisionA.score, decisionB.score);
  });

  test('Randomを渡さない場合は常に最高評価の候補を選ぶ(既存呼び出し側との後方互換)', () {
    final view = twoSlotView();
    const strategy = HeuristicCpuStrategy(CpuProfile.expert);
    final candidates = strategy.evaluateActions(view)
      ..sort((a, b) => b.score.compareTo(a.score));
    final decision = strategy.decideAction(view);
    expect(decision.score, candidates.first.score);
  });

  test('selectionWeightsが均等に近いプロファイルほど上位以外の候補も選ばれやすい', () {
    // 2つのほぼ同点の候補を用意し、幅の広い(balanced寄りの)重みでは何度か
    // 試行すると1位以外も選ばれる一方、ほぼ決定的な(expert寄りの)重みでは
    // ほとんど常に1位が選ばれることを確認する。
    const wideProfile = CpuProfile(
      eyeValue: 1,
      lockBonus: 1,
      giveawayPenalty: 1,
      progressValue: 1,
      setupBonus: 1,
      bonusWeight: 1,
      judgePremium: 1,
      judgeMinBonus: 1,
      reverseCost: 1,
      reverseKeyValue: 1,
      blindValue: 1,
      threatWeight: 0,
      jitter: 0,
      selectionWeights: [0.5, 0.5],
    );
    const narrowProfile = CpuProfile(
      eyeValue: 1,
      lockBonus: 1,
      giveawayPenalty: 1,
      progressValue: 1,
      setupBonus: 1,
      bonusWeight: 1,
      judgePremium: 1,
      judgeMinBonus: 1,
      reverseCost: 1,
      reverseKeyValue: 1,
      blindValue: 1,
      threatWeight: 0,
      jitter: 0,
      selectionWeights: [0.98, 0.02],
    );
    final view = twoSlotView();

    int countSecondPicked(CpuProfile profile, int seed) {
      var count = 0;
      const trials = 200;
      final random = Random(seed);
      for (var i = 0; i < trials; i++) {
        final decision = HeuristicCpuStrategy(
          profile,
          random,
        ).decideAction(view);
        if (decision.targetIndex == 1) count++;
      }
      return count;
    }

    final wideSecondPicks = countSecondPicked(wideProfile, 7);
    final narrowSecondPicks = countSecondPicked(narrowProfile, 7);

    expect(wideSecondPicks, greaterThan(narrowSecondPicks));
  });
}
