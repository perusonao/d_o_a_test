import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';

class RandomCpuStrategy implements CpuStrategy {
  RandomCpuStrategy([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  CpuDecision decideAction(CpuGameView view) {
    final candidates = evaluateActions(view);
    final selected = candidates[_random.nextInt(candidates.length)];
    return CpuDecision(
      action: selected.action,
      targetIndex: selected.targetIndex,
      score: selected.score,
    );
  }

  @override
  int decideJudgeTarget(CpuGameView view) {
    final targets = view.slots.where((slot) => !slot.person.isJudged).toList();
    return targets[_random.nextInt(targets.length)].index;
  }

  @override
  List<CpuCandidateScore> evaluateActions(CpuGameView view) => [
    for (final entry in view.legalTargets.entries)
      for (final target in entry.value)
        CpuCandidateScore(action: entry.key, targetIndex: target, score: 0),
  ];
}
