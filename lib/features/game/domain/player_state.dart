import 'enums.dart';
import 'life_death_card.dart';

/// プレイヤー（またはCPU）1人分の状態（Ver.0.3）。
///
/// 場は中央共有のため、ここには役割と手札のみを持つ。
/// 「どのカードを知っているか」は PersonCard.knownBy 側で表現する。
class PlayerSideState {
  const PlayerSideState({
    required this.owner,
    required this.role,
    required this.hand,
    this.usedCount = 0,
  });

  /// この状態の持ち主。
  final TurnOwner owner;

  /// 役割（救済者 / 執行者）。
  final Role role;

  /// 生死カードの手札。
  final List<LifeDeathCard> hand;

  /// 使用した生死カード枚数。
  final int usedCount;

  /// まだ使用できる生死カード。
  List<LifeDeathCard> get usableCards =>
      hand.where((c) => !c.isUsed).toList(growable: false);

  bool get hasUsableCards => hand.any((c) => !c.isUsed);

  PlayerSideState copyWith({
    List<LifeDeathCard>? hand,
    int? usedCount,
  }) {
    return PlayerSideState(
      owner: owner,
      role: role,
      hand: hand ?? this.hand,
      usedCount: usedCount ?? this.usedCount,
    );
  }
}
