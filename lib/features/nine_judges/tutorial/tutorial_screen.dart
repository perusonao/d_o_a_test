import 'dart:async';

import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/logging/tutorial_event_log.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/services/external_test_profile.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/widgets/showcase_effects.dart'
    show ParticleBurstEffect;
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Section ⑧'s shared strength scale for every non-narration beat this
/// screen shows: LIFE/DEATH progress is "medium", EYE/JUDGE outcomes are
/// "strong" — a bonus award (the actual "strongest" tier) always takes
/// priority over either and gets its own dedicated [_BonusBanner] instead,
/// so the player's eye is always drawn to whichever event matters most.
enum _FeedbackTier { medium, strong }

/// One scripted beat of the fixed lesson. [remember] is always the header —
/// "今回覚えること", the one rule this beat teaches, 1-2 lines — with
/// [doNow] (what to actually do right now) underneath as a secondary line.
/// Never a paragraph, so a first-time player can read it in a glance instead
/// of stopping to study prose.
class _TutorialStep {
  const _TutorialStep({
    required this.remember,
    required this.doNow,
    this.targetIndex,
    this.targetAction,
    this.actionLabel,
    this.actionIcon,
  });

  final String remember;
  final String doNow;

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
  const TutorialScreen({
    this.eventRepository,
    this.beatDuration = const Duration(milliseconds: 800),
    super.key,
  });

  /// Injectable for tests; defaults to the real, persisted event log.
  final TutorialEventRepository? eventRepository;

  /// How long each non-blocking "see what just happened" beat holds — the
  /// LIFE/DEATH progress badge, EYE's reveal, JUDGE's confirm flash, the
  /// CPU's own visible pause (section ④), and the bonus banner (section
  /// ⑤). Tests pass `Duration.zero` to keep the scripted flow fast and
  /// free of real pending Timers; production uses a short, deliberately
  /// unhurried default so a first-time player can actually see what
  /// changed instead of the board just snapping to its new state.
  final Duration beatDuration;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late NineJudgesController game;
  late final TutorialEventRepository _events =
      widget.eventRepository ?? LocalTutorialEventRepository.instance;
  var step = 0;
  bool _exitOutcomeRecorded = false;

  /// Guards against a second tap starting a new scripted action while the
  /// current one is still mid-beat (CPU pause / card badge / bonus banner).
  bool _busy = false;

  int? _cardBadgeIndex;
  String? _cardBadgeText;
  _FeedbackTier? _cardBadgeTier;
  int _cardBadgeSerial = 0;

