import 'enums.dart';

/// 効果判定の結果。UI のアニメーション（成功フラッシュ・失敗シェイク等）に使う。
class ActionOutcome {
  const ActionOutcome({
    required this.actor,
    required this.effect,
    required this.success,
    required this.targetPersonId,
    required this.targetOwner,
    required this.guardBlocked,
    required this.neutralPenalty,
    required this.discardedByPenalty,
    required this.lifeDeathCardId,
    required this.lifeDeathNumber,
  });

  /// 行動主体。
  final TurnOwner actor;

  /// 使った効果。
  final LifeDeathEffect effect;

  /// パワー判定に成功したか。
  final bool success;

  /// 対象の人カード ID。
  final String targetPersonId;

  /// 対象の所有者。
  final TurnOwner targetOwner;

  /// キープ防御によって dead/alive が無効化されたか。
  final bool guardBlocked;

  /// 中立ペナルティが発生したか。
  final bool neutralPenalty;

  /// ペナルティで破棄された枚数。
  final int discardedByPenalty;

  /// 使用した生死カード ID。
  final String lifeDeathCardId;

  /// 使用した生死カードの数字。
  final int lifeDeathNumber;
}
