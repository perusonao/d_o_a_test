import 'enums.dart';

/// ゲーム終了時の集計結果（Ver.0.3・得点方式）。
class GameResult {
  const GameResult({
    required this.saviorScore,
    required this.executionerScore,
    required this.winnerRole, // null なら引き分け
    required this.playerRole,
    required this.playerScore,
    required this.cpuScore,
    required this.aliveGood,
    required this.aliveEvil,
    required this.aliveNeutral,
    required this.deadGood,
    required this.deadEvil,
    required this.deadNeutral,
  });

  final int saviorScore;
  final int executionerScore;

  /// 勝者の役割。引き分けは null。
  final Role? winnerRole;

  final Role playerRole;
  final int playerScore;
  final int cpuScore;

  final int aliveGood;
  final int aliveEvil;
  final int aliveNeutral;
  final int deadGood;
  final int deadEvil;
  final int deadNeutral;

  bool get isDraw => winnerRole == null;
  bool get playerWon => !isDraw && winnerRole == playerRole;
}
