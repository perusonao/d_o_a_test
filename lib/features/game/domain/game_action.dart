import 'enums.dart';

/// 1ターンの行動：どのアクションカードを、中央のどの位置に使うか。
class GameAction {
  const GameAction({
    required this.player,
    required this.actionCardId,
    required this.targetPosition,
  });

  final PlayerId player;
  final String actionCardId;
  final int targetPosition;
}
