import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/handoff_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/result_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/selected_card_panel.dart';

class NineJudgesGameScreen extends StatefulWidget {
  const NineJudgesGameScreen({this.initialSettings, super.key});

  final NineJudgesGameSettings? initialSettings;

  @override
  State<NineJudgesGameScreen> createState() => _NineJudgesGameScreenState();
}

class _NineJudgesGameScreenState extends State<NineJudgesGameScreen> {
  NineJudgesController? controller;
  bool _cpuSequenceRunning = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSettings case final settings?) {
      _startGame(settings);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _startGame(NineJudgesGameSettings settings) {
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
    controller = NineJudgesController(settings: settings)
      ..addListener(_handleControllerChanged);
    _handleControllerChanged();
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    final game = controller;
    if (game == null ||
        !game.isCpuTurn ||
        game.awaitingHandoff ||
        game.isFinished ||
        _cpuSequenceRunning) {
      return;
    }
    _runCpuSequence();
  }

  Future<void> _runCpuSequence() async {
    final game = controller;
    if (game == null) return;
    _cpuSequenceRunning = true;
    final delay = game.settings.skipCpuDelays
        ? Duration.zero
        : const Duration(milliseconds: 550);
    await Future<void>.delayed(delay);
    if (!mounted || game != controller || !game.isCpuTurn) {
      _cpuSequenceRunning = false;
      return;
    }
    game.performCpuAction();
    if (game.phase == TurnPhase.awaitingJudge) {
      await Future<void>.delayed(
        game.settings.skipCpuDelays
            ? Duration.zero
            : const Duration(milliseconds: 450),
      );
      if (mounted && game == controller) game.performCpuJudge();
    }
    _cpuSequenceRunning = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = controller;
    if (game == null) {
      return NineJudgesModeSelectScreen(onStart: _startGame);
    }
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        if (game.isFinished) {
          return ResultScreen(controller: game);
        }
        if (game.awaitingHandoff) {
          return HandoffScreen(
            nextPlayer: game.currentPlayer,
            onReady: game.confirmHandoff,
          );
        }
        return _GameBoard(controller: game);
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
      TurnPhase.selectingAction => 'LIFE / DEATH / EYEを選択',
      TurnPhase.selectingActionTarget =>
        '${controller.selectedAction!.label}の対象人物を選択',
      TurnPhase.awaitingJudge => 'JUDGEしてターンを終了',
      TurnPhase.selectingJudgeTarget => '判決する人物を選択',
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
                        Text('TURN ${controller.turn}'),
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
                            controller.debugMode
                                ? '救済者 ${controller.score.savior}'
                                : controller.isCpuGame
                                ? '救済者（あなた）\n善・中立→生 / 悪→死'
                                : '救済者\n善・中立→生 / 悪→死',
                            maxLines: 2,
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
                            controller.debugMode
                                ? '執行者 ${controller.score.executor}'
                                : controller.isCpuGame
                                ? '執行者（CPU）\n善・中立→死 / 悪→生'
                                : '執行者\n善・中立→死 / 悪→生',
                            maxLines: 2,
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
                  if (controller.isCpuTurn ||
                      controller.lastCpuActionMessage != null)
                    Container(
                      key: const Key('cpu-action-message'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2020),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFE36A62)),
                      ),
                      child: Text(
                        controller.isCpuTurn
                            ? controller.lastCpuActionMessage ??
                                  'CPU TURN  思考中…'
                            : controller.lastCpuActionMessage!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
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
              if (controller.isCpuGame) ...[
                DropdownButtonFormField<CpuLevel>(
                  key: const Key('settings-cpu-level'),
                  initialValue: controller.settings.cpuLevel,
                  decoration: const InputDecoration(labelText: 'CPUレベル'),
                  items: const [
                    DropdownMenuItem(
                      value: CpuLevel.random,
                      child: Text('EASY / RANDOM'),
                    ),
                    DropdownMenuItem(
                      value: CpuLevel.basic,
                      child: Text('NORMAL / BASIC'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    controller.updateSettings(
                      controller.settings.copyWith(cpuLevel: value),
                    );
                    setDialogState(() {});
                  },
                ),
                SwitchListTile(
                  key: const Key('skip-cpu-delays'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('CPU思考演出をスキップ'),
                  value: controller.settings.skipCpuDelays,
                  onChanged: (value) {
                    controller.updateSettings(
                      controller.settings.copyWith(skipCpuDelays: value),
                    );
                    setDialogState(() {});
                  },
                ),
                SwitchListTile(
                  key: const Key('cpu-evaluation-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('CPU評価値を表示'),
                  value: controller.settings.showCpuEvaluations,
                  onChanged: (value) {
                    controller.updateSettings(
                      controller.settings.copyWith(showCpuEvaluations: value),
                    );
                    setDialogState(() {});
                  },
                ),
                if (controller.settings.showCpuEvaluations &&
                    controller.lastCpuEvaluations.isNotEmpty)
                  Text(
                    controller.lastCpuEvaluations
                        .take(5)
                        .map(
                          (candidate) =>
                              '${candidate.action.label} slot${candidate.targetIndex + 1} '
                              '${candidate.score.toStringAsFixed(1)}',
                        )
                        .join('\n'),
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
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
