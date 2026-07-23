import 'dart:math';

import '../domain/action_card.dart';
import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_state.dart';
import '../domain/human_card.dart';

/// CPU の意思決定（Ver.0.4）。
///
/// 自分が初期に確認した列（既知カード）と、対戦中に公開されたカードの情報を使い、
/// 自陣営の得点が高くなるよう貪欲に手を選ぶ。将来的に性格を差し替えられるよう分離。
class CpuStrategy {
  CpuStrategy({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// CPU（[owner]）の行動を決める。使えるカードが無ければ null。
  GameAction? decide(GameState state, PlayerId owner) {
    final me = state.player(owner);
    final usable = me.usableCards;
    if (usable.isEmpty) return null;

    final myColumn = GameState.knownColumnOf(owner);
    final saviorSide = me.faction == Faction.savior;

    GameAction? best;
    var bestScore = double.negativeInfinity;

    for (final card in usable) {
      for (final human in state.humans) {
        final score = _score(card, human, myColumn, saviorSide);
        // 同点はランダムに揺らして単調な手を避ける。
        final jittered = score + _random.nextDouble() * 0.01;
        if (jittered > bestScore) {
          bestScore = jittered;
          best = GameAction(
            player: owner,
            actionCardId: card.id,
            targetPosition: human.position,
          );
        }
      }
    }
    return best;
  }

  /// この陣営がそのカードを「生存させたい」か。
  bool _wantAlive(HumanType type, bool saviorSide) {
    if (saviorSide) {
      // 救済者：善人・中立を生かし、悪人を殺す。
      return type != HumanType.evil;
    } else {
      // 執行者：悪人を生かし、善人・中立を殺す。
      return type == HumanType.evil;
    }
  }

  double _score(
      ActionCard card, HumanCard human, int myColumn, bool saviorSide) {
    final known = human.column == myColumn || human.revealed;
    final points = human.points.toDouble();

    if (!known) {
      // 未知カード：正体・得点とも不明。無駄・危険を避ける。
      switch (card.type) {
        case ActionType.life:
          // 生存中のカードに生＝無変化（安全な消化先）。死んでいれば復活は不明。
          return human.isAlive ? -0.2 : -0.6;
        case ActionType.death:
          return -0.7; // 未知を殺すのは危険（自陣の可能性）。
        case ActionType.protect:
          return -0.4;
      }
    }

    final wantAlive = _wantAlive(human.type, saviorSide);

    switch (card.type) {
      case ActionType.life:
        if (wantAlive && human.isDead) return points; // 望む生存へ復活
        if (!wantAlive && human.isDead) return -points; // 復活は損
        return -0.1; // 生存中に生＝無変化
      case ActionType.death:
        if (!wantAlive && human.isAlive) return points; // 望む死亡へ
        if (wantAlive && human.isAlive) return -points; // 味方を殺すのは損
        return -0.1; // 死亡中に死＝無変化
      case ActionType.protect:
        if (human.protected) return -1.0; // 二重保護は無駄
        final inDesired = wantAlive == human.isAlive;
        // 望ましい状態のカードを封じる（相手の反転を防ぐ）。得点が高いほど有効。
        return inDesired ? points * 0.5 : -points * 0.3;
    }
  }
}
