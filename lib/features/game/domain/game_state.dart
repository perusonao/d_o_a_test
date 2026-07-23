import 'enums.dart';
import 'human_card.dart';
import 'player.dart';

/// ゲーム全体の状態（Ver.0.4）。イミュータブルに扱う。
class GameState {
  const GameState({
    required this.humans,
    required this.playerA,
    required this.playerB,
    required this.current,
    required this.phase,
    this.selectedActionCardId,
    this.selectedPosition,
    this.message,
    this.lastActionPosition,
    this.lastActionType,
    this.lastProtectAbsorbed = false,
  });

  /// 中央の人間カード9枚（position 順）。
  final List<HumanCard> humans;

  final Player playerA;
  final Player playerB;

  /// 現在の手番。
  final PlayerId current;

  final GamePhase phase;

  final String? selectedActionCardId;
  final int? selectedPosition;
  final String? message;

  /// 直近に行動を受けた位置（アニメーション用）。
  final int? lastActionPosition;

  /// 直近に使われたアクション種別（アニメーション用）。
  final ActionType? lastActionType;

  /// 直近の行動が保護で吸収されたか（アニメーション用）。
  final bool lastProtectAbsorbed;

  Player player(PlayerId id) => id == PlayerId.a ? playerA : playerB;
  Player get currentPlayer => player(current);

  HumanCard humanAt(int position) =>
      humans.firstWhere((h) => h.position == position);

  bool get bothHandsEmpty =>
      !playerA.hasUsableCards && !playerB.hasUsableCards;

  GameState copyWith({
    List<HumanCard>? humans,
    Player? playerA,
    Player? playerB,
    PlayerId? current,
    GamePhase? phase,
    String? selectedActionCardId,
    int? selectedPosition,
    String? message,
    int? lastActionPosition,
    ActionType? lastActionType,
    bool? lastProtectAbsorbed,
    bool clearSelection = false,
    bool clearMessage = false,
  }) {
    return GameState(
      humans: humans ?? this.humans,
      playerA: playerA ?? this.playerA,
      playerB: playerB ?? this.playerB,
      current: current ?? this.current,
      phase: phase ?? this.phase,
      selectedActionCardId: clearSelection
          ? null
          : (selectedActionCardId ?? this.selectedActionCardId),
      selectedPosition:
          clearSelection ? null : (selectedPosition ?? this.selectedPosition),
      message: clearMessage ? null : (message ?? this.message),
      lastActionPosition: lastActionPosition ?? this.lastActionPosition,
      lastActionType: lastActionType ?? this.lastActionType,
      lastProtectAbsorbed: lastProtectAbsorbed ?? this.lastProtectAbsorbed,
    );
  }
}
