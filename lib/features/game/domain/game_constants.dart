import 'enums.dart';

/// ゲームルールの数値・枚数を一元管理する定数群（Ver.0.3 MVP）。
///
/// バランス調整やルール変更はこのファイルを編集するだけで済むようにする。
/// §番号は DESIGN.md の節に対応する。
class GameConstants {
  GameConstants._();

  /// 人カードの数字の範囲。
  static const int personNumberMin = 1;
  static const int personNumberMax = 9;

  /// 中央に並べる人カード枚数（3×3）。
  static const int personCardCount = 9;

  /// 各種類（善人・悪人・中立）の枚数。
  static const int perTypeCount = 3;

  /// 各プレイヤーが開始時に秘密裏に確認する枚数（§2）。
  static const int secretKnownPerPlayer = 3;

  // --- 得点係数（§11） ---

  /// 主要目標（善人）の点数。
  static const int scoreGood = 2;

  /// 補助目標（悪人・中立）の点数。
  static const int scoreSideEvil = 1;
  static const int scoreSideNeutral = 1;

  // --- 手番・手札（§6, §12） ---

  /// 弱い役（先手・最終手番・+1アクション）に与える役割。
  /// シミュレーションの結果、執行者（善人=2点を能動的に狩る側）が強いと判明したため、
  /// 補正は救済者に与える（§15）。
  static const Role weakRole = Role.savior;

  /// 弱い役の生死カード手札（両者同一の固定配分・§12）。
  /// デッド{3,6,9} / アライブ{2,5,8} / シール{7}。
  static const List<({LifeDeathEffect effect, int number})> weakHand = [
    (effect: LifeDeathEffect.dead, number: 3),
    (effect: LifeDeathEffect.dead, number: 6),
    (effect: LifeDeathEffect.dead, number: 9),
    (effect: LifeDeathEffect.alive, number: 2),
    (effect: LifeDeathEffect.alive, number: 5),
    (effect: LifeDeathEffect.alive, number: 8),
    (effect: LifeDeathEffect.seal, number: 7),
  ];

  /// 強い役の手札：弱い役テンプレートから1枚減（§12。減らす札は調整変数）。
  /// ここでは alive5 を除いた6枚。
  static const List<({LifeDeathEffect effect, int number})> strongHand = [
    (effect: LifeDeathEffect.dead, number: 3),
    (effect: LifeDeathEffect.dead, number: 6),
    (effect: LifeDeathEffect.dead, number: 9),
    (effect: LifeDeathEffect.alive, number: 2),
    (effect: LifeDeathEffect.alive, number: 8),
    (effect: LifeDeathEffect.seal, number: 7),
  ];

  /// 画面に表示するログの件数。
  static const int visibleLogCount = 3;
}