  int? _bonusAmount;
  Faction? _bonusFaction;
  int _bonusSerial = 0;

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      remember: '自陣3人（A3・B3・C3）の正体は最初から見えています。',
      doNow: '盤面を確認しましょう。',
    ),
    _TutorialStep(
      remember: 'LIFEを2回受けると「生」に確定します。',
      doNow: '善人B3に「LIFE」を使ってください。',
      targetIndex: 7,
      targetAction: ActionType.life,
      actionLabel: 'LIFEを使う',
      actionIcon: Icons.favorite,
    ),
    _TutorialStep(
      remember: 'EYEで相手の属性を確認できます。',
      doNow: '中央のB2に「EYE」を使ってください。',
      targetIndex: 4,
      targetAction: ActionType.eye,
      actionLabel: 'EYEを使う',
      actionIcon: Icons.visibility,
    ),
    _TutorialStep(
      remember: 'EYEの結果は自分にしか見えません。',
      doNow: '「次へ」でCPUの番を見ましょう。',
    ),
    _TutorialStep(
      remember: 'CPUがEYEを使ったことは分かっても、属性はあなたに見えません。',
      doNow: 'CPUの行動を確認しましょう。',
    ),
    _TutorialStep(
      remember: 'EYEは1ゲームにつき2回まで。あなたの残りは1回です。',
      doNow: 'そのまま「次へ」で進みましょう。',
    ),
    _TutorialStep(
      remember: '中央3人のうち2人しか見られません。残る1人は推理で見極めましょう。',
      doNow: 'そのまま「次へ」で進みましょう。',
    ),
    _TutorialStep(
      remember: '3回目の判定でB3の生死が確定します。',
      doNow: 'CPUの「DEATH」に、もう一度「LIFE」で押し返しましょう。',
      targetIndex: 7,
      targetAction: ActionType.life,
      actionLabel: 'LIFEで押し返す',
      actionIcon: Icons.favorite,
    ),
    _TutorialStep(
      remember: 'JUDGEは正体を問わず生死を強制的に確定させます。',
      doNow: 'あなたもC1に「JUDGE」を使ってみましょう。',
      targetIndex: 2,
      targetAction: ActionType.specialVerdict,
      actionLabel: 'JUDGEを使う',
      actionIcon: Icons.gavel,
    ),
    _TutorialStep(
      remember: 'ボーナス得点を獲得すると一気に逆転できます。',
      doNow: 'そのまま「次へ」で進みましょう。',
    ),
    _TutorialStep(
      remember: '中央3人のうち2人しか見られない読み合いを意識して、実戦に挑みましょう。',
      doNow: 'お疲れさまでした！',
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

  /// Section ②③④⑥: after a real scripted action lands, hold a short,
  /// non-blocking beat showing what just happened — instead of relying on
  /// prose to explain it. A freshly-confirmed card with an awarded bonus
  /// takes priority over its own action badge (section ⑧'s "only the truly
  /// important beat gets the strongest treatment" rule) and shows the
  /// bonus banner instead. EYE only reveals the attribute when the human
  /// (savior, in this fixed lesson) is the one using it — CPU's own EYE
  /// keeps the same info-hiding the real rules already guarantee.
  Future<void> _afterAction(
    int index,
    ActionType action,
    Faction actor,
    PersonCard before,
  ) async {
    final after = game.board[index].person;
    final justConfirmed = !before.isConfirmed && after.isConfirmed;
    if (justConfirmed && after.awardedBonus != null) {
      setState(() {
        _bonusSerial++;
        _bonusAmount = after.awardedBonus;
        _bonusFaction = after.scoringFaction;
      });
      await Future<void>.delayed(widget.beatDuration);
      if (!mounted) return;
      setState(() => _bonusAmount = null);
      return;
    }

    final String text;
    final _FeedbackTier tier;
    switch (action) {
      case ActionType.eye:
        text = actor == Faction.savior
            ? '${after.attribute.label}でした'
            : 'CPUがEYEを使用';
        tier = _FeedbackTier.strong;
      case ActionType.specialVerdict:
        text = '確定！';
        tier = _FeedbackTier.strong;
      case ActionType.life:
      case ActionType.death:
        text = after.isConfirmed
            ? '確定！'
            : 'あと${3 - after.verdictActionCount}回で確定！';
        tier = _FeedbackTier.medium;
    }
    setState(() {
      _cardBadgeSerial++;
      _cardBadgeIndex = index;
      _cardBadgeText = text;
      _cardBadgeTier = tier;
    });
    await Future<void>.delayed(widget.beatDuration);
    if (!mounted) return;
    setState(() => _cardBadgeIndex = null);
  }

  Future<void> _advance() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var applied = true;
      switch (step) {
        case 1:
          {
            final before = game.board[7].person;
            applied = _act(Faction.savior, ActionType.life, 7);
            if (applied) {
              await _afterAction(7, ActionType.life, Faction.savior, before);
            }
          }
        case 2:
          {
            final before = game.board[4].person;
            applied = _act(Faction.savior, ActionType.eye, 4);
            if (applied) {
              await _afterAction(4, ActionType.eye, Faction.savior, before);
            }
          }
        case 3:
          {
            final before = game.board[3].person;
            applied = _act(Faction.executor, ActionType.eye, 3);
            if (applied) {
              await _afterAction(3, ActionType.eye, Faction.executor, before);
            }
          }
        case 7:
          {
            final beforeDeath = game.board[7].person;
            applied = _act(Faction.executor, ActionType.death, 7);
            if (applied) {
              await _afterAction(
                7,
                ActionType.death,
                Faction.executor,
                beforeDeath,
              );
              final beforeLife = game.board[7].person;
              applied = _act(Faction.savior, ActionType.life, 7);
              if (applied) {
                await _afterAction(
                  7,
                  ActionType.life,
                  Faction.savior,
                  beforeLife,
                );
              }
            }
          }
        case 8:
          {
            final beforeCpu = game.board[0].person;
            applied = _act(Faction.executor, ActionType.specialVerdict, 0);
            if (applied) {
              await _afterAction(
                0,
                ActionType.specialVerdict,
                Faction.executor,
                beforeCpu,
              );
              final beforePlayer = game.board[2].person;
              applied = _act(Faction.savior, ActionType.specialVerdict, 2);
              if (applied) {
                await _afterAction(
                  2,
                  ActionType.specialVerdict,
                  Faction.savior,
                  beforePlayer,
                );
              }
            }
          }
      }
      if (!applied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('操作を適用できませんでした。もう一度お試しください。')),
          );
        }
        return;
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => step = (step + 1).clamp(0, _totalSteps - 1));
      _record('tutorialStepReached', step: step + 1);
      if (step == _totalSteps - 1) _markCompleted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "もう一度練習": restart the fixed lesson in place — a fresh board/step
  /// count, not a new completion/skip outcome (the player already finished
  /// once to reach this screen).
  void _restart() {
    final old = game;
    setState(() {
      _newGame();
      step = 0;
      _cardBadgeIndex = null;
      _bonusAmount = null;
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
              _ScoreRow(controller: game, beatDuration: widget.beatDuration),
              const SizedBox(height: 6),
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
                      '今回覚えること',
                      key: Key('tutorial-remember-label'),
                      style: TextStyle(
                        color: GameColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current.remember,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: GameColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '【今やること】',
                          style: TextStyle(
                            color: Color(0xFF9C927D),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            current.doNow,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9C927D),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                      onTargetTap: current.isInteractive && !_busy
                          ? (_) => _advance()
                          : null,
                    ),
                    if (_cardBadgeIndex != null)
                      _TutorialCardBadge(
                        key: ValueKey('tutorial-card-badge-$_cardBadgeSerial'),
                        text: _cardBadgeText!,
                        tier: _cardBadgeTier!,
                      ),
                    if (_bonusAmount != null)
                      _BonusBanner(
                        key: ValueKey('tutorial-bonus-$_bonusSerial'),
                        amount: _bonusAmount!,
                        faction: _bonusFaction!,
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
                onPressed: _busy ? null : _advance,
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

/// Section ⑤: a compact savior/executor score readout with a count-up
/// animation whenever either score changes — otherwise a bonus award has
/// nothing visible to "add itself to".
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.controller, required this.beatDuration});
  final NineJudgesController controller;
  final Duration beatDuration;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ScoreChip(
          label: '救済者',
          score: controller.scores[Faction.savior]!,
          color: GameColors.savior,
          duration: beatDuration,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: _ScoreChip(
          label: '執行者',
          score: controller.scores[Faction.executor]!,
          color: GameColors.executor,
          duration: beatDuration,
          alignEnd: true,
        ),
      ),
    ],
  );
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.label,
    required this.score,
    required this.color,
    required this.duration,
    this.alignEnd = false,
  });

  final String label;
  final int score;
  final Color color;
  final Duration duration;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: alignEnd
        ? MainAxisAlignment.end
        : MainAxisAlignment.start,
    children: [
      if (!alignEnd) ...[_label(), const SizedBox(width: 4)],
      TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: score),
        duration: duration == Duration.zero
            ? const Duration(milliseconds: 1)
            : duration,
        builder: (context, value, child) => Text(
          '$value',
          key: const Key('tutorial-score-value'),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (alignEnd) ...[const SizedBox(width: 4), _label()],
    ],
  );

  Widget _label() => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF9C927D),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
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
  final VoidCallback? onPressed;

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

