import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../game/application/game_controller.dart';
import '../game/application/game_engine.dart';
import '../game/domain/game_result.dart';

/// リザルト画面。勝敗と集計を表示する。
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final result = controller.result();

    if (result == null) {
      // 状態が無い場合はタイトルへ。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.title);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final playerWon = result.playerWon;
    final resultColor = playerWon ? AppTheme.alive : AppTheme.evil;

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
                    playerWon ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                    size: 64,
                    color: resultColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    playerWon ? 'あなたの勝利' : 'あなたの敗北',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: resultColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '勝者：${GameLabels.faction(result.winner)}',
                    style: const TextStyle(
                        fontSize: 16, color: Color(0xFFCFC7B5)),
                  ),
                  Text(
                    'あなたの陣営：${GameLabels.faction(result.playerFaction)}',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF9A9384)),
                  ),
                  const SizedBox(height: 20),
                  _ResultTable(result: result),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        controller.restartSameFaction();
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

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.result});
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
          _header('生存しているカード'),
          _row(Icons.balance, AppTheme.good, '善人', result.aliveGood),
          _row(Icons.local_fire_department, AppTheme.evil, '悪人',
              result.aliveEvil),
          _row(Icons.theater_comedy, AppTheme.neutral, '中立',
              result.aliveNeutral),
          const Divider(height: 20),
          _header('死亡しているカード'),
          _row(Icons.balance, AppTheme.good, '善人', result.deadGood),
          _row(Icons.local_fire_department, AppTheme.evil, '悪人',
              result.deadEvil),
          _row(Icons.theater_comedy, AppTheme.neutral, '中立', result.deadNeutral),
          const Divider(height: 20),
          _plain('使用した生死カード', '${result.usedCardsTotal} 枚'),
          _plain('ペナルティで破棄', '${result.discardedTotal} 枚'),
        ],
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold)),
        ),
      );

  Widget _row(IconData icon, Color color, String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 14, color: Color(0xFFCFC7B5))),
            const Spacer(),
            Text('$value',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );

  Widget _plain(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 14, color: Color(0xFFCFC7B5))),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEDE6D4))),
          ],
        ),
      );
}
