// ignore_for_file: avoid_print
//
// 実験：中立を得点対象から外した版のバランス計測（製品コードは変更しない）。
//
// ルール差分（この実験のみ）:
//   - 得点は「善人＝生で救済者/死で執行者」「悪人＝死で救済者/生で執行者」のみ。
//     中立は得点にならない（＝読み合い・ブラフ用の罠）。合計得点は12。
//   - CPU も中立を無価値として扱う。
//   - 手札は Ver.1.0 と同じ陣営別固定（救済者=生4死2保2診1 / 執行者=生2死4保2診1）。
//
// 実行: dart run tool/neutral_out_sim.dart [games]
import 'dart:math';

import 'package:dead_or_alive/features/game/application/game_engine.dart';
import 'package:dead_or_alive/features/game/domain/enums.dart';
import 'package:dead_or_alive/features/game/domain/human_card.dart';

const Map<ActionType, int> saviorHand = {
  ActionType.life: 4,
  ActionType.death: 2,
  ActionType.protect: 2,
  ActionType.diagnose: 1,
};
const Map<ActionType, int> execHand = {
  ActionType.life: 2,
  ActionType.death: 4,
  ActionType.protect: 2,
  ActionType.diagnose: 1,
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
        id: 'h$i',
        position: i,
        type: cards[i].type,
        points: cards[i].points,
      ),
  ];
}

bool _knownRow(PlayerId who, int pos) =>
    pos ~/ 3 == (who == PlayerId.a ? 2 : 0);

/// 善人=救済者は生存希望・執行者は死亡希望。悪人=その逆。中立は対象外。
bool wantAliveGoodEvil(HumanType type, bool saviorSide) {
  if (type == HumanType.good) return saviorSide;
  return !saviorSide; // evil
}

double scoreMove(
  List<HumanCard> board,
  ActionType type,
  int pos,
  PlayerId owner,
  bool saviorSide,
) {
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
  // 既知：中立は得点にならないので無駄。
  if (h.type == HumanType.neutral) return -0.3;

  final wa = wantAliveGoodEvil(h.type, saviorSide);
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

({ActionType type, int pos})? decide(
  List<HumanCard> board,
  Map<ActionType, int> hand,
  PlayerId owner,
  bool saviorSide,
  Random rng,
) {
  ({ActionType type, int pos})? best;
  var bestScore = double.negativeInfinity;
  for (final e in hand.entries) {
    if (e.value <= 0) continue;
    for (var pos = 0; pos < board.length; pos++) {
      final h = board[pos];
      if (GameEngine.isNoOpBlocked(e.key, h)) continue;
      if (e.key == ActionType.diagnose &&
          (h.revealed || _knownRow(owner, pos) || h.diagnosedBy(owner))) {
        continue;
      }
      final s =
          scoreMove(board, e.key, pos, owner, saviorSide) +
          rng.nextDouble() * 0.01;
      if (s > bestScore) {
        bestScore = s;
        best = (type: e.key, pos: pos);
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
        diagnosedByB: owner == PlayerId.b ? true : h.diagnosedByB,
      );
      break;
    case ActionType.protect:
      board[pos] = h.copyWith(protected: true);
      break;
    case ActionType.life:
      board[pos] = h.protected
          ? h.copyWith(protected: false, revealed: true)
          : h.copyWith(state: CardState.alive, revealed: true);
      break;
    case ActionType.death:
      board[pos] = h.protected
          ? h.copyWith(protected: false, revealed: true)
          : h.copyWith(state: CardState.dead, revealed: true);
      break;
  }
}

/// 中立を除いた救済者得点（善人生存＋悪人死亡）。合計12。
int saviorScore(List<HumanCard> board) {
  var s = 0;
  for (final h in board) {
    if (h.type == HumanType.good && h.isAlive) s += h.points;
    if (h.type == HumanType.evil && h.isDead) s += h.points;
  }
  return s;
}

String pct(num n, num d) =>
    d == 0 ? '-' : '${(100 * n / d).toStringAsFixed(1)}%';

void main(List<String> args) {
  final games = args.isNotEmpty ? int.parse(args[0]) : 6000;
  final rng = Random(2024);
  var saviorW = 0, execW = 0, draw = 0, aW = 0, bW = 0;

  for (var g = 0; g < games; g++) {
    final aSavior = g.isEven;
    final board = buildBoard(rng);
    final handA = {...(aSavior ? saviorHand : execHand)};
    final handB = {...(aSavior ? execHand : saviorHand)};
    var current = PlayerId.a;
    var guard = 0;
    while ((handA.values.any((v) => v > 0) || handB.values.any((v) => v > 0)) &&
        guard < 100) {
      final hand = current == PlayerId.a ? handA : handB;
      if (!hand.values.any((v) => v > 0)) {
        current = current == PlayerId.a ? PlayerId.b : PlayerId.a;
        continue;
      }
      final saviorSide = (current == PlayerId.a) == aSavior;
      final move = decide(board, hand, current, saviorSide, rng);
      if (move == null) break;
      hand[move.type] = hand[move.type]! - 1;
      apply(board, move.type, move.pos, current);
      current = current == PlayerId.a ? PlayerId.b : PlayerId.a;
      guard++;
    }

    final sv = saviorScore(board);
    final ex = 12 - sv;
    if (sv > ex) {
      saviorW++;
    } else if (ex > sv) {
      execW++;
    } else {
      draw++;
    }
    final aScore = aSavior ? sv : ex;
    if (aScore > 12 - aScore) {
      aW++;
    } else if (12 - aScore > aScore) {
      bW++;
    }
  }

  print('=== 中立を得点外 実験（$games 戦・両席CPU）===');
  print('得点対象: 善人3枚＋悪人3枚（合計12）。中立3枚は罠（得点なし）。');
  print('');
  print('救済者 勝率: ${pct(saviorW, games)}  ($saviorW)');
  print('執行者 勝率: ${pct(execW, games)}  ($execW)');
  print('引き分け  : ${pct(draw, games)}  ($draw)');
  print('先手A 勝率(決着のみ): ${pct(aW, aW + bW)}');
  print('後手B 勝率(決着のみ): ${pct(bW, aW + bW)}');
}
