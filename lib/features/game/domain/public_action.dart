import 'enums.dart';

/// 公開される行動情報（Ver.0.3）。
///
/// 「誰が・どの位置に・どの効果・どの数字を使い・成否がどうだったか」は全公開。
/// 対象の正体（種類・数字）は含めない。CPU の推理や UI ログに使う。
class PublicAction {
  const PublicAction({
    required this.actor,
    required this.position,
    required this.effect,
    required this.number,
    required this.success,
    required this.changed,
    required this.targetSealed,
  });

  /// 行動主体。
  final TurnOwner actor;

  /// 対象の配置インデックス（0〜8）。
  final int position;

  /// 使用した効果。
  final LifeDeathEffect effect;

  /// 使用した生死カードの数字。
  final int number;

  /// パワー判定に成功したか（number >= 対象の数字）。
  final bool success;

  /// 実際に状態が変化したか（封印・同状態などで不変のことがある）。
  final bool changed;

  /// 行動時点で対象が封印されていたか。
  final bool targetSealed;
}
