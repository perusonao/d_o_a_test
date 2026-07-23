import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../domain/game_action.dart';
import '../domain/game_result.dart';
import '../domain/game_state.dart';
import 'game_engine.dart';

/// ゲーム進行の状態管理（Ver.0.4・ローカル2人対戦）。
class GameController extends Notifier<GameState?> {
  late final GameEngine _engine;

  @override
  GameState? build() {
    _engine = GameEngine();
    return null;
  }

  /// プレイヤーAの陣営を指定して開始（Bは反対陣営）。
  void startGame(Faction playerAFaction) {
    state = _engine.setup(playerAFaction);
  }

  void restart() {
    final aFaction = state?.playerA.faction ?? Faction.savior;
    startGame(aFaction);
  }

  /// 確認フェーズを進める。
  void confirmPeek() {
    final s = state;
    if (s == null) return;
    state = _engine.confirmPeek(s);
  }

  void selectActionCard(String id) {
    final s = state;
    if (s == null || s.phase != GamePhase.playing) return;
    final next = s.selectedActionCardId == id ? null : id;
    state = _withSelection(s, cardId: next, position: s.selectedPosition);
  }

  void selectPosition(int position) {
    final s = state;
    if (s == null || s.phase != GamePhase.playing) return;
    final next = s.selectedPosition == position ? null : position;
    state = _withSelection(s, cardId: s.selectedActionCardId, position: next);
  }

  void confirm() {
    final s = state;
    if (s == null || s.phase != GamePhase.playing) return;
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
  }

  GameResult? result() {
    final s = state;
    if (s == null || s.phase != GamePhase.finished) return null;
    return _engine.score(s);
  }

  GameState _withSelection(GameState s,
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
      lastProtectAbsorbed: s.lastProtectAbsorbed,
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
      lastProtectAbsorbed: s.lastProtectAbsorbed,
    );
  }
}

final gameControllerProvider =
    NotifierProvider<GameController, GameState?>(GameController.new);
