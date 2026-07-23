import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_result.dart';
import '../domain/game_state.dart';
import 'cpu_strategy.dart';
import 'game_engine.dart';

class GameTiming {
  static const Duration cpuThink = Duration(milliseconds: 600);
  static const Duration afterAction = Duration(milliseconds: 500);
}

/// ゲーム進行の状態管理（Ver.0.4・2人対戦 / CPU対戦）。
class GameController extends Notifier<GameState?> {
  late final GameEngine _engine;
  late final CpuStrategy _cpu;

  @override
  GameState? build() {
    _engine = GameEngine();
    _cpu = CpuStrategy();
    return null;
  }

  /// プレイヤーAの陣営を指定して開始。[vsCpu] で対CPU戦。
  void startGame(Faction playerAFaction, {bool vsCpu = false}) {
    state = _engine.setup(playerAFaction, vsCpu: vsCpu);
  }

  void restart() {
    final s = state;
    startGame(s?.playerA.faction ?? Faction.savior,
        vsCpu: s?.playerB.isCpu ?? false);
  }

  Future<void> confirmPeek() async {
    final s = state;
    if (s == null) return;
    state = _engine.confirmPeek(s);
    // CPU 対戦で確認後すぐ CPU の番になる可能性は無い（A先手）が、念のため。
    await _runCpuIfNeeded();
  }

  void selectActionCard(String id) {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playing) return;
    if (s.currentPlayer.isCpu) return;
    final next = s.selectedActionCardId == id ? null : id;
    state = _rebuild(s, cardId: next, position: s.selectedPosition);
  }

  /// 人間カードのタップ。
  /// - アクション未選択かつ「自分の既知カード（未公開）」なら、のぞき見をトグル。
  /// - それ以外は対象選択をトグル。
  void selectPosition(int position) {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playing) return;
    if (s.currentPlayer.isCpu) return;

    final peekable = s.isKnownBy(s.current, position) &&
        !s.humanAt(position).revealed;
    if (s.selectedActionCardId == null && peekable) {
      final set = {...s.peeked};
      if (set.contains(position)) {
        set.remove(position);
      } else {
        set.add(position);
      }
      state = s.copyWith(peeked: set, clearMessage: true);
      return;
    }

    final next = s.selectedPosition == position ? null : position;
    state = _rebuild(s, cardId: s.selectedActionCardId, position: next);
  }

  Future<void> confirm() async {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playing) return;
    if (s.currentPlayer.isCpu) return;

    final error = _engine.validate(
      s,
      actionCardId: s.selectedActionCardId,
      position: s.selectedPosition,
    );
    if (error != null) {
      state = _withMessage(s, error);
      return;
    }
    state = _engine.applyAction(
      s,
      GameAction(
        player: s.current,
        actionCardId: s.selectedActionCardId!,
        targetPosition: s.selectedPosition!,
      ),
    );
    await _runCpuIfNeeded();
  }

  /// CPU の手番が続く限り自動で行動させる。
  Future<void> _runCpuIfNeeded() async {
    while (state != null &&
        state!.phase == GamePhase.playing &&
        state!.currentPlayer.isCpu) {
      state = state!.copyWith(isBusy: true);
      await Future.delayed(GameTiming.cpuThink);

      final action = _cpu.decide(state!, state!.current);
      if (action == null) break;
      state = _engine.applyAction(state!, action);
      await Future.delayed(GameTiming.afterAction);
    }
    if (state != null) {
      state = state!.copyWith(isBusy: false);
    }
  }

  GameResult? result() {
    final s = state;
    if (s == null || s.phase != GamePhase.finished) return null;
    return _engine.score(s);
  }

  GameState _rebuild(GameState s,
      {required String? cardId, required int? position}) {
    return GameState(
      humans: s.humans,
      playerA: s.playerA,
      playerB: s.playerB,
      current: s.current,
      phase: s.phase,
      selectedActionCardId: cardId,
      selectedPosition: position,
      lastActionPosition: s.lastActionPosition,
      lastActionType: s.lastActionType,
      lastProtectAbsorbed: s.lastProtectAbsorbed,
      peeked: s.peeked,
      isBusy: s.isBusy,
    );
  }

  GameState _withMessage(GameState s, String message) {
    return GameState(
      humans: s.humans,
      playerA: s.playerA,
      playerB: s.playerB,
      current: s.current,
      phase: s.phase,
      selectedActionCardId: s.selectedActionCardId,
      selectedPosition: s.selectedPosition,
      message: message,
      lastActionPosition: s.lastActionPosition,
      lastActionType: s.lastActionType,
      lastProtectAbsorbed: s.lastProtectAbsorbed,
      peeked: s.peeked,
      isBusy: s.isBusy,
    );
  }
}

final gameControllerProvider =
    NotifierProvider<GameController, GameState?>(GameController.new);
