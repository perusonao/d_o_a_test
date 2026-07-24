import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/handoff_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/result_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/selected_card_panel.dart';

class NineJudgesGameScreen extends StatefulWidget {
  const NineJudgesGameScreen({super.key});

  @override
  State<NineJudgesGameScreen> createState() => _NineJudgesGameScreenState();
}

class _NineJudgesGameScreenState extends State<NineJudgesGameScreen> {
  late final NineJudgesController controller;

  @override
  void initState() {
    super.initState();
    controller = NineJudgesController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isFinished) {
          return ResultScreen(controller: controller);
        }
        if (controller.awaitingHandoff) {
          return HandoffScreen(
            nextPlayer: controller.currentPlayer,
            onReady: controller.confirmHandoff,
          );
        }
        return _GameBoard(controller: controller);
      },
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({required this.controller});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final playerColor = controller.currentPlayer == Faction.savior
        ? const Color(0xFF71B9F0)
        : const Color(0xFFE36A62);
    final instruction = switch (controller.phase) {
      TurnPhase.selectingAction => 'アクションを選択',
      TurnPhase.selectingTarget => '${controller.selectedAction!.label}の対象を選択',
      TurnPhase.awaitingSave => 'アクション完了。SAVEしてください',
      TurnPhase.selectingSave => '判決する人物を選択',
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 4, 9, 7),
              child: Column(
                children: [
                  SizedBox(
                    height: 35,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '9人の審判',
                            style: TextStyle(
                              color: Color(0xFFD6B25E),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text('Turn ${controller.turn}'),
                        IconButton(
                          key: const Key('settings-button'),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.only(left: 8),
                          onPressed: () => _showSettings(context),
                          icon: const Icon(Icons.settings, size: 20),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '救済者 ${controller.debugMode ? controller.score.savior : '—'}',
                            style: const TextStyle(color: Color(0xFF71B9F0)),
                          ),
                        ),
                        Text(
                          controller.currentPlayer.label,
                          style: TextStyle(
                            color: playerColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '執行者 ${controller.debugMode ? controller.score.executor : '—'}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Color(0xFFE36A62)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: controller.judgedCount / 9,
                          color: const Color(0xFFD6B25E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '判決済み ${controller.judgedCount} / 9人',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    instruction,
                    key: const Key('phase-instruction'),
                    style: const TextStyle(
                      color: Color(0xFFD6B25E),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: BoardGrid(controller: controller)),
                  SelectedCardPanel(controller: controller),
                  ActionPanel(controller: controller),
                  if (controller.debugMode)
                    SizedBox(
                      height: 25,
                      child: TextButton(
                        onPressed: () => showGameLogs(context, controller),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text('検証ログを表示'),
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

  void _showSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('検証設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                key: const Key('debug-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('デバッグモード'),
                subtitle: const Text('全情報・得点・ログを表示'),
                value: controller.debugMode,
                onChanged: (value) {
                  controller.setDebugMode(value);
                  setDialogState(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('盤面再シャッフル'),
                onTap: () {
                  controller.reshuffle();
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ゲームリセット'),
                onTap: () {
                  controller.reset();
                  Navigator.pop(dialogContext);
                },
              ),
              if (controller.debugMode)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ゲームログ'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    showGameLogs(context, controller);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
