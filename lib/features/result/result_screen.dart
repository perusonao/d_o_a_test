import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../shared/utils/card_visuals.dart';
import '../game/application/game_controller.dart';
import '../game/domain/enums.dart';
import '../game/domain/game_result.dart';

/// リザルト画面（Ver.0.4）。
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final result = controller.result();

    if (result == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.title);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final Color color;
    final String title;
    if (result.isDraw) {
      color = AppTheme.neutral;
      title = '引き分け';
    } else {
      color = CardVisuals.factionColor(result.winner!);
      final winnerPlayer =
          result.playerAFaction == result.winner ? 'プレイヤーA' : 'プレイヤーB';
      title = '$winnerPlayer の勝利';
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(result.isDraw ? Icons.balance : Icons.emoji_events,
                      size: 60, color: color),
                  const SizedBox(height: 8),
                  Text(title,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  if (!result.isDraw)
                    Text('勝利陣営：${CardVisuals.factionLabel(result.winner!)}',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFFCFC7B5))),
                  const SizedBox(height: 20),
                  _ScorePanel(result: result),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        controller.restart();
                        context.go(AppRoutes.game);
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('もう一度遊ぶ'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.title),
                      icon: const Icon(Icons.home),
                      label: const Text('タイトルへ戻る'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.result});
  final GameResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _tile(
                    '救済者',
                    result.saviorScore,
                    AppTheme.alive,
                    result.winner == Faction.savior,
                    result.playerAFaction == Faction.savior ? 'A' : 'B'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tile(
                    '執行者',
                    result.executionerScore,
                    AppTheme.evil,
                    result.winner == Faction.executioner,
                    result.playerAFaction == Faction.executioner ? 'A' : 'B'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('得点は各カード（善人/中立=生存で救済者・死亡で執行者、悪人=逆）の合計。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF9A9384))),
        ],
      ),
    );
  }

  Widget _tile(
      String label, int score, Color color, bool winner, String playerTag) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: winner ? color.withValues(alpha: 0.18) : Colors.transparent,
        border: Border.all(
            color: color.withValues(alpha: winner ? 0.8 : 0.3),
            width: winner ? 2 : 1),
      ),
      child: Column(
        children: [
          Text('$label（$playerTag）',
              style: TextStyle(fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text('$score',
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
