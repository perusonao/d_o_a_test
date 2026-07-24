import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class NineJudgesConfig {
  static const bool forceSaveEachTurn = true;
  static const int lifeCardsPerPlayer = 3;
  static const int deathCardsPerPlayer = 3;
  static const int judgeCardsPerPlayer = 2;

  static const Map<int, bool> initialAliveByRank = {1: true, 2: true, 3: false};

  static const Set<int> saviorKnownNumberSlots = {6, 7, 8};
  static const Set<int> executorKnownNumberSlots = {0, 1, 2};

  static const ActionInventory initialInventory = ActionInventory(
    life: lifeCardsPerPlayer,
    death: deathCardsPerPlayer,
    judge: judgeCardsPerPlayer,
  );
}
