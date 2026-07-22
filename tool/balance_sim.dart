// ignore_for_file: avoid_print
//
// Ver.0.3 バランス検証シミュレーション。
//
// 実際の GameEngine / DefaultCpuStrategy を用いて多数対戦を回し、
// DESIGN.md §14 の指標（役職勝率 / 先手勝率 / 同点率 / 情報アドバンテージの効き）を集計する。
//
// 実行: dart run tool/balance_sim.dart [games]
import 'dart:math';

import 'package:dead_or_alive/features/game/application/cpu_strategy.dart';
import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_constants.dart';
import 'package:dead_or_alive/features/game/domain/game_result.dart';

/// 1試合を2つの戦略で最後までプレイし、結果を返す。
GameResult playGame(
  Role playerRole,
  CpuStrategy playerStrat,
  CpuStrategy cpuStrat,
  Random rng,
) {
  final engine = GameEngine(random: rng);
  var gs = engine.startGame(playerRole);
  var guard = 0;
  while (gs.phase != GamePhase.finished && guard < 500) {
    final actor =
        gs.phase == GamePhase.cpuTurn ? TurnOwner.cpu : TurnOwner.player;
    final strat = actor == TurnOwner.player ? playerStrat : cpuStrat;
    final decision = strat.decide(gs, actor);
    if (decision == null) {
      gs = engine.advanceTurn(gs, actor);
    } else {
      gs = engine.performAction(gs, decision.action);
      gs = engine.advanceTurn(gs, actor);
    }
    guard++;
  }
  return engine.rules.score(gs.persons, gs.player.role);
}

String pct(int n, int d) =>
    d == 0 ? '-' : '${(100 * n / d).toStringAsFixed(1)}%';

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 4000;
  final weakRole = GameConstants.weakRole;

  // --- 指標1〜3: 両席とも通常CPU（既知情報を使う） ---
  {
    final rng = Random(777);
    final smart = DefaultCpuStrategy(random: rng);
    var saviorWins = 0, execWins = 0, draws = 0;
    var firstWins = 0, decided = 0;
    for (var i = 0; i < games; i++) {
      final playerRole = i.isEven ? Role.savior : Role.executioner;
      final r = playGame(playerRole, smart, smart, rng);
      if (r.isDraw) {
        draws++;
      } else if (r.winnerRole == Role.savior) {
        saviorWins++;
      } else {
        execWins++;
      }
      // 先手＝弱い役。プレイヤーが弱い役なら先手はプレイヤー席。
      if (!r.isDraw) {
        decided++;
        final firstIsPlayer = playerRole == weakRole;
        final playerWon = r.winnerRole == playerRole;
        if (firstIsPlayer == playerWon) firstWins++;
      }
    }
    print('=== $games 戦（両者:通常CPU）===');
    print('救済者 勝率: ${pct(saviorWins, games)}  ($saviorWins)');
    print('執行者 勝率: ${pct(execWins, games)}  ($execWins)');
    print('引き分け : ${pct(draws, games)}  ($draws)');
    print('先手(=弱い役:${weakRole.name}) 勝率(決着のみ): ${pct(firstWins, decided)}');
    print('');
  }

  // --- 指標4: 情報アドバンテージの効き ---
  // 片方は既知情報を使う(smart)、もう片方は使わない(blind)。席と役割を均等に入れ替える。
  {
    final rng = Random(999);
    final smart = DefaultCpuStrategy(random: rng, useSecretKnowledge: true);
    final blind = DefaultCpuStrategy(random: rng, useSecretKnowledge: false);
    var smartWins = 0, blindWins = 0, draws = 0;
    for (var i = 0; i < games; i++) {
      // i の下位ビットで「席」と「役割」を均等割り当て。
      final smartIsPlayer = i.isEven;
      final playerRole = (i ~/ 2).isEven ? Role.savior : Role.executioner;
      final playerStrat = smartIsPlayer ? smart : blind;
      final cpuStrat = smartIsPlayer ? blind : smart;
      final r = playGame(playerRole, playerStrat, cpuStrat, rng);
      if (r.isDraw) {
        draws++;
        continue;
      }
      final playerWon = r.winnerRole == playerRole;
      final smartWon = (smartIsPlayer && playerWon) || (!smartIsPlayer && !playerWon);
      if (smartWon) {
        smartWins++;
      } else {
        blindWins++;
      }
    }
    final decided = smartWins + blindWins;
    print('=== 情報アドバンテージ検証（既知情報あり vs なし・$games 戦）===');
    print('情報あり 勝率(決着のみ): ${pct(smartWins, decided)}  ($smartWins)');
    print('情報なし 勝率(決着のみ): ${pct(blindWins, decided)}  ($blindWins)');
    print('引き分け : ${pct(draws, games)}');
    print('');
    print('→ 情報ありが 50% を明確に上回れば「推理が勝敗に効く＝核が機能」。');
  }
}
