import 'enums.dart';

/// ゲーム終了時の集計結果（Ver.0.4）。
class GameResult {
  const GameResult({
    required this.saviorScore,
    required this.executionerScore,
    required this.winner, // null は引き分け
    required this.playerAFaction,
    required this.playerBFaction,
  });

  final int saviorScore;
  final int executionerScore;

  /// 勝者の陣営。引き分けは null。
  final Faction? winner;

  final Faction playerAFaction;
  final Faction playerBFaction;

  bool get isDraw => winner == null;

  int scoreOf(Faction f) =>
      f == Faction.savior ? saviorScore : executionerScore;

  int scoreOfPlayer(PlayerId id) =>
      scoreOf(id == PlayerId.a ? playerAFaction : playerBFaction);
}
