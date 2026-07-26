import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/handoff_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/play_log_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/result_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
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
                Flexible(
                  fit: FlexFit.loose,
                  child: AspectRatio(
                    aspectRatio: 1.08,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        BoardGrid(controller: controller),
                        if (controller.lastCpuActionMessage != null)
                          _CpuMessage(controller: controller),
                      ],
                    ),
                  ),
                ),
                SelectedCardPanel(controller: controller),
                const SizedBox(height: 4),
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
    final viewer = controller.uiViewer;
    final bonus = controller.visibleBonusFor(viewer);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FactionScore(
                controller: controller,
                faction: Faction.savior,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _FactionScore(
                controller: controller,
                faction: Faction.executor,
              ),
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
        const SizedBox(height: 3),
        Container(
          key: const Key('current-bonus'),
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF211D15),
            border: Border.all(color: const Color(0xFFD6B25E)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.bonusIndex == 0 ? '最初のボーナス' : '次のボーナス',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      controller.bonusVisibilityLabel(viewer),
                      key: const Key('bonus-visibility-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${bonus ?? '?'} POINT',
                style: const TextStyle(
                  color: Color(0xFFFFD76A),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                key: const Key('bonus-history'),
                tooltip: 'ボーナス履歴',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28),
                padding: EdgeInsets.zero,
                onPressed: () => _showBonusHistory(context, viewer),
                icon: const Icon(Icons.history, size: 17),
              ),
              IconButton(
                key: const Key('bonus-info'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28),
                padding: EdgeInsets.zero,
                onPressed: () => _showBonusInfo(context),
                icon: const Icon(Icons.info_outline, size: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                controller.isCpuGame
                    ? '${controller.currentPlayer == controller.humanFaction ? 'あなた' : 'CPU'}'
                          '（${controller.currentPlayer.label}）の手番'
                    : '${controller.currentPlayer.label}の手番',
                key: const Key('turn-owner-label'),
                style: const TextStyle(
                  color: Color(0xFFD6B25E),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              'TURN ${controller.turn}　確定 ${controller.confirmedCount}/9',
              style: const TextStyle(fontSize: 9),
            ),
          ],
        ),
        Row(
          children: [
            const Text(
              '直前の行動　',
              style: TextStyle(fontSize: 8, color: Colors.white54),
            ),
            Expanded(
              child: Text(
                controller.lastPublicAction(viewer) ?? 'まだありません',
                key: const Key('last-action'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9),
              ),
            ),
            SizedBox(
              height: 23,
              child: TextButton(
                key: const Key('recent-history'),
                onPressed: () => _showHistory(context, viewer),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: const Text('履歴', style: TextStyle(fontSize: 9)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showBonusInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('審判ボーナス'),
        content: const Text(
          '最初のボーナスは両者に公開されます。\n'
          '以降は、直前の審判を確定させなかったプレイヤーが、'
          '次の自分の手番開始時に次のボーナスを確認できます。',
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

  void _showBonusHistory(BuildContext context, Faction viewer) {
    final current = controller.visibleBonusFor(viewer);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '審判ボーナス履歴',
                key: Key('bonus-history-title'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              const Text('現在', style: TextStyle(color: Colors.white60)),
              Text(
                '${current ?? '?'} POINT',
                key: const Key('bonus-history-current'),
                style: const TextStyle(
                  color: Color(0xFFFFD76A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(controller.bonusVisibilityLabel(viewer)),
              const SizedBox(height: 12),
              const Text('使用済み', style: TextStyle(fontWeight: FontWeight.w900)),
              if (controller.bonusHistory.isEmpty)
                const Text('まだありません', style: TextStyle(fontSize: 12)),
              for (final result in controller.bonusHistory)
                Text(
                  '${result.order}　${result.bonus} POINT　'
                  '${result.attribute.label} / ${result.finalState.label}　'
                  '${result.scoringFaction.label}',
                  key: Key('used-bonus-${result.order}'),
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 12),
              const Text('残り', style: TextStyle(fontWeight: FontWeight.w900)),
              Text(
                controller.remainingBonuses.isEmpty
                    ? 'なし'
                    : controller.remainingBonuses.join(' / '),
                key: const Key('remaining-bonuses'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context, Faction viewer) {
    final recent = controller.logs.reversed.take(5).toList().reversed;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '直近の履歴',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty) const Text('まだ履歴はありません'),
              for (final log in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    'TURN ${log.turn}\n${controller.publicLogText(log, viewer)}',
                    key: Key('history-turn-${log.turn}'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactionScore extends StatelessWidget {
  const _FactionScore({required this.controller, required this.faction});
  final NineJudgesController controller;
  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final active = controller.currentPlayer == faction;
    final identity = controller.isCpuGame
        ? (faction == controller.humanFaction ? 'あなた' : 'CPU')
        : faction.label;
    return Container(
      key: Key('faction-${faction.name}'),
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF302714) : const Color(0xFF191919),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: active ? const Color(0xFFFFD76A) : Colors.white24,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(faction.label, style: const TextStyle(fontSize: 9)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        identity,
                        key: Key('identity-${faction.name}'),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      controller.specialVerdictAvailable(faction)
                          ? '審判●1'
                          : '審判済',
                      key: Key('verdict-status-${faction.name}'),
                      style: const TextStyle(
                        fontSize: 7,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${controller.scores[faction]}',
            style: TextStyle(
              color: faction == Faction.savior
                  ? const Color(0xFF69BDF2)
                  : const Color(0xFFF0645A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (active)
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Text(
                'TURN',
                style: TextStyle(
                  color: Color(0xFFFFD76A),
                  fontSize: 6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
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
            'eyeSeen: ${controller.eyeSeenSlots}',
            for (var i = 0; i < controller.board.length; i++)
              'slot$i ${controller.board[i].person.id} '
                  '${controller.board[i].person.attribute.name} '
                  '${controller.board[i].person.verdictState.name} '
                  'history=${controller.board[i].person.verdictHistory.map((e) => e.name).toList()} '
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
