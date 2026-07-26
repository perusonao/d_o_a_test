import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/handoff_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/play_log_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/result_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/hand_status_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/selected_card_panel.dart';
import 'package:flutter/material.dart';

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
    if (widget.initialSettings case final settings?) _startGame(settings);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _startGame(NineJudgesGameSettings settings) {
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
    controller = NineJudgesController(
      settings: settings,
      logRepository: LocalGameLogRepository.instance,
    )..addListener(_handleControllerChanged);
    _handleControllerChanged();
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    final game = controller;
    if (game == null ||
        !game.isCpuTurn ||
        game.awaitingHandoff ||
        game.awaitingConfirmationReveal ||
        game.awaitingBonusReveal ||
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
    await Future<void>.delayed(
      game.settings.skipCpuDelays
          ? Duration.zero
          : const Duration(milliseconds: 550),
    );
    if (mounted && game == controller && game.isCpuTurn) {
      game.performCpuAction();
      await Future<void>.delayed(
        game.settings.skipCpuDelays
            ? Duration.zero
            : const Duration(milliseconds: 950),
      );
      if (mounted && game == controller) game.clearCpuFeedback();
    }
    _cpuSequenceRunning = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = controller;
    if (game == null) {
      return NineJudgesModeSelectScreen(
        onStart: _startGame,
        onOpenLogs: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PlayLogScreen(repository: LocalGameLogRepository.instance),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        if (game.awaitingConfirmationReveal) {
          return _ConfirmationRevealScreen(controller: game);
        }
        if (game.isFinished) return ResultScreen(controller: game);
        if (game.awaitingBonusReveal) {
          return _BonusRevealScreen(controller: game);
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
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Column(
              children: [
                _Header(controller: controller),
                const SizedBox(height: 4),
                _PhaseBanner(controller: controller),
                const SizedBox(height: 5),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      BoardGrid(controller: controller),
                      if (controller.lastCpuActionMessage != null)
                        _CpuMessage(controller: controller),
                    ],
                  ),
                ),
                SelectedCardPanel(controller: controller),
                HandStatusPanel(controller: controller),
                const SizedBox(height: 3),
                ActionPanel(controller: controller),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final bonus = controller.visibleBonusFor(controller.currentPlayer);
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '9人の審判',
                style: TextStyle(
                  color: Color(0xFFD6B25E),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              'TURN ${controller.turn}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              key: const Key('debug-button'),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                controller.setDebugMode(true);
                await showDialog<void>(
                  context: context,
                  builder: (_) => _DebugDialog(controller: controller),
                );
                controller.setDebugMode(false);
              },
              icon: const Icon(Icons.bug_report_outlined, size: 18),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '救済者 ${controller.scores[Faction.savior]}',
                style: const TextStyle(color: Color(0xFF69BDF2)),
              ),
            ),
            Container(
              key: const Key('current-bonus'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD6B25E)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('次のボーナス ${bonus ?? '?'} POINT'),
            ),
            Expanded(
              child: Text(
                '執行者 ${controller.scores[Faction.executor]}',
                textAlign: TextAlign.end,
                style: const TextStyle(color: Color(0xFFF0645A)),
              ),
            ),
          ],
        ),
        Text(
          '${controller.currentPlayer.label}の手番　確定 ${controller.confirmedCount}/9',
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

class _DebugDialog extends StatelessWidget {
  const _DebugDialog({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('デバッグ情報'),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: SelectableText(
          [
            'bonusDeck: ${controller.bonusDeck}',
            'currentBonus: ${controller.currentBonus}',
            'privateBonus: ${controller.privateBonusKnowledge}',
            'pendingReveal: ${controller.pendingBonusReveal}',
            'score: ${controller.scores}',
            'knowledge: ${controller.knownAttributeSlots}',
            for (var i = 0; i < controller.board.length; i++)
              'slot$i ${controller.board[i].person.id} '
                  '${controller.board[i].person.attribute.name} '
                  '${controller.board[i].person.verdictState.name} '
                  'actions=${controller.board[i].person.verdictActionCount} '
                  'confirmedBy=${controller.board[i].person.confirmedBy?.name} '
                  'scoreTo=${controller.board[i].person.scoringFaction?.name} '
                  'bonus=${controller.board[i].person.awardedBonus}',
            for (final log in controller.logs)
              'Turn ${log.turn} ${log.player.name}: ${log.message}',
          ].join('\n'),
          style: const TextStyle(fontSize: 10),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('閉じる'),
      ),
    ],
  );
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.isCpuTurn
        ? 'CPUが思考中…'
        : controller.phase == TurnPhase.selectingAction
        ? 'アクションを選択してください'
        : '${controller.selectedAction!.label}の対象を選択してください';
    return Container(
      key: const Key('phase-instruction'),
      width: double.infinity,
      height: 29,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF201D16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF806A36)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _CpuMessage extends StatelessWidget {
  const _CpuMessage({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: controller.clearCpuFeedback,
    child: Container(
      key: const Key('cpu-action-message'),
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF0211D15),
        border: Border.all(color: const Color(0xFFD6B25E), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'CPU ACTION\n${controller.lastCpuActionType?.label}\n'
        '${controller.lastCpuActionMessage}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _BonusRevealScreen extends StatelessWidget {
  const _BonusRevealScreen({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final viewer = controller.currentPlayer.opponent;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${viewer.label}だけの秘密情報'),
              const SizedBox(height: 18),
              Text(
                '次の審判ボーナス\n${controller.visibleBonusFor(viewer)} POINT',
                key: const Key('private-bonus-reveal'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD6B25E),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: controller.confirmBonusReveal,
                child: const Text('確認しました'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationRevealScreen extends StatelessWidget {
  const _ConfirmationRevealScreen({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Container(
          key: const Key('confirmation-reveal'),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF211D15),
            border: Border.all(color: const Color(0xFFD6B25E), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '審判確定',
                style: TextStyle(
                  color: Color(0xFFD6B25E),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                controller.confirmationRevealMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: controller.confirmConfirmationReveal,
                child: const Text('確認'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
