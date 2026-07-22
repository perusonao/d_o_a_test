import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../shared/utils/card_visuals.dart';
import '../game/application/game_controller.dart';
import '../game/domain/enums.dart';
import '../game/domain/game_result.dart';

/// リザルト画面（Ver.0.3・得点方式）。
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final result = controller.result();

    if (result == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.title);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final Color color;
    final String title;
    if (result.isDraw) {
      color = AppTheme.neutral;
      title = '引き分け';
    } else if (result.playerWon) {
      color = AppTheme.alive;
      title = 'あなたの勝利';
    } else {
      color = AppTheme.evil;
      title = 'あなたの敗北';
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    result.isDraw
                        ? Icons.balance
                        : result.playerWon
                            ? Icons.emoji_events
                            : Icons.sentiment_dissatisfied,
                    size: 60,
                    color: color,
                  ),
                  const SizedBox(height: 8),
                  Text(title,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  const SizedBox(height: 4),
                  Text(
                    result.isDraw
                        ? '同点'
                        : '勝者：${CardVisuals.roleLabel(result.winnerRole!)}',
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFFCFC7B5)),
                  ),
                  Text('あなたの役割：${CardVisuals.roleLabel(result.playerRole)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF9A9384))),
                  const SizedBox(height: 18),
                  _ScorePanel(result: result),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        controller.restartSameRole();
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
                child: _scoreTile('救済者', result.saviorScore, AppTheme.alive,
                    result.winnerRole == Role.savior),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _scoreTile('執行者', result.executionerScore,
                    AppTheme.evil, result.winnerRole == Role.executioner),
              ),
            ],
          ),
          const Divider(height: 22),
          _header('最終状態（全カード公開）'),
          _row(Icons.balance, AppTheme.good, '善人', result.aliveGood,
              result.deadGood),
          _row(Icons.local_fire_department, AppTheme.evil, '悪人',
              result.aliveEvil, result.deadEvil),
          _row(Icons.theater_comedy, AppTheme.neutral, '中立',
              result.aliveNeutral, result.deadNeutral),
          const SizedBox(height: 4),
          const Text('（生存 / 死亡）',
              style: TextStyle(fontSize: 11, color: Color(0xFF9A9384))),
        ],
      ),
    );
  }

  Widget _scoreTile(String label, int score, Color color, bool winner) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: winner ? color.withValues(alpha: 0.18) : Colors.transparent,
        border: Border.all(
            color: color.withValues(alpha: winner ? 0.8 : 0.3),
            width: winner ? 2 : 1),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text('$score',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(t,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold)),
        ),
      );

  Widget _row(IconData icon, Color color, String label, int alive, int dead) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 14, color: Color(0xFFCFC7B5))),
            const Spacer(),
            Text('$alive / $dead',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );
}
