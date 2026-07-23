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
    this.peeked = const <int>{},
    this.isBusy = false,
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

  /// 現在の手番プレイヤーが「のぞき見」して表向きにしている位置（自分の既知カード）。
  final Set<int> peeked;

  /// CPU の思考・演出中など、入力を止めるフラグ。
  final bool isBusy;

  Player player(PlayerId id) => id == PlayerId.a ? playerA : playerB;
  Player get currentPlayer => player(current);

  /// そのプレイヤーが初期に確認できる列（A=左0 / B=右2）。
  static int knownColumnOf(PlayerId id) => id == PlayerId.a ? 0 : 2;

  /// 位置 [position] が [id] の既知カードか。
  bool isKnownBy(PlayerId id, int position) =>
      position % 3 == knownColumnOf(id);

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
    Set<int>? peeked,
    bool? isBusy,
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
      peeked: peeked ?? this.peeked,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
