// ignore_for_file: avoid_print
//
// 実験：手札「共有」版のバランス計測（製品コードは変更しない・tool内で完結）。
//
// ルール差分（この実験のみ）:
//   - 各プレイヤー固定手札ではなく、共有プール（既定 生6/死6/保4/診2＝18枚）から
//     交互に1枚ずつ選んで使用し、尽きたら終了。
//   - それ以外（盤面9枚・初期情報の段・生死保診の効果・得点）は Ver.1.0 と同じ。
//
// 実行: dart run tool/shared_hand_sim.dart [games]
import 'dart:math';

import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/human_card.dart';

/// 共有プールの構成（両陣営の合計と同じ）。
const Map<ActionType, int> sharedPool = {
  ActionType.life: 6,
  ActionType.death: 6,
  ActionType.protect: 4,
  ActionType.diagnose: 2,
};

List<HumanCard> buildBoard(Random rng) {
  final cards = <HumanCard>[];
  for (final type in HumanType.values) {
    for (final pt in const [1, 2, 3]) {
      cards.add(HumanCard(id: 'x', position: 0, type: type, points: pt));
    }
  }
  cards.shuffle(rng);
  return [
    for (var i = 0; i < 9; i++)
      HumanCard(
          id: 'h$i', position: i, type: cards[i].type, points: cards[i].points)
  ];
}

bool wantAlive(HumanType type, bool saviorSide) =>
    saviorSide ? type != HumanType.evil : type == HumanType.evil;

bool _knownRow(PlayerId who, int pos) =>
    pos ~/ 3 == (who == PlayerId.a ? 2 : 0);

double scoreMove(
    List<HumanCard> board, ActionType type, int pos, PlayerId owner, bool saviorSide) {
  final h = board[pos];
  final known = h.revealed || _knownRow(owner, pos) || h.diagnosedBy(owner);
  final points = h.points.toDouble();
  if (!known) {
    switch (type) {
      case ActionType.diagnose:
        return points * 0.35;
      case ActionType.life:
        return h.isAlive ? -0.2 : -0.6;
      case ActionType.death:
        return -0.7;
      case ActionType.protect:
        return -0.4;
    }
  }
  final wa = wantAlive(h.type, saviorSide);
  switch (type) {
    case ActionType.diagnose:
      return -0.5;
    case ActionType.life:
      if (wa && h.isDead) return points;
      if (!wa && h.isDead) return -points;
      return -0.1;
    case ActionType.death:
      if (!wa && h.isAlive) return points;
      if (wa && h.isAlive) return -points;
      return -0.1;
    case ActionType.protect:
      if (h.protected) return -1.0;
      final inDesired = wa == h.isAlive;
      return inDesired ? points * 0.5 : -points * 0.3;
  }
}

/// owner の最善手 (type,pos) を返す。使える手が無ければ null。
({ActionType type, int pos})? decide(List<HumanCard> board,
    Map<ActionType, int> pool, PlayerId owner, bool saviorSide, Random rng) {
  ({ActionType type, int pos})? best;
  var bestScore = double.negativeInfinity;
  for (final entry in pool.entries) {
    if (entry.value <= 0) continue;
    final type = entry.key;
    for (var pos = 0; pos < board.length; pos++) {
      final h = board[pos];
      if (GameEngine.isNoOpBlocked(type, h)) continue;
      if (type == ActionType.diagnose &&
          (h.revealed || _knownRow(owner, pos) || h.diagnosedBy(owner))) {
        continue;
      }
      final s = scoreMove(board, type, pos, owner, saviorSide) +
          rng.nextDouble() * 0.01;
      if (s > bestScore) {
        bestScore = s;
        best = (type: type, pos: pos);
      }
    }
  }
  return best;
}

void apply(List<HumanCard> board, ActionType type, int pos, PlayerId owner) {
  final h = board[pos];
  switch (type) {
    case ActionType.diagnose:
      board[pos] = h.copyWith(
          diagnosedByA: owner == PlayerId.a ? true : h.diagnosedByA,
          diagnosedByB: owner == PlayerId.b ? true : h.diagnosedByB);
      break;
    case ActionType.protect:
      board[pos] = h.copyWith(protected: true);
      break;
    case ActionType.life:
      if (h.protected) {
        board[pos] = h.copyWith(protected: false, revealed: true);
      } else {
        board[pos] = h.copyWith(state: CardState.alive, revealed: true);
      }
      break;
    case ActionType.death:
      if (h.protected) {
        board[pos] = h.copyWith(protected: false, revealed: true);
      } else {
        board[pos] = h.copyWith(state: CardState.dead, revealed: true);
      }
      break;
  }
}

/// 得点集計（Ver.1.0 と同じ）。救済者の得点を返す（合計は18）。
int saviorScore(List<HumanCard> board) {
  var s = 0;
  for (final h in board) {
    final toSavior = switch (h.type) {
      HumanType.good || HumanType.neutral => h.isAlive,
      HumanType.evil => h.isDead,
    };
    if (toSavior) s += h.points;
  }
  return s;
}

String pct(num n, num d) =>
    d == 0 ? '-' : '${(100 * n / d).toStringAsFixed(1)}%';

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 6000;
  final rng = Random(2024);
  var saviorW = 0, execW = 0, draw = 0, aW = 0, bW = 0;
  var execDeathUsed = 0, saviorDeathUsed = 0;

  for (var g = 0; g < games; g++) {
    // A の陣営を交互に。
    final aSavior = g.isEven;
    final board = buildBoard(rng);
    final pool = {...sharedPool};
    var current = PlayerId.a;
    var guard = 0;
    while (pool.values.any((v) => v > 0) && guard < 100) {
      final saviorSide =
          (current == PlayerId.a) == aSavior; // 現在手番が救済者か
      final move = decide(board, pool, current, saviorSide, rng);
      if (move == null) break;
      pool[move.type] = pool[move.type]! - 1;
      if (move.type == ActionType.death) {
        if (saviorSide) {
          saviorDeathUsed++;
        } else {
          execDeathUsed++;
        }
      }
      apply(board, move.type, move.pos, current);
      current = current == PlayerId.a ? PlayerId.b : PlayerId.a;
      guard++;
    }

    final sv = saviorScore(board);
    final ex = 18 - sv;
    if (sv > ex) {
      saviorW++;
    } else if (ex > sv) {
      execW++;
    } else {
      draw++;
    }
    // 席順（A=先手）。A が救済者なら sv が A のスコア。
    final aScore = aSavior ? sv : ex;
    final bScore = 18 - aScore;
    if (aScore > bScore) {
      aW++;
    } else if (bScore > aScore) {
      bW++;
    }
  }

  print('=== 共有手札 実験（$games 戦・両席CPU）===');
  print('共有プール: 生6/死6/保4/診2 = 18');
  print('');
  print('救済者 勝率: ${pct(saviorW, games)}  ($saviorW)');
  print('執行者 勝率: ${pct(execW, games)}  ($execW)');
  print('引き分け  : ${pct(draw, games)}  ($draw)');
  print('先手A 勝率(決着のみ): ${pct(aW, aW + bW)}');
  print('後手B 勝率(決着のみ): ${pct(bW, aW + bW)}');
  print('死カード使用: 救済者 $saviorDeathUsed / 執行者 $execDeathUsed');
}
