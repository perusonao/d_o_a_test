import 'enums.dart';

/// 効果判定の結果（Ver.0.3）。UI のアニメーション（成功/失敗/封印）に使う。
class ActionOutcome {
  const ActionOutcome({
    required this.actor,
    required this.effect,
    required this.number,
    required this.position,
    required this.success,
    required this.changed,
    required this.wasSealed,
  });

  final TurnOwner actor;
  final LifeDeathEffect effect;
  final int number;

  /// 対象の配置インデックス。
  final int position;

  /// パワー判定に成功したか。
  final bool success;

  /// 状態が実際に変化したか。
  final bool changed;

  /// 対象が（行動前から）封印されていたか。
  final bool wasSealed;
}
