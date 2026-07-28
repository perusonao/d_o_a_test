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
    // Defaults to v1.1 — not the app's default — so every simulation tool
    // and test already in this repo keeps reproducing exactly the numbers
    // it always has unless it explicitly opts into rulesVersion 1.2.
    this.ruleVersion = NineJudgesRuleVersion.v1_1,
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
  final NineJudgesRuleVersion ruleVersion;

  int seedFor(int gameIndex) => baseSeed + gameIndex;
}
