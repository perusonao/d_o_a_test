import 'enums.dart';

/// プレイヤーの手札「アクションカード」（生 / 死 / 保）。数字は持たない。
class ActionCard {
  const ActionCard({
    required this.id,
    required this.type,
    required this.owner,
    this.used = false,
  });

  final String id;
  final ActionType type;
  final PlayerId owner;
  final bool used;

  ActionCard copyWith({bool? used}) {
    return ActionCard(
      id: id,
      type: type,
      owner: owner,
      used: used ?? this.used,
    );
  }
}
