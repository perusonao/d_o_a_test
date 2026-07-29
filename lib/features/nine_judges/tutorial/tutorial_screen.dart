import 'dart:async';

import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_log.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/services/external_test_profile.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// One scripted beat of the fixed lesson. Text is always two short lines —
/// 【今やること】 (what to do right now) then 【覚えること】 (the one rule this
/// beat teaches) — never a paragraph, so a first-time player can read it in
/// a glance instead of stopping to study prose.
class _TutorialStep {
  const _TutorialStep({
    required this.doNow,
    required this.remember,
    this.targetIndex,
    this.targetAction,
    this.actionLabel,
    this.actionIcon,
  });

  final String doNow;
  final String remember;

  /// The one board slot this beat is about, if any — spotlighted on
  /// [BoardGrid] and wired so tapping it (in addition to the main button)
  /// advances the lesson. `null` for narration-only beats (CPU turns,
  /// reminders) that only ever advance via the button.
  final int? targetIndex;
  final ActionType? targetAction;
  final String? actionLabel;
  final IconData? actionIcon;

  bool get isInteractive => targetIndex != null;
}

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({this.eventRepository, super.key});

  /// Injectable for tests; defaults to the real, persisted event log.
  final TutorialEventRepository? eventRepository;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late NineJudgesController game;
  late final TutorialEventRepository _events =
      widget.eventRepository ?? LocalTutorialEventRepository.instance;
  var step = 0;
  bool _exitOutcomeRecorded = false;

  /// Bumped on every successful action so the (fire-and-forget, never
  /// input-blocking) success badge always restarts cleanly even if the same
  /// step index is re-entered via "もう一度練習".
  int _feedbackSerial = 0;
  bool _showFeedback = false;

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      doNow: '盤面を確認しましょう。',
      remember: '自陣3人（A3・B3・C3）の正体は最初から見えています。',
    ),
    _TutorialStep(
      doNow: '善人B3に「LIFE」を使ってください。',
      remember: 'LIFEを2回受けると「生」に確定します。',
      targetIndex: 7,
      targetAction: ActionType.life,
      actionLabel: 'LIFEを使う',
      actionIcon: Icons.favorite,
    ),
    _TutorialStep(
      doNow: '中央のB2に「EYE」を使ってください。',
      remember: 'EYEは中央のA2・B2・C2にしか使えません。',
      targetIndex: 4,
      targetAction: ActionType.eye,
      actionLabel: 'EYEを使う',
      actionIcon: Icons.visibility,
    ),
    _TutorialStep(
      doNow: '「次へ」でCPUの番を見ましょう。',
      remember: 'EYEの結果は自分にしか見えません。',
    ),
    _TutorialStep(
      doNow: 'CPUの行動を確認しましょう。',
      remember: 'CPUがEYEを使ったことは分かっても、属性はあなたに見えません。',
    ),
    _TutorialStep(
      doNow: 'そのまま「次へ」で進みましょう。',
      remember: 'EYEは1ゲームにつき2回まで。あなたの残りは1回です。',
    ),
    _TutorialStep(
      doNow: 'そのまま「次へ」で進みましょう。',
      remember: '中央3人のうち2人しか見られません。残る1人は推理で見極めましょう。',
    ),
    _TutorialStep(
      doNow: 'CPUの「DEATH」に、もう一度「LIFE」で押し返しましょう。',
      remember: '3回目の判定でB3の生死が確定します。',
      targetIndex: 7,
      targetAction: ActionType.life,
      actionLabel: 'LIFEで押し返す',
      actionIcon: Icons.favorite,
    ),
    _TutorialStep(
      doNow: 'あなたもC1に「JUDGE」を使ってみましょう。',
      remember: 'JUDGEは正体を問わず生死を強制的に確定させます。',
      targetIndex: 2,
      targetAction: ActionType.specialVerdict,
      actionLabel: 'JUDGEを使う',
      actionIcon: Icons.gavel,
    ),
    _TutorialStep(
      doNow: 'そのまま「次へ」で進みましょう。',
      remember: '確定するたびに審判ボーナスが入ります。最初のボーナスは両者に公開されます。',
    ),
    _TutorialStep(
      doNow: 'お疲れさまでした！',
      remember: '中央3人のうち2人しか見られない読み合いを意識して、実戦に挑みましょう。',
    ),
  ];

  static final _totalSteps = _steps.length;

  @override
  void initState() {
    super.initState();
    _newGame();
    _record('tutorialStarted', step: 1);
    _record('tutorialStepReached', step: 1);
  }

  void _newGame() {
    game = NineJudgesController(
      seed: 1101,
      settings: const NineJudgesGameSettings(
        mode: GameMode.hotseat,
        firstPlayer: Faction.savior,
      ),
    );
    // B3 is always the known GOOD target in this deterministic lesson.
    final goodIndex = game.board.indexWhere(
      (slot) => slot.person.attribute == PersonAttribute.good,
    );
    final temporary = game.board[7];
    game.board[7] = game.board[goodIndex];
    game.board[goodIndex] = temporary;
  }

  @override
  void dispose() {
    if (!_exitOutcomeRecorded) {
      _record('tutorialSkipped', step: step + 1);
      unawaited(ExternalTestProfile.markTutorialSkipped());
    }
    game.dispose();
    super.dispose();
  }

  Future<ExternalTestProfile>? _profileFuture;

  void _record(String type, {required int step}) {
    unawaited(_recordAsync(type, step));
  }

  Future<void> _recordAsync(String type, int step) async {
    final profile = await (_profileFuture ??=
        ExternalTestProfile.loadForNewGame());
    await _events.record(
      TutorialEventRecord(
        type: type,
        sessionId: appSessionId,
        testerId: profile.testerId,
        timestamp: DateTime.now(),
        step: step,
      ),
    );
  }

  void _markCompleted() {
    if (_exitOutcomeRecorded) return;
    _exitOutcomeRecorded = true;
    _record('tutorialCompleted', step: step + 1);
    unawaited(ExternalTestProfile.markTutorialCompleted());
  }

  void _settle() {
    if (game.awaitingConfirmationReveal) {
      game.confirmConfirmationReveal();
    }
    if (game.awaitingHandoff) game.confirmHandoff();
  }

  /// Forces the actor for this scripted step: hotseat mode alternates
  /// [NineJudgesController.currentPlayer] after every real action, but this
  /// fixed lesson needs specific back-to-back actors (e.g. the player using
  /// two of their own actions in a row) regardless of whichever turn the
  /// engine would naturally be on. `currentPlayer` is plain mutable state on
  /// the controller — same liberty [initState] already takes with the board.
  bool _act(Faction actor, ActionType action, int target) {
    game.currentPlayer = actor;
    final applied = game.performTutorialAction(action, target);
    if (applied) _settle();
    return applied;
  }

  void _advance() {
    var applied = true;
    switch (step) {
      case 1:
        applied = _act(Faction.savior, ActionType.life, 7);
        break;
      case 2:
        applied = _act(Faction.savior, ActionType.eye, 4);
        break;
      case 3:
        applied = _act(Faction.executor, ActionType.eye, 3);
        break;
      case 7:
        applied = _act(Faction.executor, ActionType.death, 7);
        if (applied) applied = _act(Faction.savior, ActionType.life, 7);
        break;
      case 8:
        applied = _act(Faction.executor, ActionType.specialVerdict, 0);
        if (applied) {
          applied = _act(Faction.savior, ActionType.specialVerdict, 2);
        }
        break;
    }
    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作を適用できませんでした。もう一度お試しください。')),
      );
      return;
    }
    // Section ⑥: a small, non-blocking "success" beat right after a real
    // action lands — never gates the next tap (the step already advances
    // below regardless of whether this finishes painting).
    if (_steps[step].isInteractive) {
      HapticFeedback.lightImpact();
      setState(() {
        _feedbackSerial++;
        _showFeedback = true;
      });
    }
    setState(() => step = (step + 1).clamp(0, _totalSteps - 1));
    _record('tutorialStepReached', step: step + 1);
    if (step == _totalSteps - 1) _markCompleted();
  }

  /// "もう一度練習": restart the fixed lesson in place — a fresh board/step
  /// count, not a new completion/skip outcome (the player already finished
  /// once to reach this screen).
  void _restart() {
    final old = game;
    setState(() {
      _newGame();
      step = 0;
      _showFeedback = false;
    });
    old.dispose();
    _record('tutorialStepReached', step: 1);
  }

  Future<void> _confirmSkip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('tutorial-skip-dialog'),
        title: const Text('CPU戦を始めますか？'),
        content: const Text('チュートリアルを終了し、CPU戦を始めます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('tutorial-skip-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('CPU戦を始める'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  String get _buttonLabel {
    final action = _steps[step].actionLabel;
    if (action != null) return action;
    return '次へ';
  }

  @override
  Widget build(BuildContext context) {
    if (step >= _totalSteps - 1) {
      return _TutorialCompleteView(
        onPracticeAgain: _restart,
        onStartCpuMatch: () {
          _markCompleted();
          Navigator.pop(context, true);
        },
        onGoHome: () {
          _markCompleted();
          Navigator.pop(context, false);
        },
      );
    }

    final current = _steps[step];
    return Scaffold(
      appBar: AppBar(
        title: Text('STEP ${step + 1} / $_totalSteps'),
        actions: [
          TextButton(
            key: const Key('tutorial-skip'),
            onPressed: _confirmSkip,
            child: const Text('スキップ'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _TutorialProgressBar(current: step, total: _totalSteps),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Container(
                key: const Key('tutorial-message'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF302714),
                  border: Border.all(color: const Color(0xFFD6B25E)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '【今やること】',
                      style: TextStyle(
                        color: Color(0xFFD6B25E),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current.doNow,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '【覚えること】',
                      style: TextStyle(
                        color: Color(0xFFD6B25E),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(current.remember, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    BoardGrid(
                      controller: game,
                      spotlightIndex: current.targetIndex,
                      spotlightLabel: current.isInteractive ? 'ここをタップ' : null,
                      onTargetTap: current.isInteractive
                          ? (_) => _advance()
                          : null,
                    ),
                    if (_showFeedback)
                      _TutorialSuccessBadge(
                        key: ValueKey('tutorial-feedback-$_feedbackSerial'),
                        onDone: () {
                          if (mounted) setState(() => _showFeedback = false);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _TutorialActionButton(
                key: const Key('tutorial-next'),
                label: _buttonLabel,
                icon: current.actionIcon ?? Icons.arrow_forward,
                color: _colorForAction(current.targetAction),
                glow: current.isInteractive,
                onPressed: _advance,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForAction(ActionType? action) => switch (action) {
    ActionType.life => GameColors.life,
    ActionType.eye => GameColors.eye,
    ActionType.specialVerdict => GameColors.gold,
    ActionType.death || null => GameColors.gold,
  };
}

/// Slim 11-segment progress strip under the AppBar — "STEP 3 / 11" in the
/// title already states it in words; this adds an at-a-glance sense of how
/// much is left.
class _TutorialProgressBar extends StatelessWidget {
  const _TutorialProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < total; i++)
        Expanded(
          child: Container(
            key: Key('tutorial-progress-$i'),
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 2),
            color: i <= current
                ? GameColors.gold
                : GameColors.gold.withValues(alpha: .18),
          ),
        ),
    ],
  );
}

/// The single, always-present advance control (kept as one button — not a
/// second one alongside a plain "次へ" — so there is only ever one obvious
/// thing to press). Pulses gently when [glow] is true (an actionable step),
/// matching the target card's spotlight so both point at the same action.
class _TutorialActionButton extends StatefulWidget {
  const _TutorialActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.glow,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool glow;
  final VoidCallback onPressed;

  @override
  State<_TutorialActionButton> createState() => _TutorialActionButtonState();
}

class _TutorialActionButtonState extends State<_TutorialActionButton>
    with SingleTickerProviderStateMixin {
  // Assigned eagerly in initState — see the identical comment in
  // board_grid.dart's _BoardGridState for why a lazy `late final`
  // initializer here would be unsafe.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.glow) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _TutorialActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.glow && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.glow && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, child) => Container(
      decoration: widget.glow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(
                    alpha: 0.4 + 0.35 * _pulse.value,
                  ),
                  blurRadius: 12 + 10 * _pulse.value,
                  spreadRadius: 1 + 2 * _pulse.value,
                ),
              ],
            )
          : null,
      child: child,
    ),
    child: FilledButton.icon(
      onPressed: widget.onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: widget.glow ? widget.color : null,
        foregroundColor: widget.glow ? Colors.black : null,
        minimumSize: const Size.fromHeight(48),
      ),
      icon: Icon(widget.icon),
      label: Text(
        widget.label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
  );
}

/// Section ⑥: a brief, purely decorative "it worked" beat — a checkmark and
/// a short line ("OK！"/"その調子！") — after a real scripted action lands.
/// Wrapped in [IgnorePointer] and never awaited by the caller, so it can
/// never delay the next tap (same non-blocking pattern as the in-game
/// LIFE/DEATH/EYE card effect).
class _TutorialSuccessBadge extends StatefulWidget {
  const _TutorialSuccessBadge({required this.onDone, super.key});
  final VoidCallback onDone;

  @override
  State<_TutorialSuccessBadge> createState() => _TutorialSuccessBadgeState();
}

class _TutorialSuccessBadgeState extends State<_TutorialSuccessBadge>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 900);
  static const _lines = ['OK！', 'その調子！', 'いいですね！'];
  late final String _line = _lines[DateTime.now().microsecond % _lines.length];
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _duration)..forward();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    key: const Key('tutorial-success-badge'),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final appear = (t / 0.2).clamp(0.0, 1.0);
        final fade = t > 0.7 ? (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
        return Opacity(
          opacity: appear * fade,
          child: Transform.scale(
            scale: 0.85 + 0.15 * appear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xE6102018),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GameColors.life, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: GameColors.life,
                    size: 36,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _line,
                    style: const TextStyle(
                      color: GameColors.life,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Section ⑦: the dedicated screen shown once all steps are viewed, instead
/// of leaving the player on the last lesson board with two small buttons.
class _TutorialCompleteView extends StatelessWidget {
  const _TutorialCompleteView({
    required this.onPracticeAgain,
    required this.onStartCpuMatch,
    required this.onGoHome,
  });

  final VoidCallback onPracticeAgain;
  final VoidCallback onStartCpuMatch;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GameColors.background,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: GameColors.gold, size: 64),
              const SizedBox(height: 16),
              const Text(
                'チュートリアル完了！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: GameColors.gold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'あなたは基本ルールを習得しました。\n次はCPU戦で実際に審判してみましょう。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: GameColors.text),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('tutorial-complete'),
                  autofocus: true,
                  onPressed: onStartCpuMatch,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: GameColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'CPU戦を始める',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('tutorial-practice-again'),
                  onPressed: onPracticeAgain,
                  child: const Text('もう一度練習'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  key: const Key('tutorial-go-home'),
                  onPressed: onGoHome,
                  child: const Text('ホームへ戻る'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
