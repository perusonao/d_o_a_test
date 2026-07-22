import 'action_outcome.dart';
import 'enums.dart';
import 'game_log_entry.dart';
import 'person_card.dart';
import 'player_state.dart';
import 'public_action.dart';

/// ゲーム全体の状態（Ver.0.3）。イミュータブルに扱う。
class GameState {
  const GameState({
    required this.persons,
    required this.player,
    required this.cpu,
    required this.phase,
    required this.logs,
    required this.history,
    this.selectedLifeDeathCardId,
    this.selectedPosition,
    this.message,
    this.lastOutcome,
    this.isBusy = false,
  });

  /// 中央共有の人カード9枚（position 順）。
  final List<PersonCard> persons;

  final PlayerSideState player;
  final PlayerSideState cpu;

  final GamePhase phase;

  /// 表示用ログ（新しいものを末尾に）。
  final List<GameLogEntry> logs;

  /// 公開行動履歴（CPU の推理・UI の履歴表示に使う）。
  final List<PublicAction> history;

  final String? selectedLifeDeathCardId;
  final int? selectedPosition;
  final String? message;
  final ActionOutcome? lastOutcome;
  final bool isBusy;

  bool get isGameOver => !player.hasUsableCards && !cpu.hasUsableCards;

  PlayerSideState stateOf(TurnOwner owner) =>
      owner == TurnOwner.player ? player : cpu;

  PersonCard personAt(int position) =>
      persons.firstWhere((p) => p.position == position);

  GameState copyWith({
    List<PersonCard>? persons,
    PlayerSideState? player,
    PlayerSideState? cpu,
    GamePhase? phase,
    List<GameLogEntry>? logs,
    List<PublicAction>? history,
    String? selectedLifeDeathCardId,
    int? selectedPosition,
    String? message,
    ActionOutcome? lastOutcome,
    bool? isBusy,
    bool clearSelection = false,
    bool clearMessage = false,
    bool clearOutcome = false,
  }) {
    return GameState(
      persons: persons ?? this.persons,
      player: player ?? this.player,
      cpu: cpu ?? this.cpu,
      phase: phase ?? this.phase,
      logs: logs ?? this.logs,
      history: history ?? this.history,
      selectedLifeDeathCardId: clearSelection
          ? null
          : (selectedLifeDeathCardId ?? this.selectedLifeDeathCardId),
      selectedPosition:
          clearSelection ? null : (selectedPosition ?? this.selectedPosition),
      message: clearMessage ? null : (message ?? this.message),
      lastOutcome: clearOutcome ? null : (lastOutcome ?? this.lastOutcome),
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
