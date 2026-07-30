import 'dart:async';

import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/characters/character_intro_overlay.dart';
import 'package:dead_or_alive/features/nine_judges/characters/special_verdict_overlay.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/handoff_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/play_log_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/result_screen.dart';
import 'package:dead_or_alive/features/nine_judges/services/external_test_profile.dart';
import 'package:dead_or_alive/features/nine_judges/tutorial/tutorial_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_area.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/card_assets.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';

class NineJudgesGameScreen extends StatefulWidget {
  const NineJudgesGameScreen({
    this.initialSettings,
    this.autoStartTutorial = false,
    super.key,
  });
  final NineJudgesGameSettings? initialSettings;

  /// When true, a device that has never completed or skipped the tutorial
  /// (see [ExternalTestProfile]) is taken straight into it — instead of the
  /// mode-select menu — right after the first frame; the tutorial's own
  /// skip button/confirm dialog (and any back navigation) still let the
  /// player leave it at any time, same as opening it manually. Defaults to
  /// false so every existing direct-construction test (which never mocks a
  /// "first launch" profile) keeps seeing the mode-select screen
  /// immediately; the real app (see lib/app/app.dart) opts in.
  final bool autoStartTutorial;

  @override
  State<NineJudgesGameScreen> createState() => _NineJudgesGameScreenState();
}

