import 'package:dead_or_alive/features/nine_judges/simulation/simulation_result.dart';

/// One experiment game's standard [SimulationResult] (so it can be fed
/// straight into the existing [SimulationStatistics] / [FirstSecondAnalysis]
/// pipeline unmodified) plus whatever experiment-specific numbers that
/// pipeline has no field for.
class ExperimentGameOutcome {
  const ExperimentGameOutcome({required this.result, required this.extras});

  final SimulationResult result;

  /// Experiment-specific, per-game figures. Keys present depend on which
  /// [SimulationExperimentConfig] toggles were active; see
  /// `experiment_runner.dart` for the keys each toggle writes.
  final Map<String, Object?> extras;
}
