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
  static const Duration betweenTurns = Duration(milliseconds: 450);
  static const Duration cpuThinking = Duration(milliseconds: 650);
}

/// ゲーム進行の状態管理を行う Riverpod コントローラ。
///
/// UI からの入力を受け取り、[GameEngine] と [CpuStrategy] を用いて状態を更新する。
/// アニメーション中は入力を無効化する（isBusy）。
class GameController extends Notifier<GameState?> {
  late final GameEngine _engine;
  late final CpuStrategy _cpu;

  @override
  GameState? build() {
    _engine = GameEngine();
    _cpu = DefaultCpuStrategy();
    return null;
  }

  /// 陣営を選んで新しい対戦を開始する。
  void startGame(Faction playerFaction) {
    state = _engine.startGame(playerFaction);
  }

  /// もう一度同じ陣営で遊ぶ。
  void restartSameFaction() {
    final faction = state?.player.faction ?? Faction.good;
    state = _engine.startGame(faction);
  }

  /// 生死カードの選択をトグルする。
  void selectLifeDeathCard(String id) {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playerTurn) return;
    if (s.selectedLifeDeathCardId == id) {
      // 同じカードを再タップ -> 選択解除。
      state = _withSelection(s, cardId: null, personId: s.selectedPersonId);
    } else {
      state = _withSelection(s, cardId: id, personId: s.selectedPersonId);
    }
  }

  /// 対象人カードの選択をトグルする（CPU側のみ選択可能）。
  void selectPerson(String id) {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playerTurn) return;
    final isCpuCard = s.cpu.persons.any((p) => p.id == id);
    if (!isCpuCard) {
      state = _withMessage(s, '対象はCPU側のカードから選んでください。');
      return;
    }
    if (s.selectedPersonId == id) {
      state = _withSelection(s, cardId: s.selectedLifeDeathCardId, personId: null);
    } else {
      state = _withSelection(s, cardId: s.selectedLifeDeathCardId, personId: id);
    }
  }

  /// 決定ボタン。選択内容を検証し、行動を実行する。
  Future<void> confirm() async {
    final s = state;
    if (s == null || s.isBusy || s.phase != GamePhase.playerTurn) return;

    final error = _engine.validatePlayerAction(
      s,
      cardId: s.selectedLifeDeathCardId,
      personId: s.selectedPersonId,
    );
    if (error != null) {
      state = _withMessage(s, error);
      return;
    }

    final action = GameAction(
      actor: TurnOwner.player,
      lifeDeathCardId: s.selectedLifeDeathCardId!,
      targetPersonId: s.selectedPersonId!,
      targetOwner: TurnOwner.cpu,
    );

    await _resolveAndAdvance(action, TurnOwner.player);
  }

  /// 行動を適用し、演出を挟んでターンを進める。必要なら CPU ターンを回す。
  Future<void> _resolveAndAdvance(GameAction action, TurnOwner actor) async {
    var s = _engine.performAction(state!, action);
    state = s.copyWith(isBusy: true);
    await Future.delayed(GameTiming.resolveFlash);

    s = _engine.advanceTurn(state!, actor);
    state = s.copyWith(isBusy: s.phase == GamePhase.cpuTurn);
    await Future.delayed(GameTiming.betweenTurns);

    await _runCpuTurnsIfNeeded();
  }

  /// CPU のターンが続く限り自動で行動させる。
  Future<void> _runCpuTurnsIfNeeded() async {
    while (state != null && state!.phase == GamePhase.cpuTurn) {
      state = state!.copyWith(isBusy: true);
      await Future.delayed(GameTiming.cpuThinking);

      final decision = _cpu.decide(state!);
      if (decision == null) {
        // 有効な行動が無い（手札切れ）。ターンを進める。
        state = _engine.advanceTurn(state!, TurnOwner.cpu);
        continue;
      }

      var s = _engine.performAction(state!, decision.action);
      state = s.copyWith(isBusy: true);
      await Future.delayed(GameTiming.resolveFlash);

      s = _engine.advanceTurn(state!, TurnOwner.cpu);
      final busy = s.phase == GamePhase.cpuTurn;
      state = s.copyWith(isBusy: busy);
      await Future.delayed(GameTiming.betweenTurns);
    }
    // プレイヤーのターンに戻ったら入力を解放。
    if (state != null && state!.phase == GamePhase.playerTurn) {
      state = state!.copyWith(isBusy: false);
    }
  }

  /// ゲーム終了時の集計結果を返す。
  GameResult? result() {
    final s = state;
    if (s == null || s.phase != GamePhase.finished) return null;
    return _engine.rules.judgeResult(s.player, s.cpu);
  }

  // --- 内部ヘルパ ---

  GameState _withSelection(GameState s,
      {required String? cardId, required String? personId}) {
    return GameState(
      player: s.player,
      cpu: s.cpu,
      phase: s.phase,
      logs: s.logs,
      selectedLifeDeathCardId: cardId,
      selectedPersonId: personId,
      lastOutcome: s.lastOutcome,
    );
  }

  GameState _withMessage(GameState s, String message) {
    return GameState(
      player: s.player,
      cpu: s.cpu,
      phase: s.phase,
      logs: s.logs,
      selectedLifeDeathCardId: s.selectedLifeDeathCardId,
      selectedPersonId: s.selectedPersonId,
      message: message,
      lastOutcome: s.lastOutcome,
    );
  }
}

/// ゲーム状態プロバイダ。
final gameControllerProvider =
    NotifierProvider<GameController, GameState?>(GameController.new);