class _NineJudgesGameScreenState extends State<NineJudgesGameScreen> {
  NineJudgesController? controller;
  bool _cpuSequenceRunning = false;
  bool _showingIntro = false;
  bool _autoTutorialAttempted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSettings case final settings?) {
      _startGame(settings);
    } else if (widget.autoStartTutorial) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeAutoStartTutorial(),
      );
    }
  }

  /// First-ever launch — before this device has completed or skipped the
  /// tutorial even once — opens it automatically. Every later launch
  /// (including right after finishing/skipping it) goes straight to the
  /// menu as normal.
  Future<void> _maybeAutoStartTutorial() async {
    if (_autoTutorialAttempted) return;
    _autoTutorialAttempted = true;
    final profile = await ExternalTestProfile.loadForNewGame();
    if (!mounted || controller != null) return;
    if (profile.hasCompletedTutorial || profile.hasSkippedTutorial) return;
    final startCpuMatch = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TutorialScreen()),
    );
    if (!mounted || startCpuMatch != true) return;
    // Mirrors mode_select_screen.dart's own "open-tutorial" tile: the
    // tutorial always teaches savior play against the CPU, so its "start a
    // CPU match" exit uses those same settings.
    _startGame(
      const NineJudgesGameSettings(
        mode: GameMode.cpu,
        factionSelection: FactionSelection.savior,
        firstPlayerSelection: FirstPlayerSelection.human,
      ),
      showIntro: true,
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  /// [showIntro] is only ever true from the real "ゲーム開始" button (see
  /// the `onStart:` wiring below) — it stays false for the `initialSettings`
  /// constructor path used by deep links/tests, so
  /// [CharacterIntroOverlay] never appears unless a player actually presses
  /// start.
  void _startGame(NineJudgesGameSettings settings, {bool showIntro = false}) {
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
    final newController = NineJudgesController(
      settings: settings,
      logRepository: LocalGameLogRepository.instance,
    )..addListener(_handleControllerChanged);
    controller = newController;
    _showingIntro = showIntro && !settings.skipCpuDelays;
    _handleControllerChanged();
    if (mounted) setState(() {});
    unawaited(_attachExternalTestContext(newController));
  }

  /// The external-test identity (anonymous testerId, play count, prior
  /// tutorial state) lives in local storage, so it's loaded asynchronously
  /// and merged into the session shortly after the game already starts —
  /// never blocking the first turn on it.
  Future<void> _attachExternalTestContext(NineJudgesController target) async {
    final profile = await ExternalTestProfile.loadForNewGame();
    if (!mounted || controller != target) return;
    target.applyExternalTestContext(profile);
  }

  /// Best-effort abandonment: only reachable while a game is in progress
  /// (the home button lives on [_GameBoard], never on the result screen),
  /// and never touches scoring/turn logic — it just tags the log and swaps
  /// back to the mode-select screen exactly like finishing normally would.
  Future<void> _returnToMenu() async {
    final game = controller;
    if (game != null) {
      await game.markAbandoned();
    }
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
    controller = null;
    if (mounted) setState(() {});
  }

  /// Reachable only from [ResultScreen]'s "ホームへ戻る" — the game already
  /// finished normally, so (unlike [_returnToMenu]) this never calls
  /// `markAbandoned()`.
  void _returnToMenuFromResult() {
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
    controller = null;
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    final game = controller;
    if (game == null ||
        // While the pre-game intro is up, defer even the CPU's very first
        // move until it's done (see the intro's onDone below) — otherwise a
        // CPU-goes-first game could resolve and clear its own turn message
        // while the intro is still covering the board, so the player would
        // never actually see it happen.
        _showingIntro ||
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
        onStart: (settings) => _startGame(settings, showIntro: true),
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
          return ResultScreen(
            controller: game,
            onGoHome: _returnToMenuFromResult,
          );
        }
        if (game.awaitingHandoff && !game.awaitingConfirmationReveal) {
          return HandoffScreen(
            nextPlayer: game.currentPlayer,
            onReady: game.confirmHandoff,
          );
        }
        final board = _GameBoard(controller: game, onExit: _returnToMenu);
        if (!_showingIntro) return board;
        return Stack(
          children: [
            board,
            Positioned.fill(
              child: CharacterIntroOverlay(
                humanFaction: game.isCpuGame ? game.humanFaction : null,
                onDone: () {
                  if (!mounted) return;
                  setState(() => _showingIntro = false);
                  // A CPU-goes-first turn was deferred by the intro guard
                  // in _handleControllerChanged — pick it up now that the
                  // intro is actually gone.
                  _handleControllerChanged();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GameBoard extends StatefulWidget {
  const _GameBoard({required this.controller, required this.onExit});
  final NineJudgesController controller;
  final VoidCallback onExit;

  @override
  State<_GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<_GameBoard> {
  NineJudgesController get controller => widget.controller;
  VoidCallback get onExit => widget.onExit;

  int? _effectIndex;
  ActionType? _effectAction;
  int _effectSerial = 0;

  /// Section ④: fires a brief, non-blocking flash over [index] for a
  /// LIFE/DEATH/EYE action that already resolved via `selectSlot` above —
  /// purely decorative, never gates the next turn.
  void _triggerCardEffect(int index, ActionType action) {
    setState(() {
      _effectIndex = index;
      _effectAction = action;
      _effectSerial++;
    });
  }

  void _clearCardEffect(int serial) {
    if (serial != _effectSerial) return;
    if (mounted) setState(() => _effectIndex = null);
  }

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
                    _GameHeader(controller: controller, onExit: onExit),
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
                            effectIndex: _effectIndex,
                            effectAction: _effectAction,
                            effectSerial: _effectSerial,
                            onEffectDone: () => _clearCardEffect(_effectSerial),
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
          Positioned.fill(
            child:
                controller.lastConfirmationAction == ActionType.specialVerdict
                ? SpecialVerdictOverlay(
                    actor: controller.lastConfirmationActor!,
                    instant: controller.settings.skipCpuDelays,
                    onDone: controller.confirmConfirmationReveal,
                  )
                : _ConfirmationOverlay(controller: controller),
          ),
      ],
    ),
  );

  Future<void> _handleTargetTap(BuildContext context, int index) async {
    if (controller.selectedAction == ActionType.eye &&
        controller.eyeZoneRestricted) {
      await _handleEyeTap(context, index);
      return;
    }
    if (controller.selectedAction != ActionType.specialVerdict) {
      final action = controller.selectedAction!;
      final wasLegal = controller.canTarget(index);
      controller.selectSlot(index);
      if (wasLegal) _triggerCardEffect(index, action);
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

  /// rulesVersion 1.2 only: EYE is capped at 2 uses per player, so a short
  /// confirmation (mirroring JUDGE's) guards against spending one by mistake.
  Future<void> _handleEyeTap(BuildContext context, int index) async {
    final actor = controller.currentPlayer;
    final remainingBefore = controller.eyeUsesRemaining(actor) ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('eye-confirm-dialog'),
        icon: const Icon(
          Icons.visibility_outlined,
          color: AppTheme.eye,
          size: 32,
        ),
        title: Text('${controller.positionLabel(index)}の正体を確認しますか？'),
        content: Text(
          '残りEYE: $remainingBefore → ${remainingBefore - 1}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            key: const Key('confirm-eye'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('EYE'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.canTarget(index)) {
      controller.selectSlot(index);
      _triggerCardEffect(index, ActionType.eye);
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
                // `remainingBonuses` counts every bonus not yet spent on a
                // confirmation, which still includes the "現在" one shown
                // above — already revealed to this viewer, so it must not
                // also be listed as an undisclosed "?" here.
                _hiddenBonusCount(current) <= 0
                    ? 'なし'
                    : List.filled(_hiddenBonusCount(current), '?').join(' / '),
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

  /// How many bonus values are still genuinely undisclosed to this viewer.
  /// [remainingBonuses] counts every bonus not yet *spent* on a
  /// confirmation, which includes the "現在" one shown separately above the
  /// moment it's been privately revealed — so it must be subtracted here to
  /// avoid listing an already-known value as a second "?".
  int _hiddenBonusCount(int? currentlyVisible) =>
      controller.remainingBonuses.length - (currentlyVisible != null ? 1 : 0);

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
  const _GameHeader({required this.controller, required this.onExit});
  final NineJudgesController controller;
  final VoidCallback onExit;

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
        Expanded(
          flex: 30,
          child: _TurnIndicator(controller: controller, onExit: onExit),
        ),
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

    // Both source crests have different canvas ratios. A fixed square stage
    // with contain-fit keeps their visual centres aligned instead of letting
    // ClipOval + cover crop each source differently.
    final crest = SizedBox(
      key: Key('faction-crest-area-${faction.name}'),
      width: 34,
      height: 34,
      child: Center(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: .18),
            border: Border.all(color: color.withValues(alpha: .7)),
          ),
          padding: const EdgeInsets.all(2),
          child: Image.asset(
            CardAssets.crest(faction),
            key: Key('faction-crest-${faction.name}'),
            fit: BoxFit.contain,
            alignment: Alignment.center,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                Icon(Icons.balance, color: color, size: 18),
          ),
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
        // Section ⑤: identity/JUDGE status are secondary info — still fully
        // present (nothing removed), just visually receded further behind
        // the score below so a glance lands on the number first.
        Text(
          identity,
          key: Key('identity-${faction.name}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            color: GameColors.textDim.withValues(alpha: .75),
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          controller.specialVerdictAvailable(faction) ? 'JUDGE ●1' : 'JUDGE 済',
          key: Key('verdict-status-${faction.name}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 7,
            color: GameColors.textDim.withValues(alpha: .65),
          ),
        ),
      ],
    );

    // Fixed-width + scale-down so a wide "POINT" caption can never eat into
    // the flexible labels column and force it to wrap (which caused a
    // vertical RenderFlex overflow at narrow phone widths). Section ⑤: the
    // score is one of the three things a player actually needs mid-game, so
    // it's sized a step above the surrounding labels (FittedBox still keeps
    // it safe on narrow screens).
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
                fontSize: 28,
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
  const _TurnIndicator({required this.controller, required this.onExit});
  final NineJudgesController controller;
  final VoidCallback onExit;

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
        Positioned(
          top: 0,
          left: 0,
          child: SizedBox(
            width: 26,
            height: 22,
            child: IconButton(
              key: const Key('game-home-button'),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              iconSize: 14,
              color: GameColors.textDim,
              onPressed: () => _confirmExit(context, onExit),
              icon: const Icon(Icons.home_outlined),
            ),
          ),
        ),
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
              // Section ⑤: whose turn it is is one of the three things a
              // player actually needs at a glance, so it gets a soft glowing
              // pill behind it on the player's own turn — the same text as
              // before, just harder to miss.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isHumanTurn
                      ? GameColors.gold.withValues(alpha: .12)
                      : Colors.transparent,
                  boxShadow: isHumanTurn
                      ? [
                          BoxShadow(
                            color: GameColors.gold.withValues(alpha: .25),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Diamond(muted: !isHumanTurn),
                    const SizedBox(width: 6),
                    // FittedBox (not a fixed font size + ellipsis) so "YOUR
                    // TURN"/"CPU TURN" always renders in full — on some
                    // devices this centre column is too narrow for the text
                    // at its natural size, and truncating whose-turn-it-is
                    // to "YOUR TU…" is worse than shrinking it slightly.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          big,
                          key: const Key('turn-big-label'),
                          maxLines: 1,
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
                    ),
                    const SizedBox(width: 6),
                    _Diamond(muted: !isHumanTurn),
                  ],
                ),
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

Future<void> _confirmExit(BuildContext context, VoidCallback onExit) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('exit-confirm-dialog'),
      title: const Text('ホームへ戻りますか？'),
      content: const Text('現在の対局は中断として記録され、続きから再開はできません。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('confirm-exit'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('ホームへ戻る'),
        ),
      ],
    ),
  );
  if (confirmed == true) onExit();
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

/// Which of the 9 fixed bonus-deck slots a [_BonusSlot] represents, purely
/// for its own appearance — never derived from real hidden data (the deck's
/// actual point values for un-used slots are never read here, only each
/// slot's *position* relative to [NineJudgesController.bonusHistory].
enum _BonusSlotState { used, current, hidden }

/// Verdict-bonus deck progress strip plus the ledger / recent-action
/// buttons. Shows the 9-slot bonus deck's progress as a 1-9 sequence (see
/// the "裁定ボーナス山札" redesign): already-spent slots are greyed with
/// their position number, the slot about to be spent is highlighted (with
/// its point value still only shown via the existing right-hand "N POINT" +
/// visibility label, unchanged), and not-yet-reached slots show the same
/// card-back/scale motif as the JUDGE action icon — never a "?" and never
/// tappable, since nothing here is new information beyond what the existing
/// current-bonus panel already revealed.
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
    final visibility = controller.bonusVisibilityLabel(viewer);
    final totalSlots = controller.bonusDeck.length;
    final usedCount = controller.bonusHistory.length;
    // 1-based position of the slot about to be spent, matching the fixed
    // 1-9 numbering used throughout this strip.
    final currentOrdinal = usedCount + 1;

    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Expanded(
            child: Container(
              key: const Key('current-bonus'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '裁定ボーナス山札（両者に公開）',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8,
                                color: Color(0xFFCBB682),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            SizedBox(
                              height: 20,
                              child: Row(
                                children: [
                                  for (var i = 1; i <= totalSlots; i++)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        child: _BonusSlot(
                                          ordinal: i,
                                          state: i < currentOrdinal
                                              ? _BonusSlotState.used
                                              : i == currentOrdinal
                                              ? _BonusSlotState.current
                                              : _BonusSlotState.hidden,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 4,
                        // FittedBox(scaleDown) — the 9-slot icon strip now
                        // shares this box with the point display, so "N
                        // POINT" no longer has the whole box width to
                        // itself; on narrow phones it could wrap to a
                        // second line and overflow this column's fixed
                        // height. Scaling down instead of wrapping keeps
                        // both lines fully readable at any width.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${bonus ?? '?'} POINT',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Color(0xFFFFDF79),
                                  fontSize: 18,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                  fontFamilyFallback: ['serif'],
                                ),
                              ),
                              Text(
                                visibility,
                                key: const Key('bonus-visibility-label'),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: GameColors.textDim,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

/// One box in the 9-slot bonus-deck progress strip. Never tappable — purely
/// a read-only progress indicator: already-spent slots (fewer than the
/// current ordinal) show their own position number greyed out, the slot
/// about to be spent is highlighted gold, and not-yet-reached slots show
/// the same scale/JUDGE motif as a face-down card — never a number or a
/// "?", since no slot here ever reveals an actual point value (that stays
/// solely in the existing right-hand "N POINT" display).
class _BonusSlot extends StatelessWidget {
  const _BonusSlot({required this.ordinal, required this.state});

  final int ordinal;
  final _BonusSlotState state;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == _BonusSlotState.current;
    final isHidden = state == _BonusSlotState.hidden;
    return Container(
      decoration: BoxDecoration(
        color: isCurrent
            ? GameColors.gold.withValues(alpha: .16)
            : Colors.white.withValues(alpha: isHidden ? .04 : .07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isCurrent ? GameColors.gold : GameColors.goldSoft,
          width: isCurrent ? 1.4 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: GameColors.gold.withValues(alpha: .35),
                  blurRadius: 5,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: isHidden
          ? Padding(
              padding: const EdgeInsets.all(3),
              child: Opacity(
                opacity: .55,
                child: Image.asset(
                  CardAssets.actionIcon(ActionType.specialVerdict),
                  fit: BoxFit.contain,
                ),
              ),
            )
          : Text(
              '$ordinal',
              style: TextStyle(
                fontSize: isCurrent ? 12 : 10,
                fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                color: isCurrent
                    ? GameColors.gold
                    : GameColors.textDim.withValues(alpha: .8),
              ),
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
          // Section ⑤: secondary controls (not the turn/score/bonus a player
          // actually needs mid-turn), so kept a step more muted than the
          // gold-accented HUD around them — still fully visible/tappable.
          border: Border.all(color: GameColors.textDim.withValues(alpha: .4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: GameColors.textDim),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: GameColors.textDim,
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
            if (controller.lastCpuEvaluations.isNotEmpty) ...[
              '',
              'CPU評価(上位候補・非表示は一般プレイヤーには出さない):',
              for (final candidate in controller.lastCpuEvaluations.take(5))
                '${candidate.action.name} -> slot${candidate.targetIndex}: '
                    '${candidate.score.toStringAsFixed(1)} '
                    '(${candidate.reasons.map((r) => '${r.key}:${r.value.toStringAsFixed(1)}').join(', ')})',
            ],
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
