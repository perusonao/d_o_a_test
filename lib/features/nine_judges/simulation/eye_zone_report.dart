import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';

/// rulesVersion 1.2-specific EYE/center-zone metrics, computed additively
/// from [SimulationResult.actions]. Kept separate from [SimulationStatistics]
/// so the existing (v1.1-era) report format and its consumers never change.
class EyeZoneReport {
  const EyeZoneReport._(this.values);

  final Map<String, Object> values;

  factory EyeZoneReport.fromResults(List<SimulationResult> results) {
    final games = results.length;
    double rate(int value, int denominator) =>
        denominator == 0 ? 0 : value / denominator;
    double average(List<int> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    int eyeUsesFor(SimulationResult result, Faction faction) => result.actions
        .where(
          (action) => action.faction == faction && action.action == ActionType.eye,
        )
        .length;

    final playerEyeUses = [
      for (final result in results) ...[
        eyeUsesFor(result, Faction.savior),
        eyeUsesFor(result, Faction.executor),
      ],
    ];
    final playerSlots = playerEyeUses.length;

    final centerEyedCounts = <int>[];
    final eyeBeforeFirstConfirm = <int>[];
    final confirmationOrderCenterCounts = List<int>.filled(9, 0);

    for (final result in results) {
      final eyedIndices = result.actions
          .where((action) => action.action == ActionType.eye)
          .map((action) => action.targetIndex)
          .toSet();
      centerEyedCounts.add(
        NineJudgesConfig.centerIndices.where(eyedIndices.contains).length,
      );

      var eyeCount = 0;
      for (final action in result.actions) {
        if (action.action == ActionType.eye) eyeCount++;
        if (action.confirmedThisAction) break;
      }
      eyeBeforeFirstConfirm.add(eyeCount);

      for (final action in result.actions) {
        final order = action.confirmationOrder;
        if (order == null) continue;
        if (NineJudgesConfig.centerIndices.contains(action.targetIndex)) {
          confirmationOrderCenterCounts[order - 1]++;
        }
      }
    }

    return EyeZoneReport._({
      'gameCount': games,
      'eye0UseRate': rate(playerEyeUses.where((u) => u == 0).length, playerSlots),
      'eye1UseRate': rate(playerEyeUses.where((u) => u == 1).length, playerSlots),
      'eye2UseRate': rate(playerEyeUses.where((u) => u == 2).length, playerSlots),
      'centerPersonsEyedAverage': average(centerEyedCounts),
      'centerPersonsNeverEyedAverage': average(
        centerEyedCounts.map((c) => 3 - c).toList(),
      ),
      'allThreeCenterEyedRate': rate(
        centerEyedCounts.where((c) => c == 3).length,
        games,
      ),
      'noCenterEyedRate': rate(
        centerEyedCounts.where((c) => c == 0).length,
        games,
      ),
      'averageEyeCountBeforeFirstConfirmation': average(eyeBeforeFirstConfirm),
      'centerConfirmationOrderRate': {
        for (var i = 0; i < 9; i++) '${i + 1}': rate(confirmationOrderCenterCounts[i], games),
      },
    });
  }

  Map<String, Object> toJson() => values;

  String toConsoleReport() {
    String percent(String key) =>
        '${((values[key]! as num) * 100).toStringAsFixed(1)}%';
    String number(String key) => (values[key]! as num).toStringAsFixed(2);
    return '''
--------------------------------------------------
EYE / CENTER ZONE (rulesVersion 1.2)
--------------------------------------------------
EYE uses per player-slot   0:${percent('eye0UseRate')}  1:${percent('eye1UseRate')}  2:${percent('eye2UseRate')}
Center persons EYE'd       avg ${number('centerPersonsEyedAverage')} / 3
Center persons never EYE'd avg ${number('centerPersonsNeverEyedAverage')} / 3
All 3 center EYE'd         ${percent('allThreeCenterEyedRate')}
No center EYE'd            ${percent('noCenterEyedRate')}
Avg EYE before 1st confirm ${number('averageEyeCountBeforeFirstConfirmation')}
--------------------------------------------------''';
  }
}

/// Wilson 95% confidence interval for a binomial win-rate, mirroring the
/// formula already used by the experimental report
/// (simulation/experiments/experiment_statistics.dart) so both tools agree
/// numerically without importing across the production/experimental split.
Map<String, double> wilson95(int successes, int total) {
  if (total == 0) return {'lower': 0, 'upper': 0};
  const z = 1.959963984540054;
  final p = successes / total;
  final denominator = 1 + z * z / total;
  final center = (p + z * z / (2 * total)) / denominator;
  final margin =
      z * sqrt((p * (1 - p) + z * z / (4 * total)) / total) / denominator;
  return {'lower': center - margin, 'upper': center + margin};
}
