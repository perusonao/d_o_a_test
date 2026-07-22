import 'enums.dart';

/// プレイヤーが手札として持つ「生死カード」（Ver.0.3）。
///
/// デッド / アライブ / シール の効果と数字を持つ。
class LifeDeathCard {
  const LifeDeathCard({
    required this.id,
    required this.effect,
    required this.number,
    required this.owner,
    this.isUsed = false,
  });

  /// 一意な ID。
  final String id;

  /// 効果（dead / alive / seal）。
  final LifeDeathEffect effect;

  /// 数字（1〜9）。
  final int number;

  /// 所有者。
  final TurnOwner owner;

  /// 使用済みかどうか。
  final bool isUsed;

  LifeDeathCard copyWith({bool? isUsed}) {
    return LifeDeathCard(
      id: id,
      effect: effect,
      number: number,
      owner: owner,
      isUsed: isUsed ?? this.isUsed,
    );
  }
}
