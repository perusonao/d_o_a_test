import 'dart:math';

import '../domain/action_outcome.dart';
import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_constants.dart';
import '../domain/game_log_entry.dart';
import '../domain/game_state.dart';
import '../domain/life_death_card.dart';
import '../domain/person_card.dart';
import '../domain/player_state.dart';
import 'game_rule_service.dart';
import 'game_setup_service.dart';

/// 表示用のラベル変換ヘルパ。
class GameLabels {
  static String effect(LifeDeathEffect e) {
    switch (e) {
      case LifeDeathEffect.dead:
        return 'デッド';
      case LifeDeathEffect.alive:
        return 'アライブ';
      case LifeDeathEffect.keep:
        return 'キープ';
    }
  }

  static String personType(PersonType t) {
    switch (t) {
      case PersonType.good:
        return '善人';
      case PersonType.evil:
        return '悪人';
      case PersonType.neutral:
        return '中立';
    }
  }

  static String faction(Faction f) =>
      f == Faction.good ? '善人陣営' : '悪人陣営';

  static String owner(TurnOwner o) => o == TurnOwner.player ? 'プレイヤー' : 'CPU';
}

/// ゲーム進行を統括するエンジン。
///
/// セットアップ・行動適用・ターン進行・終了処理を担当し、
/// ルールの純粋計算は [GameRuleService] に委譲する。
class GameEngine {
  GameEngine({
    Random? random,
    GameRuleService? rules,
    GameSetupService? setup,
  })  : _random = random ?? Random(),
        _rules = rules ?? const GameRuleService(),
        _setup = setup ?? GameSetupService(random: random);

  final Random _random;
  final GameRuleService _rules;
  final GameSetupService _setup;

  GameRuleService get rules => _rules;

  /// 対戦を初期化する。プレイヤーが陣営を選択し、CPU は反対陣営になる。
  GameState startGame(Faction playerFaction) {
    final persons = _setup.dealPersonCards();
    final cpuFaction =
        playerFaction == Faction.good ? Faction.evil : Faction.good;

    final player = PlayerState(
      owner: TurnOwner.player,
      faction: playerFaction,
      persons: persons.player,
      hand: _setup.buildLifeDeathHand(TurnOwner.player),
    );
    final cpu = PlayerState(
      owner: TurnOwner.cpu,
      faction: cpuFaction,
      persons: persons.cpu,
      hand: _setup.buildLifeDeathHand(TurnOwner.cpu),
    );

    return GameState(
      player: player,
      cpu: cpu,
      phase: GamePhase.playerTurn,
      logs: const [
        GameLogEntry(message: 'ゲーム開始。', actor: null),
      ],
    );
  }

  /// プレイヤーの選択を検証する。問題があれば理由文字列、無ければ null を返す。
  String? validatePlayerAction(
    GameState state, {
    String? cardId,
    String? personId,
  }) {
    if (cardId == null) {
      return '生死カードを選択してください。';
    }
    final card = state.player.hand
        .where((c) => c.id == cardId && !c.isUsed)
        .cast<LifeDeathCard?>()
        .firstWhere((c) => c != null, orElse: () => null);
    if (card == null) {
      return 'そのカードは使用できません。';
    }
    if (personId == null) {
      return '対象のCPUカードを選択してください。';
    }
    final target = state.cpu.persons
        .where((p) => p.id == personId)
        .cast<PersonCard?>()
        .firstWhere((p) => p != null, orElse: () => null);
    if (target == null) {
      return '対象はCPU側のカードから選んでください。';
    }
    return null;
  }

