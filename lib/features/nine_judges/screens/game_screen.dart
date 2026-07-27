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
import 'package:dead_or_alive/features/nine_judges/widgets/board_area.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/card_assets.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
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
    backgroundColor: GameColors.background,
    body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/backgrounds/courtroom.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: GameColors.background),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .28, .6, 1],
                colors: [
                  GameColors.backdropTop,
                  GameColors.backdropMid,
                  GameColors.backdropMid,
                  GameColors.backdropBottom,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 4, 7, 6),
                child: Column(
                  children: [
                    _GameHeader(controller: controller),
                    const SizedBox(height: GameMetrics.gap),
                    _BonusBar(
                      controller: controller,
                      onHistory: () =>
                          _showBonusHistory(context, controller.uiViewer),
                      onInfo: () => _showBonusInfo(context),
                      onRecent: () =>
                          _showHistory(context, controller.uiViewer),
                    ),
                    const SizedBox(height: GameMetrics.gap),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          BoardArea(
                            controller: controller,
                            onTargetTap: (index) =>
                                _handleTargetTap(context, index),
                          ),
                          if (controller.lastCpuActionMessage != null)
                            _CpuMessage(controller: controller),
                        ],
                      ),
                    ),
                    const SizedBox(height: GameMetrics.gapSm),
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
    final actor = controller.currentPlayer;
    // JUDGE's outcome is a fixed rule (savior -> alive, executor -> dead), not
    // hidden information, so previewing it here never leaks anything the
    // acting player doesn't already know from the rules themselves.
    final resultState = actor == Faction.savior ? '生存確定' : '死亡確定';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('judge-confirm-dialog'),
        icon: const Icon(Icons.balance, color: AppTheme.accent, size: 32),
        title: const Text('JUDGEを使用しますか？'),
        content: Text(
          '対象: ${controller.positionLabel(index)}\n'
          '正体: ${known ? person.attribute.label : '正体不明'}\n'
          '結果: ${actor.label} → $resultState',
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

  void _showBonusInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('遊び方のヒント'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('審判ボーナス', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text(
                '確定した人物1人につき1枚使われる得点です。'
                '最初のボーナスは両者に公開されます。'
                '以降は、直前の審判を確定させなかったプレイヤーが、'
                '次の自分の手番開始時に次のボーナスを確認できます。',
              ),
              SizedBox(height: 14),
              Text('カード下部の記号', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('生 ＝ LIFEを与えた履歴（生存へ寄せる）'),
              Text('死 ＝ DEATHを与えた履歴（死亡へ寄せる）'),
              Text('○ ＝ まだ何も行われていない'),
              SizedBox(height: 8),
              Text('EYEマーカー', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text(
                'カード右上の目印は、EYEで正体を確認した陣営を示します。'
                '相手だけが確認した場合、あなたには正体は分かりません。',
              ),
            ],
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

/// Top strip: savior on the left, executor on the right, turn state centred —
/// laid directly over the backdrop instead of in one wide panel.
class _GameHeader extends StatelessWidget {
  const _GameHeader({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 32,
          child: _PlayerPanel(controller: controller, faction: Faction.savior),
        ),
        const SizedBox(width: 6),
        Expanded(flex: 30, child: _TurnIndicator(controller: controller)),
        const SizedBox(width: 6),
        Expanded(
          flex: 32,
          child: _PlayerPanel(
            controller: controller,
            faction: Faction.executor,
          ),
        ),
      ],
    ),
  );
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.controller, required this.faction});
  final NineJudgesController controller;
  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final isSavior = faction == Faction.savior;
    final active = controller.currentPlayer == faction;
    final isHuman = !controller.isCpuGame || faction == controller.humanFaction;
    final color = GameColors.faction(isSavior);
    final identity = controller.isCpuGame
        ? (faction == controller.humanFaction ? 'あなた' : 'CPU')
        : faction.label;

    final crest = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .7)),
      ),
      child: ClipOval(
        child: Image.asset(
          CardAssets.crest(faction),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              Icon(Icons.balance, color: color, size: 18),
        ),
      ),
    );

    final labels = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isSavior
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          faction.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
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
            color: GameColors.textDim,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          controller.specialVerdictAvailable(faction) ? 'JUDGE ●1' : 'JUDGE 済',
          key: Key('verdict-status-${faction.name}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 7, color: GameColors.textDim),
        ),
      ],
    );

    // Fixed-width + scale-down so a wide "POINT" caption can never eat into
    // the flexible labels column and force it to wrap (which caused a
    // vertical RenderFlex overflow at narrow phone widths).
    final score = SizedBox(
      width: 38,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${controller.scores[faction]}',
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w900,
                fontFamilyFallback: const ['serif'],
              ),
            ),
            const Text(
              'POINT',
              maxLines: 1,
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 1.5,
                color: GameColors.textDim,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    final inner = isSavior
        ? [crest, const SizedBox(width: 6), Expanded(child: labels), score]
        : [score, Expanded(child: labels), const SizedBox(width: 6), crest];

    return Container(
      key: Key('faction-${faction.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isSavior ? Alignment.topLeft : Alignment.topRight,
          end: isSavior ? Alignment.bottomRight : Alignment.bottomLeft,
          colors: isSavior
              ? const [GameColors.saviorPanelTop, GameColors.saviorPanelBottom]
              : const [
                  GameColors.executorPanelTop,
                  GameColors.executorPanelBottom,
                ],
        ),
        borderRadius: BorderRadius.circular(GameMetrics.panelRadius),
        border: Border.all(
          color: isHuman
              ? (active ? GameColors.gold : const Color(0xFFC8A34A))
              : (active ? color : GameColors.goldSoft),
          width: isHuman ? (active ? 2 : 1.5) : (active ? 1.5 : 1),
        ),
        boxShadow: [
          if (isHuman)
            BoxShadow(
              color: GameColors.gold.withValues(alpha: active ? .34 : .16),
              blurRadius: active ? 12 : 6,
            ),
          if (active)
            BoxShadow(color: color.withValues(alpha: .25), blurRadius: 9),
        ],
      ),
      child: Row(children: inner),
    );
  }
}

