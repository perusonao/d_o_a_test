import 'enums.dart';

/// 1ターンで実行される行動（Ver.0.3）。
///
/// 「どの生死カードを、中央のどの位置の人カードに使うか」。
class GameAction {
  const GameAction({
    required this.actor,
    required this.lifeDeathCardId,
    required this.targetPosition,
  });

  final TurnOwner actor;
  final String lifeDeathCardId;

  /// 対象の人カードの配置インデックス（0〜8）。
  final int targetPosition;
}
