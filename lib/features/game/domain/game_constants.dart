import 'enums.dart';

/// ゲームの数値・枚数を一元管理（Ver.0.4）。
class GameConstants {
  GameConstants._();

  /// 中央の人間カード枚数（3×3）。
  static const int humanCardCount = 9;

  /// 各種類が持つ得点（善人/中立/悪人それぞれ 1・2・3 の3枚ずつ）。
  static const List<int> pointValues = [1, 2, 3];

  /// 手札：生・死・保を各何枚持つか。
  static const int handPerActionType = 3;

  /// アクションカードの一覧（各3枚ずつ・計9枚）。
  static const List<ActionType> handComposition = [
    ActionType.life,
    ActionType.life,
    ActionType.life,
    ActionType.death,
    ActionType.death,
    ActionType.death,
    ActionType.protect,
    ActionType.protect,
    ActionType.protect,
  ];
}
