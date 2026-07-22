import 'enums.dart';

/// ゲームログ1件分。試合中の全ログを内部的に保持する。
class GameLogEntry {
  const GameLogEntry({
    required this.message,
    required this.actor,
  });

  /// 表示用メッセージ。
  final String message;

  /// この行動を起こした主体（player / cpu）。null はシステムメッセージ。
  final TurnOwner? actor;
}