  /// 行動を適用し、効果判定・情報公開・中立ペナルティを反映した新しい状態を返す。
  /// フェーズは resolving に設定する（アニメーション後に [advanceTurn] を呼ぶ）。
  GameState performAction(GameState state, GameAction action) {
    final actorState = state.stateOf(action.actor);
    final targetState = state.stateOf(action.targetOwner);

    final card = actorState.hand.firstWhere(
      (c) => c.id == action.lifeDeathCardId,
    );
    final targetIndex =
        targetState.persons.indexWhere((p) => p.id == action.targetPersonId);
    final target = targetState.persons[targetIndex];

    final resolution = _rules.applyEffect(target, card);

    // 対象人カードを更新。
    final newTargetPersons = List<PersonCard>.from(targetState.persons);
    newTargetPersons[targetIndex] = resolution.updatedCard;

    // 中立ペナルティ判定。
    final penalty = _rules.isNeutralPenalty(
      actorFaction: actorState.faction,
      target: target,
      becameDead: resolution.becameDead,
      becameAlive: resolution.becameAlive,
    );

    // 使用したカードを used に。
    var newHand = actorState.hand
        .map((c) => c.id == card.id ? c.copyWith(isUsed: true) : c)
        .toList();
    var discardedNow = 0;
    if (penalty) {
      final result = _discardRandom(newHand, GameConstants.neutralPenaltyDiscardMax);
      newHand = result.hand;
      discardedNow = result.discarded;
    }

    // actor / target が同一人物（自分の場を対象）でも整合するよう組み立てる。
    final logs = List<GameLogEntry>.from(state.logs);
    logs.add(GameLogEntry(
      message:
          '${GameLabels.owner(action.actor)}が「${GameLabels.effect(card.effect)}${card.number}」を使用',
      actor: action.actor,
    ));
    if (resolution.success) {
      if (resolution.guardBlocked) {
        logs.add(const GameLogEntry(message: 'キープの防御で無効化された', actor: null));
      } else {
        logs.add(const GameLogEntry(message: 'パワー判定成功', actor: null));
      }
      logs.add(GameLogEntry(
        message:
            '対象は「${GameLabels.personType(target.type)}${target.number}」だった',
        actor: null,
      ));
    } else {
      logs.add(GameLogEntry(
        message: 'パワー判定失敗（対象の数字は ${target.number}）',
        actor: null,
      ));
    }
    if (penalty) {
      logs.add(GameLogEntry(
        message:
            '中立ペナルティ発生！${GameLabels.owner(action.actor)}が生死カードを$discardedNow枚破棄',
        actor: null,
      ));
    }

    final outcome = ActionOutcome(
      actor: action.actor,
      effect: card.effect,
      success: resolution.success,
      targetPersonId: action.targetPersonId,
      targetOwner: action.targetOwner,
      guardBlocked: resolution.guardBlocked,
      neutralPenalty: penalty,
      discardedByPenalty: discardedNow,
      lifeDeathCardId: card.id,
      lifeDeathNumber: card.number,
    );

    // actor と target それぞれの状態を「差分」として管理し、最後に player/cpu へ反映する。
    // 同一人物が actor かつ target になるケース（自分の場を対象）にも対応する。
    var newPlayer = state.player;
    var newCpu = state.cpu;

    PlayerState applyActor(PlayerState base) => base.copyWith(
          hand: newHand,
          usedCount: base.usedCount + 1,
          discardedCount: base.discardedCount + discardedNow,
        );

    // まず actor の手札・カウンタを反映。
    if (action.actor == TurnOwner.player) {
      newPlayer = applyActor(newPlayer);
    } else {
      newCpu = applyActor(newCpu);
    }
    // 次に target の人カードを反映（actor と同一なら上の結果に上書き）。
    if (action.targetOwner == TurnOwner.player) {
      newPlayer = newPlayer.copyWith(persons: newTargetPersons);
    } else {
      newCpu = newCpu.copyWith(persons: newTargetPersons);
    }

    return state.copyWith(
      player: newPlayer,
      cpu: newCpu,
      phase: GamePhase.resolving,
      logs: logs,
      lastOutcome: outcome,
      clearSelection: true,
      clearMessage: true,
    );
  }

  /// 効果判定後にターンを進める。
  ///
  /// 終了していれば全公開して finished に、そうでなければ次の担当へ。
  GameState advanceTurn(GameState state, TurnOwner lastActor) {
    if (_rules.isGameOver(state.player, state.cpu)) {
      return _finalize(state);
    }
    final other =
        lastActor == TurnOwner.player ? TurnOwner.cpu : TurnOwner.player;
    if (state.stateOf(other).hasUsableCards) {
      return state.copyWith(
        phase: other == TurnOwner.player
            ? GamePhase.playerTurn
            : GamePhase.cpuTurn,
        clearOutcome: true,
      );
    }
    // 相手はパス。自分にまだカードがあれば継続。
    if (state.stateOf(lastActor).hasUsableCards) {
      final logs = List<GameLogEntry>.from(state.logs)
        ..add(GameLogEntry(
          message: '${GameLabels.owner(other)}は手札切れのためパス',
          actor: null,
        ));
      return state.copyWith(
        phase: lastActor == TurnOwner.player
            ? GamePhase.playerTurn
            : GamePhase.cpuTurn,
        logs: logs,
        clearOutcome: true,
      );
    }
    return _finalize(state);
  }

  GameState _finalize(GameState state) {
    final logs = List<GameLogEntry>.from(state.logs)
      ..add(const GameLogEntry(message: '両者手札切れ。全カードを公開します。', actor: null));
    return state.copyWith(
      player: state.player
          .copyWith(persons: _rules.revealAll(state.player.persons)),
      cpu: state.cpu.copyWith(persons: _rules.revealAll(state.cpu.persons)),
      phase: GamePhase.finished,
      logs: logs,
      clearOutcome: true,
    );
  }

  ({List<LifeDeathCard> hand, int discarded}) _discardRandom(
    List<LifeDeathCard> hand,
    int max,
  ) {
    final unusedIndexes = <int>[];
    for (var i = 0; i < hand.length; i++) {
      if (!hand[i].isUsed) unusedIndexes.add(i);
    }
    unusedIndexes.shuffle(_random);
    final discardCount = unusedIndexes.length < max ? unusedIndexes.length : max;
    final toDiscard = unusedIndexes.take(discardCount).toSet();
    final newHand = <LifeDeathCard>[];
    for (var i = 0; i < hand.length; i++) {
      newHand.add(toDiscard.contains(i) ? hand[i].copyWith(isUsed: true) : hand[i]);
    }
    return (hand: newHand, discarded: discardCount);
  }
}
