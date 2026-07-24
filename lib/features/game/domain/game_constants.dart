import 'enums.dart';

/// ゲームの数値・枚数を一元管理（Ver.0.4）。
class GameConstants {
  GameConstants._();

  /// 中央の人間カード枚数（3×3）。
  static const int humanCardCount = 9;

  /// 各種類が持つ得点（善人/中立/悪人それぞれ 1・2・3 の3枚ずつ）。
  static const List<int> pointValues = [1, 2, 3];

  /// 手札の枚数（両陣営同じ枚数にすること。ターン数の公平性のため）。
  static const int handSize = 9;

  /// 救済者の手札構成（生が多め）。ここを編集して枚数調整する。
  static const List<ActionType> saviorHand = [
    ActionType.life,
    ActionType.life,
    ActionType.life,
    ActionType.life,
    ActionType.death,
    ActionType.death,
    ActionType.protect,
    ActionType.protect,
    ActionType.diagnose,
  ];

  /// 執行者の手札構成（死が多め）。
  static const List<ActionType> executionerHand = [
    ActionType.life,
    ActionType.life,
    ActionType.death,
    ActionType.death,
    ActionType.death,
    ActionType.death,
    ActionType.protect,
    ActionType.protect,
    ActionType.diagnose,
  ];

  /// 陣営に応じた手札構成を返す。
  static List<ActionType> handFor(Faction faction) =>
      faction == Faction.savior ? saviorHand : executionerHand;
}
