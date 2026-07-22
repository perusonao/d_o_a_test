import 'action_outcome.dart';
import 'enums.dart';
import 'game_log_entry.dart';
import 'player_state.dart';

/// ゲーム全体の状態。イミュータブルに扱い、エンジンが新しい状態を返す。
class GameState {
  const GameState({
    required this.player,
    required this.cpu,
    required this.phase,
    required this.logs,
    this.selectedLifeDeathCardId,
    this.selectedPersonId,
    this.message,
    this.lastOutcome,
    this.isBusy = false,
  });

  /// プレイヤーの状態。
  final PlayerState player;

  /// CPU の状態。
  final PlayerState cpu;

  /// 現在のフェーズ。
  final GamePhase phase;

  /// 試合中の全ログ（新しいものを末尾に追加）。
  final List<GameLogEntry> logs;

  /// 現在選択中の生死カード ID（プレイヤー操作用）。
  final String? selectedLifeDeathCardId;

  /// 現在選択中の対象人カード ID（プレイヤー操作用）。
  final String? selectedPersonId;

  /// 画面下部に表示するメッセージ（無効操作の理由など）。
  final String? message;

  /// 直近の効果判定結果（アニメーション用）。
  final ActionOutcome? lastOutcome;

  /// アニメーション等で入力を止めるフラグ。
  final bool isBusy;

  /// 両者とも使用可能カードが無くなったか。
  bool get isGameOver => !player.hasUsableCards && !cpu.hasUsableCards;

  GameState copyWith({
    PlayerState? player,
    PlayerState? cpu,
    GamePhase? phase,
    List<GameLogEntry>? logs,
    String? selectedLifeDeathCardId,
    String? selectedPersonId,
    String? message,
    ActionOutcome? lastOutcome,
    bool? isBusy,
    bool clearSelection = false,
    bool clearMessage = false,
    bool clearOutcome = false,
  }) {
    return GameState(
      player: player ?? this.player,
      cpu: cpu ?? this.cpu,
      phase: phase ?? this.phase,
      logs: logs ?? this.logs,
      selectedLifeDeathCardId: clearSelection
          ? null
          : (selectedLifeDeathCardId ?? this.selectedLifeDeathCardId),
      selectedPersonId: clearSelection
          ? null
          : (selectedPersonId ?? this.selectedPersonId),
      message: clearMessage ? null : (message ?? this.message),
      lastOutcome: clearOutcome ? null : (lastOutcome ?? this.lastOutcome),
      isBusy: isBusy ?? this.isBusy,
    );
  }

  /// 指定した所有者の状態を返す。
  PlayerState stateOf(TurnOwner owner) =>
      owner == TurnOwner.player ? player : cpu;
}
