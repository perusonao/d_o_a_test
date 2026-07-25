import 'package:dead_or_alive/features/nine_judges/cpu/cpu_evaluator.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class BasicCpuStrategy implements CpuStrategy {
  const BasicCpuStrategy();

  @override
  CpuDecision decideAction(CpuGameView view) {
    final candidates = evaluateActions(view)
      ..sort((a, b) => b.score.compareTo(a.score));
    final selected = candidates.first;
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
          score: CpuEvaluator.actionScore(view, entry.key, view.slots[target]),
          eyeInformation: entry.key == ActionType.eye
              ? CpuEvaluator.preferredEyeInformation(view.slots[target])
              : null,
        ),
  ];
}
