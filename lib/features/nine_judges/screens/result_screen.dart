import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.controller, super.key});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final score = controller.score;
    final winner = score.winner;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                children: [
                  const Text(
                    '最終判決',
                    style: TextStyle(
                      color: Color(0xFFD6B25E),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    winner == null ? 'DRAW' : 'WINNER ${winner.label}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '救済者 ${score.savior}',
                        style: const TextStyle(color: Color(0xFF71B9F0)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('―'),
                      ),
                      Text(
                        '執行者 ${score.executor}',
                        style: const TextStyle(color: Color(0xFFE36A62)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: BoardGrid(controller: controller, showScores: true),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('result-log'),
                          onPressed: () => showGameLogs(context, controller),
                          child: const Text('プレイログ'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FilledButton(
                          key: const Key('new-game'),
                          onPressed: controller.reset,
                          child: const Text('新しいゲーム'),
                        ),
                      ),
                    ],
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

void showGameLogs(BuildContext context, NineJudgesController controller) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('プレイログ'),
      content: SizedBox(
        width: double.maxFinite,
        child: controller.logs.isEmpty
            ? const Text('ログはまだありません')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: controller.logs.length,
                itemBuilder: (context, index) {
                  final log = controller.logs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      'Turn ${log.turn} ${log.player.label}\n${log.message}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}
