import 'dart:math';

import '../domain/action_card.dart';
import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_constants.dart';
import '../domain/game_result.dart';
import '../domain/game_state.dart';
import '../domain/human_card.dart';
import '../domain/player.dart';

/// 表示用ラベル。
class GameLabels {
  static String actionType(ActionType t) {
    switch (t) {
      case ActionType.life:
        return '生';
      case ActionType.death:
        return '死';
      case ActionType.protect:
        return '保';
    }
  }

  static String humanType(HumanType t) {
    switch (t) {
      case HumanType.good:
        return '善人';
      case HumanType.neutral:
        return '中立';
      case HumanType.evil:
        return '悪人';
    }
  }

  static String faction(Faction f) =>
      f == Faction.savior ? '救済者' : '執行者';

  static String player(PlayerId id) =>
      id == PlayerId.a ? 'プレイヤーA' : 'プレイヤーB';
}

/// ゲームロジックを集約するエンジン（Widget にロジックを書かない）。
class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 対戦を初期化する。プレイヤーAの陣営を指定し、Bは反対陣営になる。
  /// [vsCpu] が true のとき、プレイヤーBを CPU にする。
  GameState setup(Faction playerAFaction, {bool vsCpu = false}) {
    // 9枚の人間カード（善人/中立/悪人 × 得点1/2/3）を生成しシャッフル配置。
    final cards = <HumanCard>[];
    var seq = 0;
    for (final type in HumanType.values) {
      for (final pt in GameConstants.pointValues) {
        cards.add(HumanCard(
          id: 'h${seq++}',
          position: 0, // 後で確定
          type: type,
          points: pt,
        ));
      }
    }
    cards.shuffle(_random);
    final humans = <HumanCard>[
      for (var i = 0; i < cards.length; i++)
        HumanCard(
          id: cards[i].id,
          position: i,
          type: cards[i].type,
          points: cards[i].points,
        ),
    ];

    final playerBFaction =
        playerAFaction == Faction.savior ? Faction.executioner : Faction.savior;

    return GameState(
      humans: humans,
      playerA: Player(
        id: PlayerId.a,
        faction: playerAFaction,
        hand: _buildHand(PlayerId.a),
      ),
      playerB: Player(
        id: PlayerId.b,
        faction: playerBFaction,
        hand: _buildHand(PlayerId.b),
        isCpu: vsCpu,
      ),
      current: PlayerId.a,
      phase: GamePhase.peekA,
    );
  }

  List<ActionCard> _buildHand(PlayerId owner) {
    final hand = <ActionCard>[];
    for (var i = 0; i < GameConstants.handComposition.length; i++) {
      hand.add(ActionCard(
        id: 'ac_${owner.name}_$i',
        type: GameConstants.handComposition[i],
        owner: owner,
      ));
    }
    return hand;
  }

  /// 確認フェーズを進める（peekA → peekB → playing）。
  /// CPU 対戦のときは B の確認フェーズを省略する。
  GameState confirmPeek(GameState state) {
    switch (state.phase) {
      case GamePhase.peekA:
        return state.copyWith(
          phase: state.playerB.isCpu ? GamePhase.playing : GamePhase.peekB,
        );
      case GamePhase.peekB:
        return state.copyWith(phase: GamePhase.playing);
      default:
        return state;
    }
  }

  /// 行動の妥当性を検証する。問題があれば理由、無ければ null。
  String? validate(GameState state, {String? actionCardId, int? position}) {
    if (actionCardId == null) return 'アクションカードを選んでください。';
    final card = state.currentPlayer.hand
        .where((c) => c.id == actionCardId && !c.used)
        .cast<ActionCard?>()
        .firstWhere((c) => c != null, orElse: () => null);
    if (card == null) return 'そのカードは使用できません。';
    if (position == null) return '対象の人間カードを選んでください。';
    if (position < 0 || position >= GameConstants.humanCardCount) {
      return '対象を選び直してください。';
    }
    return null;
  }

  /// 行動を適用し、手番を交代した新しい状態を返す。
  GameState applyAction(GameState state, GameAction action) {
    final actor = state.player(action.player);
    final card = actor.hand.firstWhere((c) => c.id == action.actionCardId);
    final index =
        state.humans.indexWhere((h) => h.position == action.targetPosition);
    final target = state.humans[index];

    HumanCard updated;
    var protectAbsorbed = false;

    switch (card.type) {
      case ActionType.protect:
        // 保護を付与。公開しない。
        updated = target.copyWith(protected: true);
        break;
      case ActionType.life:
      case ActionType.death:
        // 生/死は対象を公開する。
        if (target.protected) {
          // 保護中：保護のみ破壊、生死は変化なし。
          protectAbsorbed = true;
          updated = target.copyWith(protected: false, revealed: true);
        } else {
          final newState =
              card.type == ActionType.life ? CardState.alive : CardState.dead;
          updated = target.copyWith(state: newState, revealed: true);
        }
        break;
    }

    final newHumans = List<HumanCard>.from(state.humans);
    newHumans[index] = updated;

    final newHand = actor.hand
        .map((c) => c.id == card.id ? c.copyWith(used: true) : c)
        .toList();
    final newActor = actor.copyWith(hand: newHand);
    final newA = action.player == PlayerId.a ? newActor : state.playerA;
    final newB = action.player == PlayerId.b ? newActor : state.playerB;

    final next = action.player == PlayerId.a ? PlayerId.b : PlayerId.a;
    final bothEmpty = !newA.hasUsableCards && !newB.hasUsableCards;

    return state.copyWith(
      humans: newHumans,
      playerA: newA,
      playerB: newB,
      current: next,
      phase: bothEmpty ? GamePhase.finished : GamePhase.playing,
      lastActionPosition: action.targetPosition,
      lastActionType: card.type,
      lastProtectAbsorbed: protectAbsorbed,
      peeked: const <int>{}, // 手番交代でのぞき見はリセット
      clearSelection: true,
      clearMessage: true,
    );
  }

  /// 得点を集計する。各カードの得点は最終状態に応じてどちらか一方に入る。
  GameResult score(GameState state) {
    var savior = 0;
    var executioner = 0;
    for (final h in state.humans) {
      final toSavior = switch (h.type) {
        // 善人・中立は「生存」で救済者、「死亡」で執行者。
        HumanType.good || HumanType.neutral => h.isAlive,
        // 悪人は「死亡」で救済者、「生存」で執行者。
        HumanType.evil => h.isDead,
      };
      if (toSavior) {
        savior += h.points;
      } else {
        executioner += h.points;
      }
    }
    final Faction? winner = savior > executioner
        ? Faction.savior
        : executioner > savior
            ? Faction.executioner
            : null;
    return GameResult(
      saviorScore: savior,
      executionerScore: executioner,
      winner: winner,
      playerAFaction: state.playerA.faction,
      playerBFaction: state.playerB.faction,
    );
  }
}
