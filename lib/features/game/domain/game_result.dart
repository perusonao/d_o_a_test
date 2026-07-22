import 'enums.dart';

/// ゲーム終了時の集計結果。
class GameResult {
  const GameResult({
    required this.winner,
    required this.playerFaction,
    required this.aliveGood,
    required this.aliveEvil,
    required this.aliveNeutral,
    required this.deadGood,
    required this.deadEvil,
    required this.deadNeutral,
    required this.usedCardsTotal,
    required this.discardedTotal,
    required this.playerWon,
  });

  /// 勝者陣営。
  final Faction winner;

  /// プレイヤーの陣営。
  final Faction playerFaction;

  /// 生存している善人・悪人・中立の人数。
  final int aliveGood;
  final int aliveEvil;
  final int aliveNeutral;

  /// 死亡している善人・悪人・中立の人数。
  final int deadGood;
  final int deadEvil;
  final int deadNeutral;

  /// 両者が使用した生死カードの合計枚数。
  final int usedCardsTotal;

  /// 両者がペナルティで破棄した合計枚数。
  final int discardedTotal;

  /// プレイヤーが勝利したか。
  final bool playerWon;
}
