import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

abstract final class NineJudgesConfig {
  static const String gameVersion = '1.1.0-prototype';
  static const String rulesVersion = '1.1';
  static const Faction defaultFirstPlayer = Faction.savior;
  static const int personCount = 9;
  static const int specialVerdictsPerPlayer = 1;
  static const List<int> verdictBonuses = [1, 2, 3, 4, 5, 6, 7, 8, 9];
}
