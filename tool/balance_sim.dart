// ignore_for_file: avoid_print
//
// Ver.1.0 バランス計測シミュレーション。
//
// 実際の GameEngine / CpuStrategy で両席を自動プレイし、
// 役職勝率・先手/後手勝率・同点率、および「診」「保」の有効率を集計する。
//
// 実行: dart run tool/balance_sim.dart [games]
import 'dart:math';

import 'package:dead_or_alive/features/game/application/cpu_strategy.dart';
import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';

class _Prot {
  _Prot(this.owner, this.pos);
  final PlayerId owner;
  final int pos;
  bool absorbed = false;
}

class _Diag {
  _Diag(this.owner, this.pos);
  final PlayerId owner;
  final int pos;
  bool actedUpon = false;
}

bool _wantAlive(HumanType type, bool saviorSide) {
  // 救済者：善人・中立を生存、悪人を死亡。
  if (saviorSide) return type != HumanType.evil;
  return type == HumanType.evil;
}

String pct(num n, num d) =>
    d == 0 ? '-' : '${(100 * n / d).toStringAsFixed(1)}%';

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 5000;
  final rng = Random(2024);
  final strat = CpuStrategy(random: rng);

  var saviorW = 0, execW = 0, draw = 0;
  var aW = 0, bW = 0;
  // 役職×席順の交互作用。
  var saviorWinsAsA = 0, saviorGamesAsA = 0;
  var saviorWinsAsB = 0, saviorGamesAsB = 0;

  var protPlaced = 0, protAbsorbed = 0, protFavorable = 0;
  var diagPlaced = 0, diagActed = 0;
  var marginSum = 0.0;
  var revealedSum = 0;

  for (var g = 0; g < games; g++) {
    final aFaction = g.isEven ? Faction.savior : Faction.executioner;
    final engine = GameEngine(random: rng);
    var s = engine.setup(aFaction, vsCpu: false);
    s = engine.confirmPeek(s); // peekA -> peekB
    s = engine.confirmPeek(s); // peekB -> playing

    final prots = <_Prot>[];
    final diags = <_Diag>[];
    var guard = 0;
    while (s.phase != GamePhase.finished && guard < 100) {
      final actor = s.current;
      final d = strat.decide(s, actor)!;
      final card = s
          .player(actor)
          .hand
          .firstWhere((c) => c.id == d.actionCardId);
      final pos = d.targetPosition;

      if (card.type == ActionType.life || card.type == ActionType.death) {
        final tgt = s.humanAt(pos);
        if (tgt.protected) {
          for (var i = prots.length - 1; i >= 0; i--) {
            if (prots[i].pos == pos && !prots[i].absorbed) {
              prots[i].absorbed = true;
              break;
            }
          }
        }
        // その位置を過去に診断していた本人が実際に手を打った＝情報を活用。
        for (final dg in diags) {
          if (dg.owner == actor && dg.pos == pos) dg.actedUpon = true;
        }
      } else if (card.type == ActionType.protect) {
        protPlaced++;
        prots.add(_Prot(actor, pos));
      } else if (card.type == ActionType.diagnose) {
        diagPlaced++;
        diags.add(_Diag(actor, pos));
      }

      s = engine.applyAction(s, d);
      guard++;
    }

    final r = engine.score(s);
    if (r.isDraw) {
      draw++;
    } else if (r.winner == Faction.savior) {
      saviorW++;
    } else {
      execW++;
    }
    // 席順（A=先手）。
    final aFactionFinal = s.playerA.faction;
    final aWon = !r.isDraw && r.winner == aFactionFinal;
    if (!r.isDraw) {
      if (aWon) {
        aW++;
      } else {
        bW++;
      }
    }
    // 救済者が A か B か。
    if (aFactionFinal == Faction.savior) {
      saviorGamesAsA++;
      if (r.winner == Faction.savior) saviorWinsAsA++;
    } else {
      saviorGamesAsB++;
      if (r.winner == Faction.savior) saviorWinsAsB++;
    }

    marginSum += (r.saviorScore - r.executionerScore).abs();
    revealedSum += s.humans.where((h) => h.revealed).length;

    // 保の有効性：吸収した数と、最終的に守った側の望む状態で終わった数。
    for (final p in prots) {
      if (p.absorbed) protAbsorbed++;
      final h = s.humanAt(p.pos);
      final saviorSide = s.player(p.owner).faction == Faction.savior;
      if (_wantAlive(h.type, saviorSide) == h.isAlive) protFavorable++;
    }
    for (final dg in diags) {
      if (dg.actedUpon) diagActed++;
    }
  }

  print('=== Ver.1.0 バランス計測（$games 戦・両席CPU）===');
  print('');
  print('[勝率]');
  print('  救済者 : ${pct(saviorW, games)}  ($saviorW)');
  print('  執行者 : ${pct(execW, games)}  ($execW)');
  print('  引き分け: ${pct(draw, games)}  ($draw)');
  print('');
  print('[席順]（A=先手）決着のみ');
  print('  先手A : ${pct(aW, aW + bW)}');
  print('  後手B : ${pct(bW, aW + bW)}');
  print('');
  print('[役職×席順] 救済者の勝率');
  print('  救済者=先手(A): ${pct(saviorWinsAsA, saviorGamesAsA)}');
  print('  救済者=後手(B): ${pct(saviorWinsAsB, saviorGamesAsB)}');
  print('');
  print('[カード有効率]');
  print(
    '  保：吸収して仕事をした率  ${pct(protAbsorbed, protPlaced)}  '
    '($protAbsorbed/$protPlaced)',
  );
  print('  保：最終的に望む状態を守れた率 ${pct(protFavorable, protPlaced)}');
  print(
    '  診：本人が後で対象に手を打った率 ${pct(diagActed, diagPlaced)}  '
    '($diagActed/$diagPlaced)',
  );
  print('');
  print('[参考]');
  print('  平均得点差(|救-執|): ${(marginSum / games).toStringAsFixed(2)}');
  print('  終了時の平均公開枚数: ${(revealedSum / games).toStringAsFixed(2)} / 9');
}
