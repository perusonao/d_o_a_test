import 'enums.dart';

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

  // --- 運の比重を下げるためのバランス設定 ---
  //
  // これらを切り替えることで、ランダム性の強い旧仕様にも戻せる。

  /// B. 盤面の均等化：各プレイヤーの場に配置する「各種類」の枚数。
  /// personTypeCountPerPlayer × 種類数(3) = personCardsPerPlayer になるようにする。
  /// 例: 3 なら 善人3 / 悪人3 / 中立3 で計9枚。
  static const int personTypeCountPerPlayer = 3;

  /// A. 手札の均等化：両プレイヤーに配る共通の生死カードテンプレート。
  /// 効果ごとに低・中・高の数字を持たせ、引き運を排除する。
  /// 高い数字(9)を各効果に1枚入れることで、どの人カードも狙える余地を残す。
  static const List<({LifeDeathEffect effect, int number})> balancedHand = [
    (effect: LifeDeathEffect.dead, number: 3),
    (effect: LifeDeathEffect.dead, number: 6),
    (effect: LifeDeathEffect.dead, number: 9),
    (effect: LifeDeathEffect.alive, number: 3),
    (effect: LifeDeathEffect.alive, number: 6),
    (effect: LifeDeathEffect.alive, number: 9),
    (effect: LifeDeathEffect.keep, number: 3),
    (effect: LifeDeathEffect.keep, number: 6),
    (effect: LifeDeathEffect.keep, number: 9),
  ];

  /// C. 開始時に人カードの数字を公開するか（種類は伏せたまま）。
  /// true の場合、当てずっぽうを減らし「種類の推理」に集中させる。
  static const bool revealNumbersAtStart = true;
}
