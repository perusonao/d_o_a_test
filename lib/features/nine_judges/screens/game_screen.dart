import 'dart:async';

import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/handoff_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/play_log_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/result_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/card_assets.dart';
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
        if (game.isFinished && !game.awaitingConfirmationReveal) {
          return ResultScreen(controller: game);
        }
        if (game.awaitingHandoff && !game.awaitingConfirmationReveal) {
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
    body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/backgrounds/courtroom.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99070910),
                  Color(0xC00B0B10),
                  Color(0xF20B0B10),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                child: Column(
                  children: [
                    _Header(controller: controller),
                    const SizedBox(height: 3),
                    _PhaseBanner(controller: controller),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          BoardGrid(
                            controller: controller,
                            onTargetTap: (index) =>
                                _handleTargetTap(context, index),
                          ),
                          if (controller.lastCpuActionMessage != null)
                            _CpuMessage(controller: controller),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    const _Legend(),
                    const SizedBox(height: 3),
                    ActionPanel(controller: controller),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (controller.awaitingConfirmationReveal)
          Positioned.fill(child: _ConfirmationOverlay(controller: controller)),
      ],
    ),
  );

  Future<void> _handleTargetTap(BuildContext context, int index) async {
    if (controller.selectedAction != ActionType.specialVerdict) {
      controller.selectSlot(index);
      return;
    }
    final person = controller.board[index].person;
    final viewer = controller.uiViewer;
    final known = controller.knowsAttribute(person, viewer);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('judge-confirm-dialog'),
        icon: const Icon(Icons.balance, color: AppTheme.accent, size: 32),
        title: const Text('JUDGEを使用しますか？'),
        content: Text(
          '対象: ${controller.positionLabel(index)}\n'
          '正体: ${known ? person.attribute.label : '正体不明'}\n\n'
          'この人物を即時裁定します。',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            key: const Key('confirm-judge'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.balance),
            label: const Text('JUDGE'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.canTarget(index)) {
      controller.selectSlot(index);
    }
  }
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
            if (controller.settings.showCpuEvaluations)
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
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xE6332A1A), Color(0xE6141218)],
            ),
            border: Border.all(color: AppTheme.accent, width: 1.2),
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(color: Color(0x44C8A34A), blurRadius: 8),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.bonusIndex == 0 ? '最初の裁定ボーナス' : '次の裁定ボーナス',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFD8C89C),
                        fontWeight: FontWeight.w700,
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
                  color: Color(0xFFFFDF79),
                  fontSize: 18,
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
              'TURN ${controller.turn}  ・  確定 ${controller.confirmedCount}/9',
              style: const TextStyle(fontSize: 9),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(
              Icons.history_toggle_off,
              size: 11,
              color: Colors.white54,
            ),
            const SizedBox(width: 3),
            const Text(
              '直前  ',
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
                  '${result.order}回目　'
                  '${controller.positionLabel(result.targetIndex)}　'
                  '${result.bonus} POINT　'
                  '${result.attribute.label} / ${result.finalState.label}　'
                  '${result.scoringFaction.label}',
                  key: Key('used-bonus-${result.order}'),
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 12),
              const Text(
                '残り（順序非公開）',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                controller.remainingBonuses.isEmpty
                    ? 'なし'
                    : List.filled(
                        controller.remainingBonuses.length,
                        '?',
                      ).join(' / '),
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
    final isSelf = faction == controller.uiViewer;
    final factionColor = faction == Faction.savior
        ? AppTheme.savior
        : AppTheme.executor;
    return Container(
      key: Key('faction-${faction.name}'),
      height: 51,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            factionColor.withValues(alpha: active ? .30 : .16),
            const Color(0xEB111118),
          ],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active
              ? const Color(0xFFFFD76A)
              : isSelf
              ? AppTheme.accent
              : factionColor.withValues(alpha: .55),
          width: active ? 2 : 1.1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: factionColor.withValues(alpha: .32),
                  blurRadius: 9,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: factionColor.withValues(alpha: .7)),
            ),
            child: ClipOval(
              child: Image.asset(
                CardAssets.crest(faction),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.balance, color: factionColor, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faction.label,
                  style: TextStyle(
                    color: factionColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  identity,
                  key: Key('identity-${faction.name}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  controller.specialVerdictAvailable(faction)
                      ? 'JUDGE ●1'
                      : 'JUDGE 済',
                  key: Key('verdict-status-${faction.name}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 7, color: Colors.white60),
                ),
              ],
            ),
          ),
          Text(
            '${controller.scores[faction]} POINT',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: factionColor,
              height: 1,
              fontSize: 12,
              fontWeight: FontWeight.w900,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 16,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(text: '生 LIFE履歴', color: AppTheme.alive),
        SizedBox(width: 12),
        _LegendItem(text: '死 DEATH履歴', color: AppTheme.dead),
        SizedBox(width: 12),
        _LegendItem(
          text: '\u{1F441} EYE確認済',
          color: AppTheme.eye,
        ),
      ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w700),
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
        ? (controller.isCpuGame
              ? 'YOUR TURN  ・  あなたの手番'
              : '${controller.currentPlayer.label}の手番')
        : '${controller.selectedAction!.label}を使用する人物を選択';
    return Container(
      key: const Key('phase-instruction'),
      width: double.infinity,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xD91A1713),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accent.withValues(alpha: .65)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFEAD9A4),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
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

class _ConfirmationOverlay extends StatefulWidget {
  const _ConfirmationOverlay({required this.controller});
  final NineJudgesController controller;

  @override
  State<_ConfirmationOverlay> createState() => _ConfirmationOverlayState();
}

class _ConfirmationOverlayState extends State<_ConfirmationOverlay> {
  Timer? _timer;

  NineJudgesController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (!controller.settings.skipCpuDelays) {
      _timer = Timer(
        const Duration(milliseconds: 1400),
        controller.confirmConfirmationReveal,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetIndex = controller.confirmationTargetIndex;
    final person = targetIndex == null
        ? null
        : controller.board[targetIndex].person;
    final accent = person?.isAlive == true ? AppTheme.alive : AppTheme.dead;
    return GestureDetector(
      onTap: controller.confirmConfirmationReveal,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .72),
        child: Center(
          child: Container(
            key: const Key('confirmation-reveal'),
            margin: const EdgeInsets.all(38),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D261A), Color(0xFF111116)],
              ),
              border: Border.all(color: accent, width: 2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: .36), blurRadius: 18),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'JUDGEMENT',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  controller.confirmationRevealMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'タップで閉じる',
                  style: TextStyle(
                    color: accent.withValues(alpha: .8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
