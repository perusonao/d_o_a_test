import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:flutter/material.dart';

/// Converts one raw [GameActionLog] into the human-readable text block
/// section 12 asks for, e.g.:
///
/// ```
/// Turn 10
/// PLAYER / EXECUTOR
/// EYE → evil-1
/// 対象状態: dead
/// 決定時間: 8.4秒
/// EYE候補数: 2
/// 残りEYE: 1 → 0
/// ```
///
/// Action types are distinguished by an icon AND a text label (never color
/// alone, per section 12) — see [icon]/[actionTypeLabel].
abstract final class ActionLogFormatter {
  static String actionTypeLabel(String actionType) => switch (actionType) {
    'life' => 'LIFE',
    'death' => 'DEATH',
    'eye' => 'EYE',
    'specialVerdict' => 'JUDGE',
    'judge' => 'JUDGE',
    'confirmation' => '確定',
    _ => actionType.toUpperCase(),
  };

  static IconData icon(GameActionLog action) {
    if (action.wasReverseAction) return Icons.u_turn_left;
    if (action.bonusRevealTriggered) return Icons.card_giftcard;
    return switch (action.actionType) {
      'life' => Icons.favorite_outline,
      'death' => Icons.dangerous_outlined,
      'eye' => Icons.visibility_outlined,
      'specialVerdict' || 'judge' => Icons.gavel_outlined,
      'confirmation' => Icons.fact_check_outlined,
      _ => Icons.circle_outlined,
    };
  }

  static String header(GameActionLog action) =>
      'Turn ${action.turnNumber}\n'
      '${action.actingPlayer.toUpperCase()} / ${action.faction.toUpperCase()}';

  static List<String> detailLines(GameActionLog action) {
    final lines = <String>[];
    final label = actionTypeLabel(action.actionType);
    final reverseTag = action.wasReverseAction ? '（逆転の一手）' : '';
    lines.add('$label$reverseTag → ${action.targetPersonId}');
    lines.add('対象状態: ${action.stateBefore} → ${action.stateAfter}');
    if (action.eyeResult != null) {
      lines.add('EYE結果: ${action.eyeResult}');
    }
    if (action.turnDecisionTimeMs != null) {
      lines.add(
        '決定時間: ${(action.turnDecisionTimeMs! / 1000).toStringAsFixed(1)}秒',
      );
    }
    if (action.eyeCandidateCount != null) {
      lines.add('EYE候補数: ${action.eyeCandidateCount}');
    }
    if (action.eyeUsesRemainingBefore != null ||
        action.eyeUsesRemainingAfter != null) {
      lines.add(
        '残りEYE: ${action.eyeUsesRemainingBefore ?? '-'} → '
        '${action.eyeUsesRemainingAfter ?? '-'}',
      );
    }
    if (action.targetZone != null) {
      lines.add('対象ゾーン: ${action.targetZone}');
    }
    if (action.confirmedBy != null) {
      lines.add('確定: ${action.confirmedBy}');
    }
    if (action.verdictBonus != null) {
      lines.add('付与ボーナス: +${action.verdictBonus}（${action.scoringFaction ?? '-'}）');
    }
    if (action.bonusRevealTriggered) {
      lines.add(
        'ボーナス開示: ${action.bonusViewer ?? '-'} が '
        '${action.revealedBonus ?? '-'} を確認',
      );
    }
    if (action.judgeWasAvailable) {
      lines.add('この手番はJUDGE使用可能だった');
    }
    return lines;
  }
}
