import 'game_action.dart';

/// CPU が選んだ行動と、その評価理由（デバッグ・ログ用）。
class CpuDecision {
  const CpuDecision({
    required this.action,
    required this.score,
    this.reason = '',
  });

  /// 実行する行動。
  final GameAction action;

  /// 評価スコア（高いほど優先）。
  final double score;

  /// 選択理由（ログやデバッグ用の任意テキスト）。
  final String reason;
}