/// Section ②③⑥: a brief, purely decorative "here's what changed" badge
/// over the board — LIFE/DEATH's confirmation progress, or EYE/JUDGE's
/// outcome — styled a step stronger for [_FeedbackTier.strong] than
/// [_FeedbackTier.medium] (section ⑧). Never awaited by the caller (the
/// parent's own `beatDuration` timer, not this widget, decides how long it
/// stays mounted), so it can never delay the next tap.
class _TutorialCardBadge extends StatelessWidget {
  const _TutorialCardBadge({required this.text, required this.tier, super.key});

  final String text;
  final _FeedbackTier tier;

  @override
  Widget build(BuildContext context) {
    final strong = tier == _FeedbackTier.strong;
    final accent = strong ? GameColors.eye : GameColors.life;
    return IgnorePointer(
      key: const Key('tutorial-card-badge'),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: strong ? 16 : 12,
            vertical: strong ? 10 : 7,
          ),
          decoration: BoxDecoration(
            color: const Color(0xE6141019),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent, width: strong ? 2.5 : 1.5),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: .55), blurRadius: strong ? 16 : 8),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: strong ? 16 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section ⑤: the "most important thing that can happen" beat — a bonus
/// award — gets the strongest treatment on the whole screen (section ⑧'s
/// top tier), briefly covering the board so it can't be missed, before the
/// (already-animating, see [_ScoreChip]) score readout finishes counting up
/// on its own.
class _BonusBanner extends StatelessWidget {
  const _BonusBanner({required this.amount, required this.faction, super.key});
  final int amount;
  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final accent = GameColors.faction(faction == Faction.savior);
    return IgnorePointer(
      key: const Key('tutorial-bonus-banner'),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.elasticOut,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.6 + 0.4 * t.clamp(0.0, 1.0), child: child),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF241A08), accent.withValues(alpha: .28)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GameColors.gold, width: 3),
            boxShadow: [
              BoxShadow(color: GameColors.gold.withValues(alpha: .7), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BONUS',
                style: TextStyle(
                  color: GameColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              Text(
                '+$amount',
                style: const TextStyle(
                  color: GameColors.gold,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                '${faction.label}に加算！',
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section ⑦⑨: the dedicated screen shown once all steps are viewed —
/// keeps the previous three buttons, adds a confetti burst and a stronger
/// "you did it" line so finishing the lesson itself feels like an event.
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
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: ParticleBurstEffect(
                duration: Duration(milliseconds: 1800),
                colors: [
                  GameColors.gold,
                  GameColors.savior,
                  GameColors.executor,
                ],
                particleCount: 48,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: GameColors.gold,
                    size: 64,
                  ),
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
                  const SizedBox(height: 6),
                  const Text(
                    '基本ルールを習得しました！準備完了！',
                    key: Key('tutorial-complete-headline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: GameColors.savior,
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
        ],
      ),
    ),
  );
}
