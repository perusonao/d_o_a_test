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
import '../domain/public_action.dart';
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
      case LifeDeathEffect.seal:
        return 'シール';
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

  static String role(Role r) => r == Role.savior ? '救済者' : '執行者';

  static String owner(TurnOwner o) => o == TurnOwner.player ? 'あなた' : 'CPU';
}

/// ゲーム進行を統括するエンジン（Ver.0.3）。
class GameEngine {
  GameEngine({
    Random? random,
    GameRuleService? rules,
    GameSetupService? setup,
  })  : _rules = rules ?? const GameRuleService(),
        _setup = setup ?? GameSetupService(random: random);

  final GameRuleService _rules;
  final GameSetupService _setup;

  GameRuleService get rules => _rules;

  /// 対戦を初期化する。プレイヤーが役割を選び、CPU は反対役になる。
  GameState startGame(Role playerRole) {
    final persons = _setup.buildPersons();
    final cpuRole =
        playerRole == Role.savior ? Role.executioner : Role.savior;

    final player = PlayerSideState(
      owner: TurnOwner.player,
      role: playerRole,
      hand: _setup.buildLifeDeathHand(TurnOwner.player, playerRole),
    );
    final cpu = PlayerSideState(
      owner: TurnOwner.cpu,
      role: cpuRole,
      hand: _setup.buildLifeDeathHand(TurnOwner.cpu, cpuRole),
    );

    // 弱い役が先手（＝最終手番）。
    final firstOwner =
        playerRole == GameConstants.weakRole ? TurnOwner.player : TurnOwner.cpu;

    return GameState(
      persons: persons,
      player: player,
      cpu: cpu,
      phase: firstOwner == TurnOwner.player
          ? GamePhase.playerTurn
          : GamePhase.cpuTurn,
      logs: [
        GameLogEntry(
          message:
              'ゲーム開始。あなたは${GameLabels.role(playerRole)}、CPUは${GameLabels.role(cpuRole)}。',
          actor: null,
        ),
      ],
      history: const [],
    );
  }

  /// プレイヤーの選択を検証する。問題があれば理由文字列、無ければ null。
  String? validatePlayerAction(
    GameState state, {
    String? cardId,
    int? position,
  }) {
    if (cardId == null) return '生死カードを選択してください。';
    final card = state.player.hand
        .where((c) => c.id == cardId && !c.isUsed)
        .cast<LifeDeathCard?>()
        .firstWhere((c) => c != null, orElse: () => null);
    if (card == null) return 'そのカードは使用できません。';
    if (position == null) return '対象の人カードを選択してください。';
    final target = state.persons
        .where((p) => p.position == position)
        .cast<PersonCard?>()
        .firstWhere((p) => p != null, orElse: () => null);
    if (target == null) return '対象を選び直してください。';
    if (target.sealed) return 'そのカードは封印済みで変更できません。';
    return null;
  }

  /// 行動を適用し、公開情報・ログ・結果を反映した新しい状態を返す。
  /// フェーズは resolving に設定する。
  GameState performAction(GameState state, GameAction action) {
    final actorState = state.stateOf(action.actor);
    final card =
        actorState.hand.firstWhere((c) => c.id == action.lifeDeathCardId);
    final index =
        state.persons.indexWhere((p) => p.position == action.targetPosition);
    final target = state.persons[index];

    final res = _rules.applyEffect(target, card);

    final newPersons = List<PersonCard>.from(state.persons);
    newPersons[index] = res.updatedCard;

    final newHand = actorState.hand
        .map((c) => c.id == card.id ? c.copyWith(isUsed: true) : c)
        .toList();
    final newActor =
        actorState.copyWith(hand: newHand, usedCount: actorState.usedCount + 1);

    final newPlayer = action.actor == TurnOwner.player ? newActor : state.player;
    final newCpu = action.actor == TurnOwner.cpu ? newActor : state.cpu;

    final publicAction = PublicAction(
      actor: action.actor,
      position: action.targetPosition,
      effect: card.effect,
      number: card.number,
      success: res.success,
      changed: res.changed,
      targetSealed: res.wasSealed,
    );
    final newHistory = List<PublicAction>.from(state.history)..add(publicAction);

    final logs = List<GameLogEntry>.from(state.logs);
    final pos = action.targetPosition + 1; // 表示は1始まり
    logs.add(GameLogEntry(
      message:
          '${GameLabels.owner(action.actor)}が[$pos]に「${GameLabels.effect(card.effect)}${card.number}」',
      actor: action.actor,
    ));
    if (res.wasSealed) {
      logs.add(const GameLogEntry(message: '対象は封印済み。変化なし。', actor: null));
    } else if (!res.success) {
      logs.add(GameLogEntry(
          message: 'パワー不足で失敗（対象は ${card.number + 1} 以上）', actor: null));
    } else if (card.effect == LifeDeathEffect.seal) {
      logs.add(const GameLogEntry(message: '成功。対象を封印した。', actor: null));
    } else if (res.changed) {
      logs.add(GameLogEntry(
          message:
              '成功。対象を${card.effect == LifeDeathEffect.dead ? "死亡" : "生存"}にした。',
          actor: null));
    } else {
      logs.add(const GameLogEntry(message: '成功したが状態は変わらなかった。', actor: null));
    }

    final outcome = ActionOutcome(
      actor: action.actor,
      effect: card.effect,
      number: card.number,
      position: action.targetPosition,
      success: res.success,
      changed: res.changed,
      wasSealed: res.wasSealed,
    );

    return state.copyWith(
      persons: newPersons,
      player: newPlayer,
      cpu: newCpu,
      phase: GamePhase.resolving,
      logs: logs,
      history: newHistory,
      lastOutcome: outcome,
      clearSelection: true,
      clearMessage: true,
    );
  }

  /// 効果判定後にターンを進める。
  GameState advanceTurn(GameState state, TurnOwner lastActor) {
    if (_rules.isGameOver(state.player.hasUsableCards, state.cpu.hasUsableCards)) {
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
    // 相手は手札切れ。自分に残りがあれば継続。
    if (state.stateOf(lastActor).hasUsableCards) {
      final logs = List<GameLogEntry>.from(state.logs)
        ..add(GameLogEntry(
            message: '${GameLabels.owner(other)}は手札切れのためパス', actor: null));
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
      ..add(const GameLogEntry(message: '全手番終了。正体を一斉公開します。', actor: null));
    return state.copyWith(
      phase: GamePhase.finished,
      logs: logs,
      clearOutcome: true,
    );
  }
}