/// Centre of the header: TURN counter, the big YOUR TURN / CPU line and the
/// precise "…の手番" label the tests key on.
class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({required this.controller});
  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.currentPlayer;
    final isHumanTurn =
        !controller.isCpuGame || current == controller.humanFaction;
    final big = controller.isCpuGame
        ? (isHumanTurn ? 'YOUR TURN' : 'CPU TURN')
        : current.label;
    final owner = controller.isCpuGame
        ? '${current == controller.humanFaction ? 'あなた' : 'CPU'}'
              '（${current.label}）の手番'
        : '${current.label}の手番';

    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'TURN ${controller.turn}  ・  確定 ${controller.confirmedCount}/9',
                style: const TextStyle(
                  fontSize: 8,
                  color: GameColors.textDim,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Diamond(muted: !isHumanTurn),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      big,
                      key: const Key('turn-big-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isHumanTurn
                            ? GameColors.gold
                            : GameColors.goldMuted,
                        fontSize: 15,
                        fontWeight: isHumanTurn
                            ? FontWeight.w900
                            : FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _Diamond(muted: !isHumanTurn),
                ],
              ),
              // Kept as a small, muted caption: the big headline above already
              // states whose turn it is, so this line only adds the precise
              // faction wording without competing for attention.
              Text(
                owner,
                key: const Key('turn-owner-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  color: GameColors.textDim,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (controller.settings.showCpuEvaluations)
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: 26,
              height: 22,
              child: IconButton(
                key: const Key('debug-button'),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  controller.setDebugMode(true);
                  await showDialog<void>(
                    context: context,
                    builder: (_) => _DebugDialog(controller: controller),
                  );
                  controller.setDebugMode(false);
                },
                icon: const Icon(Icons.bug_report_outlined, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}

class _Diamond extends StatelessWidget {
  const _Diamond({this.muted = false});
  final bool muted;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        border: Border.all(
          color: muted ? GameColors.textDim : GameColors.goldSoft,
        ),
      ),
    ),
  );
}

/// Compact verdict-bonus block plus the ledger / recent-action buttons.
class _BonusBar extends StatelessWidget {
  const _BonusBar({
    required this.controller,
    required this.onHistory,
    required this.onInfo,
    required this.onRecent,
  });

  final NineJudgesController controller;
  final VoidCallback onHistory;
  final VoidCallback onInfo;
  final VoidCallback onRecent;

  @override
  Widget build(BuildContext context) {
    final viewer = controller.uiViewer;
    final bonus = controller.visibleBonusFor(viewer);
    // The visibility label alone ("あなたのみ確認" etc.) doesn't tell a first-
    // time player what the bonus is even FOR. Prefix a short, static purpose
    // line — except for the very first bonus, whose own label already says
    // "両者に公開" and doesn't need the extra context.
    final visibility = controller.bonusVisibilityLabel(viewer);
    final purposeLine = controller.bonusIndex == 0 ? visibility : visibility;
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Expanded(
            child: Container(
              key: const Key('current-bonus'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xF01A1712), Color(0xF00C0B10)],
                ),
                borderRadius: BorderRadius.circular(GameMetrics.panelRadius),
                border: Border.all(color: GameColors.goldSoft, width: 1.2),
                boxShadow: const [
                  BoxShadow(color: GameColors.goldFaint, blurRadius: 8),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          controller.bonusIndex == 0 ? '最初の裁定ボーナス' : '次の裁定ボーナス',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFFCBB682),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${bonus ?? '?'} POINT',
                          style: const TextStyle(
                            color: Color(0xFFFFDF79),
                            fontSize: 20,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            fontFamilyFallback: ['serif'],
                          ),
                        ),
                        Text(
                          purposeLine,
                          key: const Key('bonus-visibility-label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8,
                            color: GameColors.textDim,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: IconButton(
                      key: const Key('bonus-info'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      onPressed: onInfo,
                      icon: const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: GameColors.textDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LedgerButton(
                buttonKey: const Key('bonus-history'),
                icon: Icons.receipt_long,
                label: '裁定履歴',
                onTap: onHistory,
              ),
              const SizedBox(height: 4),
              _LedgerButton(
                buttonKey: const Key('recent-history'),
                icon: Icons.history,
                label: '行動履歴',
                onTap: onRecent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerButton extends StatelessWidget {
  const _LedgerButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: buttonKey,
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xE60C0B12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: GameColors.goldSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: GameColors.gold),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: GameColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
