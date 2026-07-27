import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/cpu/cpu_evaluator.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/heuristic_cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/cpu/random_cpu_strategy.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class CpuPlayer {
  static CpuStrategy strategyFor(CpuLevel level, Random random) =>
      switch (level) {
        CpuLevel.random => RandomCpuStrategy(random),
        CpuLevel.balanced => HeuristicCpuStrategy(CpuProfile.balanced, random),
        CpuLevel.aggressive => HeuristicCpuStrategy(
          CpuProfile.aggressive,
          random,
        ),
        CpuLevel.defensive => HeuristicCpuStrategy(
          CpuProfile.defensive,
          random,
        ),
        CpuLevel.expert => HeuristicCpuStrategy(CpuProfile.expert, random),
      };
}
