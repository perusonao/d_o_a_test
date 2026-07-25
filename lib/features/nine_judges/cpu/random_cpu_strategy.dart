import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

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
      eyeInformation: selected.eyeInformation,
    );
  }

  @override
  List<CpuCandidateScore> evaluateActions(CpuGameView view) => [
    for (final entry in view.legalTargets.entries)
      for (final target in entry.value)
        CpuCandidateScore(
          action: entry.key,
          targetIndex: target,
          score: 0,
          eyeInformation: entry.key == ActionType.eye
              ? view.slots[target].eyeOptions[_random.nextInt(
                  view.slots[target].eyeOptions.length,
                )]
              : null,
        ),
  ];
}
