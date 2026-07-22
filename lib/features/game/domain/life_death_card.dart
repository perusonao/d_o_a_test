import 'enums.dart';

/// プレイヤーが手札として持つ「生死カード」。
///
/// デッド / アライブ / キープ の効果と数字を持つ。
class LifeDeathCard {
  const LifeDeathCard({
    required this.id,
    required this.effect,
    required this.number,
    this.isUsed = false,
  });

  /// 一意な ID。
  final String id;

  /// 効果（dead / alive / keep）。
  final LifeDeathEffect effect;

  /// 数字（1〜9）。
  final int number;

  /// 使用済みかどうか（使用 or ペナルティ破棄で true）。
  final bool isUsed;

  LifeDeathCard copyWith({bool? isUsed}) {
    return LifeDeathCard(
      id: id,
      effect: effect,
      number: number,
      isUsed: isUsed ?? this.isUsed,
    );
  }
}
