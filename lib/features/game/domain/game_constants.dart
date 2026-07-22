/// ゲームルールの数値・枚数を一元管理する定数群。
///
/// バランス調整やルール変更はこのファイルを編集するだけで済むようにする。
class GameConstants {
  GameConstants._();

  /// 人カードの数字の下限・上限。
  static const int personNumberMin = 1;
  static const int personNumberMax = 9;

  /// 生死カードの数字の下限・上限。
  static const int lifeDeathNumberMin = 1;
  static const int lifeDeathNumberMax = 9;

  /// 各プレイヤーの場に並べる人カード枚数。
  static const int personCardsPerPlayer = 9;

  /// 各プレイヤーに配る生死カードの手札枚数。
  static const int lifeDeathHandSize = 9;

  /// 生死カードの各効果を最低何枚保証するか。
  static const int minDeadCards = 2;
  static const int minAliveCards = 2;
  static const int minKeepCards = 2;

  /// 中立ペナルティで破棄する最大枚数。
  static const int neutralPenaltyDiscardMax = 3;

  /// 画面に表示するログの件数。
  static const int visibleLogCount = 3;
}
