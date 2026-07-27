import 'dart:math';

import '../domain/action_card.dart';
import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_state.dart';
import '../domain/human_card.dart';
import 'game_engine.dart';

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

    final saviorSide = me.faction == Faction.savior;

    GameAction? best;
    var bestScore = double.negativeInfinity;

    for (final card in usable) {
      for (final human in state.humans) {
        // 禁止手（表向きカードへの無変化・二重保護）は選ばない。
        if (GameEngine.isNoOpBlocked(card.type, human)) continue;
        // 診：既に正体が分かっているカードには使わない。
        if (card.type == ActionType.diagnose &&
            state.canSeeFace(owner, human.position)) {
          continue;
        }
        final known = state.canSeeFace(owner, human.position);
        final score = _score(card, human, known, saviorSide);
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
    if (best != null) return best;

    // 全ての手が禁止（表向き無変化等）の稀なケース：有効な手を1つ探す。
    for (final card in usable) {
      for (final human in state.humans) {
        if (!GameEngine.isNoOpBlocked(card.type, human)) {
          return GameAction(
            player: owner,
            actionCardId: card.id,
            targetPosition: human.position,
          );
        }
      }
    }
    return null;
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

  double _score(ActionCard card, HumanCard human, bool known, bool saviorSide) {
    // 得点は常に見えるので、未知でも points は使える（正体＝種類だけが不明）。
    final points = human.points.toDouble();

    if (!known) {
      // 正体不明：無駄・危険を避けつつ、高得点カードは診で確認する価値。
      switch (card.type) {
        case ActionType.diagnose:
          return points * 0.35; // 高得点の未知を優先して確認
        case ActionType.life:
          return human.isAlive ? -0.2 : -0.6;
        case ActionType.death:
          return -0.7; // 未知を殺すのは危険（自陣の可能性）
        case ActionType.protect:
          return -0.4;
      }
    }

    final wantAlive = _wantAlive(human.type, saviorSide);

    switch (card.type) {
      case ActionType.diagnose:
        return -0.5; // 既知への診は無駄
      case ActionType.life:
        if (wantAlive && human.isDead) return points; // 望む生存へ復活
        if (!wantAlive && human.isDead) return -points; // 復活は損
        return -0.1; // 生存中に生＝無変化
      case ActionType.death:
        if (!wantAlive && human.isAlive) return points; // 望む死亡へ
        if (wantAlive && human.isAlive) return -points; // 味方を殺すのは損
        return -0.1; // 死亡中に死＝無変化
      case ActionType.protect:
        if (human.protected) return -1.0;
        final inDesired = wantAlive == human.isAlive;
        return inDesired ? points * 0.5 : -points * 0.3;
    }
  }
}
