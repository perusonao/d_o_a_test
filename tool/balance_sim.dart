// ignore_for_file: avoid_print
//
// 陣営バランスの簡易シミュレーション。
//
// 実際の GameEngine / CpuActionEvaluator を用いて、両席とも同じ評価ロジックで
// プレイした対戦を多数回し、陣営別・席順別の勝率を集計する。
//
// 実行: dart run tool/balance_sim.dart [games]
import 'dart:math';

import 'package:dead_or_alive/features/game/application/cpu_strategy.dart';
import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/game_action.dart';
import 'package:dead_or_alive/features/game/domain/game_state.dart';
import 'package:dead_or_alive/features/game/domain/life_death_card.dart';

const evaluator = CpuActionEvaluator();

/// 指定した席（actor）の行動を、CPU と同じ評価ロジックで決定する。
GameAction? decideFor(GameState state, TurnOwner actor, Random rng) {
  final self = state.stateOf(actor);
  final opponent = actor == TurnOwner.player ? TurnOwner.cpu : TurnOwner.player;
  final targets = state.stateOf(opponent).persons;
  final usable = self.usableCards;
  if (usable.isEmpty || targets.isEmpty) return null;

  LifeDeathCard? bestCard;
  var bestTargetId = '';
  var bestScore = double.negativeInfinity;
  for (final card in usable) {
    for (final t in targets) {
      final s = evaluator.evaluate(
          cpuFaction: self.faction, card: card, target: t);
      if (s > bestScore) {
        bestScore = s;
        bestCard = card;
        bestTargetId = t.id;
      }
    }
  }
  if (bestCard == null || bestScore <= 0) {
    final card = usable[rng.nextInt(usable.length)];
    final t = targets[rng.nextInt(targets.length)];
    return GameAction(
      actor: actor,
      lifeDeathCardId: card.id,
      targetPersonId: t.id,
      targetOwner: opponent,
    );
  }
  return GameAction(
    actor: actor,
    lifeDeathCardId: bestCard.id,
    targetPersonId: bestTargetId,
    targetOwner: opponent,
  );
}

({Faction winner, bool tie, int aliveGood, int aliveEvil}) playGame(
    Faction playerFaction, Random rng) {
  final engine = GameEngine(random: rng);
  var gs = engine.startGame(playerFaction);
  var guard = 0;
  while (gs.phase != GamePhase.finished && guard < 500) {
    final actor =
        gs.phase == GamePhase.cpuTurn ? TurnOwner.cpu : TurnOwner.player;
    final action = decideFor(gs, actor, rng);
    if (action == null) {
      gs = engine.advanceTurn(gs, actor);
    } else {
      gs = engine.performAction(gs, action);
      gs = engine.advanceTurn(gs, actor);
    }
    guard++;
  }
  final r = engine.rules.judgeResult(gs.player, gs.cpu);
  return (
    winner: r.winner,
    tie: r.aliveGood == r.aliveEvil,
    aliveGood: r.aliveGood,
    aliveEvil: r.aliveEvil,
  );
}

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 4000;
  final rng = Random(12345);

  var goodWins = 0, evilWins = 0, ties = 0;
  var playerWins = 0, cpuWins = 0;
  var goodAsPlayerWins = 0, goodAsCpuWins = 0;
  final half = games ~/ 2;

  // 前半: プレイヤー席=善人 / 後半: プレイヤー席=悪人（席順の影響を分離）。
  for (var i = 0; i < games; i++) {
    final playerFaction = i < half ? Faction.good : Faction.evil;
    final res = playGame(playerFaction, rng);
    if (res.winner == Faction.good) {
      goodWins++;
    } else {
      evilWins++;
    }
    if (res.tie) ties++;

    final playerWon = res.winner == playerFaction;
    if (playerWon) {
      playerWins++;
    } else {
      cpuWins++;
    }
    if (playerFaction == Faction.good && res.winner == Faction.good) {
      goodAsPlayerWins++;
    }
    if (playerFaction == Faction.evil && res.winner == Faction.good) {
      goodAsCpuWins++; // 善人が CPU 席のときに善人が勝った回数
    }
  }

  String pct(int n, int d) => '${(100 * n / d).toStringAsFixed(1)}%';

  print('=== $games 戦の結果 ===');
  print('善人陣営 勝率: ${pct(goodWins, games)}  ($goodWins)');
  print('悪人陣営 勝率: ${pct(evilWins, games)}  ($evilWins)');
  print('（うち同数=引き分け裁定で悪人勝ち: ${pct(ties, games)}）');
  print('');
  print('--- 席順の影響（先攻=プレイヤー席）---');
  print('プレイヤー席(先攻) 勝率: ${pct(playerWins, games)}');
  print('CPU席(後攻)      勝率: ${pct(cpuWins, games)}');
  print('');
  print('--- 陣営×席順の交互作用 ---');
  print('善人が先攻(プレイヤー席)のとき 善人勝率: ${pct(goodAsPlayerWins, half)}');
  print('善人が後攻(CPU席)のとき     善人勝率: ${pct(goodAsCpuWins, half)}');
}
