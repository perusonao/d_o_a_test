import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class NineJudgesConfig {
  static const String gameVersion = '0.5.0';
  static const String rulesVersion = '0.5';
  static const bool numberCardsEnabled = false;

  static const int lifeCardsPerPlayer = 2;
  static const int deathCardsPerPlayer = 2;
  static const int eyeCardsPerPlayer = 1;
  static const int judgeCardsPerPlayer = 1;
  static const int maxActionsPerPlayer = 6;
  static const int maxTurns = maxActionsPerPlayer * 2;

  static const Map<int, bool> initialAliveByRank = {1: true, 2: true, 3: false};

  static const ActionInventory initialInventory = ActionInventory(
    life: lifeCardsPerPlayer,
    death: deathCardsPerPlayer,
    eye: eyeCardsPerPlayer,
    judge: judgeCardsPerPlayer,
  );
}
