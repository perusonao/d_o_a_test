import 'enums.dart';

/// 1ターンで実行される行動。
///
/// 「どの生死カードを、誰のどの人カードに使うか」を表す。
class GameAction {
  const GameAction({
    required this.actor,
    required this.lifeDeathCardId,
    required this.targetPersonId,
    required this.targetOwner,
  });

  /// 行動主体。
  final TurnOwner actor;

  /// 使用する生死カードの ID。
  final String lifeDeathCardId;

  /// 対象の人カードの ID。
  final String targetPersonId;

  /// 対象の人カードの所有者。
  final TurnOwner targetOwner;
}
