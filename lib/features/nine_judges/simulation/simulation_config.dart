import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

enum SimulationFirstPlayer { alternate, random, savior, executor }

class SimulationConfig {
  const SimulationConfig({
    this.gameCount = 100,
    this.baseSeed = 1000,
    this.saviorDifficulty = CpuLevel.balanced,
    this.executorDifficulty = CpuLevel.balanced,
    this.firstPlayer = SimulationFirstPlayer.alternate,
    this.highBonusThreshold = 7,
    this.oneSidedThreshold = 15,
  }) : assert(gameCount > 0),
       assert(highBonusThreshold >= 1 && highBonusThreshold <= 9),
       assert(oneSidedThreshold >= 0);

  final int gameCount;
  final int baseSeed;
  final CpuLevel saviorDifficulty;
  final CpuLevel executorDifficulty;
  final SimulationFirstPlayer firstPlayer;
  final int highBonusThreshold;
  final int oneSidedThreshold;

  int seedFor(int gameIndex) => baseSeed + gameIndex;
}
