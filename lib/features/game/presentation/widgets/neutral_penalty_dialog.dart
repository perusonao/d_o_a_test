import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../application/game_engine.dart';
import '../../domain/action_outcome.dart';

/// 中立ペナルティ発生時の目立つダイアログ。
Future<void> showNeutralPenaltyDialog(
    BuildContext context, ActionOutcome outcome) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.evil, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.evil),
            SizedBox(width: 8),
            Text('中立ペナルティ！',
                style: TextStyle(color: AppTheme.evil, fontSize: 18)),
          ],
        ),
        content: Text(
          '${GameLabels.owner(outcome.actor)}が中立カードに逆方向の状態変化を成功させました。\n'
          '生死カードを ${outcome.discardedByPenalty} 枚破棄しました。',
          style: const TextStyle(color: Color(0xFFCFC7B5), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      );
    },
  );
}
