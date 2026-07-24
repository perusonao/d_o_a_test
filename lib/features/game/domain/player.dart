import 'action_card.dart';
import 'enums.dart';

/// プレイヤー1人分の状態。
class Player {
  const Player({
    required this.id,
    required this.faction,
    required this.hand,
    this.isCpu = false,
  });

  final PlayerId id;
  final Faction faction;
  final List<ActionCard> hand;

  /// この席が CPU 操作かどうか。
  final bool isCpu;

  List<ActionCard> get usableCards =>
      hand.where((c) => !c.used).toList(growable: false);

  bool get hasUsableCards => hand.any((c) => !c.used);

  int countUsable(ActionType type) =>
      hand.where((c) => !c.used && c.type == type).length;

  Player copyWith({List<ActionCard>? hand}) {
    return Player(
      id: id,
      faction: faction,
      hand: hand ?? this.hand,
      isCpu: isCpu,
    );
  }
}
