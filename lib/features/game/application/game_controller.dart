import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_result.dart';
import '../domain/game_state.dart';
import 'cpu_strategy.dart';
import 'game_engine.dart';

/// アニメーション演出のための待ち時間。
class GameTiming {
  static const Duration resolveFlash = Duration(milliseconds: 700);
  static const Duration betweenTurns = Duration(milliseconds: 400);
  static const Duration cpuThinking = Duration(milliseconds: 650);
}

/// ゲーム進行の状態管理（Ver.0.3）。
class GameController extends Notifier<GameState?> {
  late final GameEngine _engine;
  late final CpuStrategy _cpu;

  @override
  GameState? build() {
    _engine = GameEngine();
    _cpu = DefaultCpuStrategy();
    return null;
  }

  /// 役割を選んで新しい対戦を開始する。
  Future<void> startGame(Role playerRole) async {
    state = _engine.startGame(playerRole);
    // CPU が先手（弱い役）の場合はまず CPU に行動させる。
    await _runCpuTurnsIfNeeded();
  }

  Future<void> restartSameRole() async {
    final role = state?.player.role ?? Role.savior;
    await startGame(role);
  }

  void selectLifeDeathCard(String id) {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playerTurn) return;
    final next = s.selectedLifeDeathCardId == id ? null : id;
    state = _withSelection(s, cardId: next, position: s.selectedPosition);
  }

  void selectPosition(int position) {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playerTurn) return;
    final person = s.persons.where((p) => p.position == position);
    if (person.isEmpty) return;
    if (person.first.sealed) {
      state = _withMessage(s, 'そのカードは封印済みで変更できません。');
      return;
    }
    final next = s.selectedPosition == position ? null : position;
    state = _withSelection(s, cardId: s.selectedLifeDeathCardId, position: next);
  }

  Future<void> confirm() async {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playerTurn) return;

    final error = _engine.validatePlayerAction(
      s,
      cardId: s.selectedLifeDeathCardId,
      position: s.selectedPosition,
    );
    if (error != null) {
      state = _withMessage(s, error);
      return;
    }

    final action = GameAction(
      actor: TurnOwner.player,
      lifeDeathCardId: s.selectedLifeDeathCardId!,
      targetPosition: s.selectedPosition!,
    );
    await _resolveAndAdvance(action, TurnOwner.player);
  }

  Future<void> _resolveAndAdvance(GameAction action, TurnOwner actor) async {
    var s = _engine.performAction(state!, action);
    state = s.copyWith(isBusy: true);
    await Future.delayed(GameTiming.resolveFlash);

    s = _engine.advanceTurn(state!, actor);
    state = s.copyWith(isBusy: s.phase == GamePhase.cpuTurn);
    await Future.delayed(GameTiming.betweenTurns);

    await _runCpuTurnsIfNeeded();
  }

  Future<void> _runCpuTurnsIfNeeded() async {
    while (state != null && state!.phase == GamePhase.cpuTurn) {
      state = state!.copyWith(isBusy: true);
      await Future.delayed(GameTiming.cpuThinking);

      final decision = _cpu.decide(state!, TurnOwner.cpu);
      if (decision == null) {
        state = _engine.advanceTurn(state!, TurnOwner.cpu);
        continue;
      }
      var s = _engine.performAction(state!, decision.action);
      state = s.copyWith(isBusy: true);
      await Future.delayed(GameTiming.resolveFlash);

      s = _engine.advanceTurn(state!, TurnOwner.cpu);
      state = s.copyWith(isBusy: s.phase == GamePhase.cpuTurn);
      await Future.delayed(GameTiming.betweenTurns);
    }
    if (state != null && state!.phase == GamePhase.playerTurn) {
      state = state!.copyWith(isBusy: false);
    }
  }

  GameResult? result() {
    final s = state;
    if (s == null || s.phase != GamePhase.finished) return null;
    return _engine.rules.score(s.persons, s.player.role);
  }

  GameState _withSelection(GameState s,
      {required String? cardId, required int? position}) {
    return GameState(
      persons: s.persons,
      player: s.player,
      cpu: s.cpu,
      phase: s.phase,
      logs: s.logs,
      history: s.history,
      selectedLifeDeathCardId: cardId,
      selectedPosition: position,
      lastOutcome: s.lastOutcome,
    );
  }

  GameState _withMessage(GameState s, String message) {
    return GameState(
      persons: s.persons,
      player: s.player,
      cpu: s.cpu,
      phase: s.phase,
      logs: s.logs,
      history: s.history,
      selectedLifeDeathCardId: s.selectedLifeDeathCardId,
      selectedPosition: s.selectedPosition,
      message: message,
      lastOutcome: s.lastOutcome,
    );
  }
}

final gameControllerProvider =
    NotifierProvider<GameController, GameState?>(GameController.new);
