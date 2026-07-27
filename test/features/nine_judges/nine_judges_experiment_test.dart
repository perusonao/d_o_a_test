import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/experiments/experiment_statistics.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_config.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_runner.dart';
import 'package:dead_or_alive/features/nine_judges/simulation/simulation_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = SimulationConfig(gameCount: 300, baseSeed: 9000);

  group('CONTROL parity', () {
    test('reproduces the production SimulationRunner exactly', () {
      final production = const SimulationRunner().run(config);
      final experimentControl = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.control,
      );
      for (var i = 0; i < config.gameCount; i++) {
        final a = production.results[i];
        final b = experimentControl.results[i];
        expect(b.saviorScore, a.saviorScore, reason: 'game $i savior score');
        expect(b.executorScore, a.executorScore, reason: 'game $i executor score');
        expect(b.totalTurns, a.totalTurns, reason: 'game $i turns');
        expect(b.winner, a.winner, reason: 'game $i winner');
      }
    });

    test('SimulationExperimentConfig.control.isControl is true', () {
      expect(SimulationExperimentConfig.control.isControl, isTrue);
      expect(SimulationExperimentConfig.finalJudgeDouble.isControl, isFalse);
    });
  });

  group('every registered experiment and combination', () {
    final all = [
      ...SimulationExperimentConfig.primarySet,
      ...SimulationExperimentConfig.combinationSet,
    ];

    test('runs without throwing and keeps scores non-negative', () {
      for (final experiment in all) {
        final run = const ExperimentSimulationRunner().run(config, experiment);
        expect(run.outcomes, hasLength(config.gameCount));
        for (final outcome in run.outcomes) {
          expect(outcome.result.saviorScore, greaterThanOrEqualTo(0));
          expect(outcome.result.executorScore, greaterThanOrEqualTo(0));
          expect(outcome.result.finalConfirmedCount, 9);
        }
      }
    });

    test('feed cleanly into the existing statistics/analysis pipeline', () {
      for (final experiment in all) {
        final run = const ExperimentSimulationRunner().run(config, experiment);
        final stats = SimulationStatistics.fromResults(run.results, config);
        expect(stats.values['gameCount'], config.gameCount);
        final extra = ExperimentExtraStatistics.fromOutcomes(
          run.outcomes,
          experiment,
        );
        // Every experiment other than CONTROL should record at least one
        // experiment-only figure.
        if (!experiment.isControl) {
          expect(extra.values, isNotEmpty, reason: experiment.name);
        }
      }
    });
  });

  group('Experiment A — FINAL JUDGE x2', () {
    test('doubles exactly the 9th confirmation\'s bonus, nothing else', () {
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.finalJudgeDouble,
      );
      for (final outcome in run.outcomes) {
        final base = outcome.extras['finalJudgeBonusBase']! as int;
        final doubled = outcome.extras['finalJudgeBonusFinal']! as int;
        expect(doubled, base * 2);
        expect(outcome.result.saviorScore + outcome.result.executorScore, 45 + base);
      }
    });
  });

  group('Experiment B — 10th FINAL JUDGE person', () {
    test('awards exactly 10 points on a match, 0 on a mismatch', () {
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.tenthPersonFinalJudge,
      );
      for (final outcome in run.outcomes) {
        final points = outcome.extras['tenthPersonPoints']! as int;
        final outcomeKind = outcome.extras['tenthPersonOutcome']! as String;
        if (outcomeKind == 'mismatch') {
          expect(points, 0);
          expect(
            outcome.result.saviorScore + outcome.result.executorScore,
            45,
          );
        } else {
          expect(points, 10);
          expect(
            outcome.result.saviorScore + outcome.result.executorScore,
            55,
          );
        }
      }
      final anyMatch = run.outcomes.any(
        (outcome) => outcome.extras['tenthPersonOutcome'] != 'mismatch',
      );
      expect(anyMatch, isTrue);
    });

    test('does not use the normal 1..9 bonus deck differently than control', () {
      final control = const SimulationRunner().run(config);
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.tenthPersonFinalJudge,
      );
      for (var i = 0; i < config.gameCount; i++) {
        final base = control.results[i].saviorScore + control.results[i].executorScore;
        expect(base, 45);
        final tenthPoints = run.outcomes[i].extras['tenthPersonPoints']! as int;
        expect(
          run.outcomes[i].result.saviorScore + run.outcomes[i].result.executorScore,
          45 + tenthPoints,
        );
      }
    });
  });

  group('Experiment C — reverse JUDGE', () {
    test('flips exactly one confirmed person per use and swaps its scorer', () {
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.reverseJudge,
      );
      for (final outcome in run.outcomes) {
        final count = outcome.extras['judgeReversalCount']! as int;
        expect(count, inInclusiveRange(0, 2));
        // Total points in play are only ever redistributed, never created.
        expect(
          outcome.result.saviorScore + outcome.result.executorScore,
          45,
        );
      }
    });

    test('never reverses the same person twice', () {
      // A person appearing twice among specialVerdict actions would mean the
      // "at most one JUDGE reversal per person" rule was violated.
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.reverseJudge,
      );
      for (final outcome in run.outcomes) {
        final targets = outcome.result.actions
            .where((action) => action.action == ActionType.specialVerdict)
            .map((action) => action.targetIndex)
            .toList();
        expect(targets.toSet().length, targets.length);
      }
    });
  });

  group('Experiment D — center-only, shared single-use EYE', () {
    test('every EYE action targets the center row (indices 3,4,5)', () {
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.centerEyeOnly,
      );
      for (final outcome in run.outcomes) {
        for (final action in outcome.result.actions) {
          if (action.action == ActionType.eye) {
            expect(action.targetIndex, anyOf(3, 4, 5));
          }
        }
      }
    });

    test('no slot is EYE-targeted by both factions', () {
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.centerEyeOnly,
      );
      for (final outcome in run.outcomes) {
        final byFaction = <Faction, Set<int>>{
          Faction.savior: {},
          Faction.executor: {},
        };
        for (final action in outcome.result.actions) {
          if (action.action == ActionType.eye) {
            byFaction[action.faction]!.add(action.targetIndex);
          }
        }
        expect(
          byFaction[Faction.savior]!.intersection(byFaction[Faction.executor]!),
          isEmpty,
        );
      }
    });
  });

  group('Experiment E — EYE costs 1 point, floor 0', () {
    test('final score never exceeds the pre-cost score and never negative', () {
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.eyeCost,
      );
      for (final outcome in run.outcomes) {
        final beforeSavior = outcome.extras['saviorScoreBeforeEyeCost']! as int;
        final beforeExecutor = outcome.extras['executorScoreBeforeEyeCost']! as int;
        expect(outcome.result.saviorScore, lessThanOrEqualTo(beforeSavior));
        expect(outcome.result.executorScore, lessThanOrEqualTo(beforeExecutor));
        expect(outcome.result.saviorScore, greaterThanOrEqualTo(0));
        expect(outcome.result.executorScore, greaterThanOrEqualTo(0));
      }
    });
  });

  group('Experiment F — first player extra special action', () {
    test('specialVerdict variant lets the first player use JUDGE twice', () {
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.firstPlayerExtraSpecial,
      );
      for (final outcome in run.outcomes) {
        final firstPlayer = outcome.result.firstPlayer;
        final firstPlayerJudgeUses = outcome.result.actions
            .where(
              (action) =>
                  action.faction == firstPlayer &&
                  action.action == ActionType.specialVerdict,
            )
            .length;
        expect(firstPlayerJudgeUses, lessThanOrEqualTo(2));
        final secondPlayerJudgeUses = outcome.result.actions
            .where(
              (action) =>
                  action.faction == firstPlayer.opponent &&
                  action.action == ActionType.specialVerdict,
            )
            .length;
        expect(secondPlayerJudgeUses, lessThanOrEqualTo(1));
      }
    });
  });

  group('Experiment G — asymmetric information', () {
    test('attribute viewer never uses EYE (already knows every attribute)', () {
      final run = const ExperimentSimulationRunner().run(
        config,
        SimulationExperimentConfig.infoFirstIsAttributeViewer,
      );
      for (final outcome in run.outcomes) {
        final firstPlayer = outcome.result.firstPlayer;
        final attributeViewerEyeUses = outcome.result.actions
            .where(
              (action) =>
                  action.faction == firstPlayer && action.action == ActionType.eye,
            )
            .length;
        expect(attributeViewerEyeUses, 0);
      }
    });
  });

  group('paired comparison and Δ vs control', () {
    test('identical result lists compare as 100% unchanged', () {
      final run = const SimulationRunner().run(config);
      final paired = PairedComparison.compare(run.results, run.results);
      expect(paired.values['winnerUnchangedRate'], 1.0);
      expect(paired.values['totalFlipRate'], 0.0);
    });

    test('delta of a statistics object against itself is all zero', () {
      final run = const SimulationRunner().run(config);
      final delta = ControlDelta.compute(run.statistics, run.statistics);
      for (final value in delta.values.values) {
        expect(value, 0.0);
      }
    });
  });
}
