import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/screens/play_log_screen.dart';

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
                          onPressed: () async {
                            await controller.ensureLogSaved();
                            if (!context.mounted) return;
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayLogScreen(
                                  repository: controller.logRepository,
                                ),
                              ),
                            );
                          },
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
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      key: const Key('playtest-feedback'),
                      onPressed: () => _showFeedback(context),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('テストプレイの感想を保存'),
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

  Future<void> _showFeedback(BuildContext context) async {
    final notes = TextEditingController(text: controller.session.notes);
    var fun = controller.session.funRating ?? 3;
    var reading = controller.session.readingRating ?? 3;
    var luck = controller.session.luckRating ?? 3;
    var tempo = controller.session.tempoRating ?? 3;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('テストプレイメモ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: notes,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: '感想（省略可能）'),
                ),
                _rating('面白さ', fun, (v) => setState(() => fun = v)),
                _rating('読み合い', reading, (v) => setState(() => reading = v)),
                _rating('運要素', luck, (v) => setState(() => luck = v)),
                _rating('テンポ', tempo, (v) => setState(() => tempo = v)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('スキップ'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.updatePlaytestFeedback(
                  notes: notes.text,
                  fun: fun,
                  reading: reading,
                  luck: luck,
                  tempo: tempo,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
  }

  Widget _rating(String label, int value, ValueChanged<int> onChanged) => Row(
    children: [
      SizedBox(width: 58, child: Text(label)),
      Expanded(
        child: Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
      Text('$value'),
    ],
  );
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
