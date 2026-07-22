import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/game_constants.dart';
import '../../domain/game_state.dart';

/// 直近数件のゲームログを表示する Widget。
class GameLogView extends StatelessWidget {
  const GameLogView({super.key, required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final logs = state.logs;
    final recent = logs.length <= GameConstants.visibleLogCount
        ? logs
        : logs.sublist(logs.length - GameConstants.visibleLogCount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in recent)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('› ',
                    style: TextStyle(color: AppTheme.accent, fontSize: 11)),
                Expanded(
                  child: Text(
                    entry.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFCFC7B5), height: 1.25),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
