import 'enums.dart';
import 'life_death_card.dart';
import 'person_card.dart';

/// プレイヤー（またはCPU）1人分の状態。
class PlayerState {
  const PlayerState({
    required this.owner,
    required this.faction,
    required this.persons,
    required this.hand,
    this.discardedCount = 0,
    this.usedCount = 0,
  });

  /// この状態の持ち主。
  final TurnOwner owner;

  /// 陣営。
  final Faction faction;

  /// 場に並ぶ人カード（9枚）。
  final List<PersonCard> persons;

  /// 生死カードの手札。
  final List<LifeDeathCard> hand;

  /// 中立ペナルティで破棄した枚数。
  final int discardedCount;

  /// 使用した生死カード枚数。
  final int usedCount;

  /// まだ使用できる生死カード（未使用のもの）。
  List<LifeDeathCard> get usableCards =>
      hand.where((c) => !c.isUsed).toList(growable: false);

  /// 使用可能なカードが残っているか。
  bool get hasUsableCards => hand.any((c) => !c.isUsed);

  PlayerState copyWith({
    Faction? faction,
    List<PersonCard>? persons,
    List<LifeDeathCard>? hand,
    int? discardedCount,
    int? usedCount,
  }) {
    return PlayerState(
      owner: owner,
      faction: faction ?? this.faction,
      persons: persons ?? this.persons,
      hand: hand ?? this.hand,
      discardedCount: discardedCount ?? this.discardedCount,
      usedCount: usedCount ?? this.usedCount,
    );
  }
}
