import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/screens/play_log_screen.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_bootstrap.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_playtest_repository.dart';

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
                  const SizedBox(height: 4),
                  _GameSummaryLine(controller: controller),
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
    var eyeChoice = controller.session.eyeChoiceRating ?? 3;
    var ruleUnderstanding = controller.session.ruleUnderstandingRating ?? 3;
    var judgeUsefulness = controller.session.judgeUsefulnessRating ?? 3;
    var eyeTension = controller.session.eyeTensionRating ?? 3;
    var strategicDepth = controller.session.strategicDepthRating ?? 3;
    var replayIntent = controller.session.replayIntentRating ?? 3;
    var clarity = 3;
    var sending = false;
    String? sendError;
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('この試合を評価してください'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '送信を選んだ場合のみ、匿名ID・対戦ログ・以下の評価を'
                  'ゲーム改善目的でFirebaseへ送信します。個人情報は入力不要です。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('feedback-comment'),
                  controller: notes,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText:
                        '分かりづらかった点、面白かった場面、'
                        '改善してほしい点があれば教えてください（省略可能）',
                  ),
                ),
                _rating(
                  '面白さ',
                  fun,
                  (v) => setState(() => fun = v),
                  emphasize: true,
                ),
                _rating(
                  '分かりやすさ',
                  ruleUnderstanding,
                  (v) => setState(() => ruleUnderstanding = v),
                  emphasize: true,
                ),
                _rating(
                  'また遊びたいか',
                  replayIntent,
                  (v) => setState(() => replayIntent = v),
                  emphasize: true,
                ),
                _rating('読み合い', reading, (v) => setState(() => reading = v)),
                _rating('運要素', luck, (v) => setState(() => luck = v)),
                _rating('テンポ', tempo, (v) => setState(() => tempo = v)),
                _rating(
                  'EYEの悩ましさ',
                  eyeChoice,
                  (v) => setState(() => eyeChoice = v),
                ),
                _rating(
                  'JUDGEの価値',
                  judgeUsefulness,
                  (v) => setState(() => judgeUsefulness = v),
                ),
                _rating(
                  'EYEでどこを見るか悩んだか',
                  eyeTension,
                  (v) => setState(() => eyeTension = v),
                ),
                _rating(
                  '読み合いの深さ',
                  strategicDepth,
                  (v) => setState(() => strategicDepth = v),
                ),
                _rating('明瞭さ', clarity, (v) => setState(() => clarity = v)),
                if (sendError != null)
                  Text(
                    sendError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
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
                  eyeChoice: eyeChoice,
                  ruleUnderstanding: ruleUnderstanding,
                  judgeUsefulness: judgeUsefulness,
                  eyeTension: eyeTension,
                  strategicDepth: strategicDepth,
                  replayIntent: replayIntent,
                  feedbackComment: notes.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, false);
              },
              child: const Text('保存'),
            ),
            FilledButton(
              key: const Key('send-playtest-data'),
              onPressed: !FirebaseBootstrap.available || sending
                  ? null
                  : () async {
                      setState(() {
                        sending = true;
                        sendError = null;
                      });
                      try {
                        await controller.updatePlaytestFeedback(
                          notes: notes.text,
                          fun: fun,
                          reading: reading,
                          luck: luck,
                          tempo: tempo,
                          eyeChoice: eyeChoice,
                          ruleUnderstanding: ruleUnderstanding,
                          judgeUsefulness: judgeUsefulness,
                          eyeTension: eyeTension,
                          strategicDepth: strategicDepth,
                          replayIntent: replayIntent,
                          feedbackComment: notes.text,
                        );
                        await const FirebasePlaytestRepository().send(
                          session: controller.session,
                          ratings: {
                            'fun': fun,
                            'reading': reading,
                            'luck': luck,
                            'tempo': tempo,
                            'eyeChoice': eyeChoice,
                            'ruleUnderstanding': ruleUnderstanding,
                            'judgeUsefulness': judgeUsefulness,
                            'eyeTension': eyeTension,
                            'strategicDepth': strategicDepth,
                            'replayIntent': replayIntent,
                            'clarity': clarity,
                          },
                          notes: notes.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (_) {
                        setState(() {
                          sending = false;
                          sendError = '送信できませんでした。ローカル結果は保持されています。';
                        });
                      }
                    },
              child: const Text('フィードバックを送信'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ご協力ありがとうございました')));
    }
  }

  Widget _rating(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    bool emphasize = false,
  }) => Row(
    children: [
      SizedBox(
        width: 58,
        child: Text(
          label,
          style: emphasize
              ? const TextStyle(fontWeight: FontWeight.w900)
              : null,
        ),
      ),
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

/// "今回の試合": ターン数・EYE使用回数・JUDGE使用有無・reverse使用有無 の一行サマリ。
class _GameSummaryLine extends StatelessWidget {
  const _GameSummaryLine({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final eyeCount = controller.session.actions
        .where((action) => action.actionType == ActionType.eye.name)
        .length;
    final judgeUsed =
        controller.specialVerdictUsed[Faction.savior]! ||
        controller.specialVerdictUsed[Faction.executor]!;
    final reverseUsed =
        controller.reverseActionUsed[Faction.savior]! ||
        controller.reverseActionUsed[Faction.executor]!;
    return Text(
      '今回の試合　ターン ${controller.session.totalTurns}　'
      'EYE $eyeCount回　JUDGE ${judgeUsed ? '使用' : '未使用'}　'
      'reverse ${reverseUsed ? '使用' : '未使用'}',
      key: const Key('result-summary'),
      textAlign: TextAlign.center,
      maxLines: 2,
      style: const TextStyle(fontSize: 11, color: Colors.white70),
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
