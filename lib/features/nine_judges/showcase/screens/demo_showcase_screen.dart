import 'dart:async';

import 'package:dead_or_alive/features/nine_judges/characters/character_intro_overlay.dart';
import 'package:dead_or_alive/features/nine_judges/characters/result_character_overlay.dart';
import 'package:dead_or_alive/features/nine_judges/characters/special_verdict_overlay.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/models/showcase_event.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/widgets/recruitment_card_view.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/widgets/result_and_rating_view.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/widgets/showcase_effects.dart';
import 'package:dead_or_alive/features/nine_judges/showcase/widgets/title_splash_view.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_area.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';

enum _Phase {
  intro,
  characterIntro,
  board,
  resultCharacter,
  result,
  rating,
  recruitment,
}

/// Section ⑧: a hidden, recording-only route (never linked from any normal
/// player screen — reached only by typing `#/showcase` directly, matching
/// how `/admin` is hidden). Auto-plays a **fixed-seed, deterministic**
/// CPU-vs-CPU match end to end via [NineJudgesController.performAutoAction]
/// (added solely for this screen — see game_controller.dart) so the exact
/// same sequence reproduces every time it's recorded: title(2.0s) +
/// catch-copy(0.8s) + character-intro(2.0s) + board(~10.9s) +
/// result-character(3.0s) + result(1.8s) + rating(1.5s) + recruitment(2.5s)
/// ≈ 24.5s total. Originally tuned to ~19.5s for section 8's "20秒以内"
/// recruitment-clip target; the character-intro and result-character beats
/// (the real [CharacterIntroOverlay]/[ResultCharacterOverlay]/
/// [SpecialVerdictOverlay] widgets, not mockups) push it over that, an
/// explicit tradeoff so this screen can also demo/record those moments
/// properly. Layers the section ③-⑦ visual effects on top of the real
/// board/card widgets so the footage shows the actual product, not a
/// mockup.
///
/// Game rules, CPU decision logic, and rulesVersion are untouched: this
/// screen only decides *who* is allowed to trigger the same, unmodified CPU
/// decision function each turn.
class DemoShowcaseScreen extends StatefulWidget {
  const DemoShowcaseScreen({
    this.gameUrl = 'https://perusonao.github.io/nine-verdicts/',
    this.onEvent,
    this.loop = true,
    super.key,
  });

  final String gameUrl;

  /// Fires at each named beat (section 10) — for a future video edit to
  /// hang BGM/SE cues off, without needing another code change.
  final ValueChanged<ShowcaseEvent>? onEvent;

  /// Whether to restart from the title screen after the recruitment card,
  /// so a screen recorder doesn't have to manually replay it.
  final bool loop;

  /// Fixed so every recording of this screen is byte-for-byte the same
  /// match (section 8: "CPUの行動も固定してください"). Chosen from a short
  /// seed survey (see test/features/nine_judges/showcase/
  /// auto_action_smoke_test.dart) for an early EYE, a mid-game JUDGE, a
  /// reversal, and a clear (but not lopsided) savior win.
  static const demoSeed = 4;

  /// How many actions the fixed [demoSeed] match takes in total — used only
  /// to pace the non-spotlight turns so the whole board phase fits its time
  /// budget; the loop itself still runs until [NineJudgesController.
  /// isFinished], so nothing breaks if this ever drifts.
  static const _expectedActionCount = 24;

  @override
  State<DemoShowcaseScreen> createState() => _DemoShowcaseScreenState();
}

class _DemoShowcaseScreenState extends State<DemoShowcaseScreen> {
  late NineJudgesController _controller = _newController();
  _Phase _phase = _Phase.intro;
  Widget? _activeEffect;
  bool _shake = false;
  bool _disposed = false;
  bool _eyeSpotlightShown = false;
  bool _judgeSpotlightShown = false;
  bool _reverseSpotlightShown = false;

  // Originally tuned to ~19.5s for the "20秒以内" recruitment-video target.
  // Adding the character-intro and result-character beats (below) pushes
  // the full sequence to ~24.5s — an explicit tradeoff to properly show off
  // those two new moments when this screen is used to demo/record them,
  // rather than trimming them down to protect the original recruitment-clip
  // length.
  static const _titleDuration = Duration(milliseconds: 2000);
  static const _catchCopyDuration = Duration(milliseconds: 800);
  static const _characterIntroDuration = Duration(milliseconds: 2000);
  static const _boardBudget = Duration(milliseconds: 10900);
  static const _eyeSpotlight = Duration(milliseconds: 1500);
  static const _judgeSpotlight = Duration(milliseconds: 1800);
  static const _reverseSpotlight = Duration(milliseconds: 1300);
  static const _resultCharacterDuration = Duration(milliseconds: 3000);
  static const _resultDuration = Duration(milliseconds: 1800);
  static const _ratingDuration = Duration(milliseconds: 1500);
  static const _recruitmentDuration = Duration(milliseconds: 2500);

  static const _catchCopies = ['9人の運命を裁け。', '善人を救い、悪人を裁け。'];

  NineJudgesController _newController() => NineJudgesController(
    seed: DemoShowcaseScreen.demoSeed,
    settings: const NineJudgesGameSettings(
      mode: GameMode.cpu,
      skipCpuDelays: true,
    ),
  );

  void _fire(ShowcaseEvent event) => widget.onEvent?.call(event);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runIntro());
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runIntro() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.intro);
    _fire(ShowcaseEvent.titleShown);
    await Future<void>.delayed(_titleDuration);
    if (_disposed) return;
    _fire(ShowcaseEvent.catchCopyShown);
    await Future<void>.delayed(_catchCopyDuration);
    if (_disposed) return;
    await _runCharacterIntro();
  }

  /// The real [CharacterIntroOverlay], personalized as the savior (this
  /// fixed seed's eventual winner) so the demo reads as one coherent story:
  /// "you are the savior" → the match plays out → "victory".
  Future<void> _runCharacterIntro() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.characterIntro);
    _fire(ShowcaseEvent.characterIntroShown);
    await Future<void>.delayed(_characterIntroDuration);
    if (_disposed) return;
    await _runBoard();
  }

  Future<void> _runBoard() async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.board;
      _eyeSpotlightShown = false;
      _judgeSpotlightShown = false;
      _reverseSpotlightShown = false;
    });
    _fire(ShowcaseEvent.cardsPlaced);

    final spotlightMs =
        _eyeSpotlight.inMilliseconds +
        _judgeSpotlight.inMilliseconds +
        _reverseSpotlight.inMilliseconds;
    final regularCount =
        (DemoShowcaseScreen._expectedActionCount - 3).clamp(1, 999);
    final regularMs = ((_boardBudget.inMilliseconds - spotlightMs) / regularCount)
        .clamp(120, 700)
        .round();

    var iterations = 0;
    while (!_controller.isFinished && iterations < 500 && !_disposed) {
      iterations++;
      if (_controller.awaitingConfirmationReveal) {
        _controller.confirmConfirmationReveal();
        continue;
      }
      final beforeCount = _controller.session.actions.length;
      final decision = _controller.performAutoAction();
      if (decision == null) break;
      if (!mounted) return;
      setState(() {}); // re-render the board with the new state.

      final actions = _controller.session.actions;
      final GameActionLog? justPlayed = actions.length > beforeCount ? actions.last : null;
      final delay = await _effectForAction(justPlayed, regularMs);
      if (_disposed) return;
      await Future<void>.delayed(delay);
      if (mounted) setState(() => _activeEffect = null);
    }
    if (_disposed) return;
    await _runResultCharacter();
  }

  /// Returns how long to hold on this beat, and schedules whichever effect
  /// (section ③/④/⑨) matches [action] — the first EYE/JUDGE/reversal only;
  /// every other action gets a quick, uneffected flash so the ~20 turns fit
  /// the time budget.
  Future<Duration> _effectForAction(GameActionLog? action, int regularMs) async {
    if (action == null) return Duration(milliseconds: regularMs);
    final actionType = action.actionType;
    final wasReverse = action.wasReverseAction;

    if (actionType == 'eye' && !_eyeSpotlightShown) {
      _eyeSpotlightShown = true;
      _fire(ShowcaseEvent.eyeUsed);
      setState(
        () => _activeEffect = Stack(
          children: [
            const EyeRippleEffect(duration: _eyeSpotlight),
            EffectCaption(
              title: 'EYE',
              subtitle: '属性を確認',
              accent: GameColors.eye,
              duration: _eyeSpotlight,
            ),
          ],
        ),
      );
      return _eyeSpotlight;
    }
    if (actionType == 'specialVerdict' && !_judgeSpotlightShown) {
      _judgeSpotlightShown = true;
      _fire(ShowcaseEvent.judgeUsed);
      _fire(ShowcaseEvent.scoreAwarded);
      setState(() {
        _shake = true;
        // The real SpecialVerdictOverlay (see characters/), not a bespoke
        // mockup effect — this is exactly what a real SPECIAL VERDICT
        // confirmation looks like during actual play.
        _activeEffect = SpecialVerdictOverlay(
          actor: Faction.values.byName(action.faction),
          onDone: () {},
        );
      });
      Future<void>.delayed(
        _judgeSpotlight,
        () => mounted ? setState(() => _shake = false) : null,
      );
      return _judgeSpotlight;
    }
    if (wasReverse && !_reverseSpotlightShown) {
      _reverseSpotlightShown = true;
      _fire(ShowcaseEvent.reversalUsed);
      setState(
        () => _activeEffect = const EffectCaption(
          title: '逆転',
          subtitle: 'たった一度の切り札',
          accent: GameColors.death,
          duration: _reverseSpotlight,
        ),
      );
      return _reverseSpotlight;
    }
    return Duration(milliseconds: regularMs);
  }

  /// The real [ResultCharacterOverlay], shown once right as the match ends
  /// and before the existing result banner — matches the personalized
  /// savior intro with a savior-victory payoff (this seed always ends in a
  /// savior win, so `isVictory` is always true here).
  Future<void> _runResultCharacter() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.resultCharacter);
    _fire(ShowcaseEvent.resultCharacterShown);
    await Future<void>.delayed(_resultCharacterDuration);
    if (_disposed) return;
    await _runResult();
  }

  Future<void> _runResult() async {
    if (!mounted) return;
    final winner = _controller.score.winner;
    final isPlayerWin = winner == Faction.savior;
    setState(() => _phase = _Phase.result);
    _fire(isPlayerWin ? ShowcaseEvent.victory : ShowcaseEvent.defeat);
    await Future<void>.delayed(_resultDuration);
    if (_disposed) return;
    await _runRating();
  }

  Future<void> _runRating() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.rating);
    _fire(ShowcaseEvent.ratingShown);
    await Future<void>.delayed(_ratingDuration);
    if (_disposed) return;
    await _runRecruitment();
  }

  Future<void> _runRecruitment() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.recruitment);
    _fire(ShowcaseEvent.recruitmentShown);
    await Future<void>.delayed(_recruitmentDuration);
    if (_disposed || !widget.loop) return;
    _controller.dispose();
    _controller = _newController();
    await _runIntro();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF06070C),
    body: SafeArea(child: _body()),
  );

  Widget _body() {
    switch (_phase) {
      case _Phase.intro:
        return TitleSplashView(
          titleDuration: _titleDuration,
          catchCopyDuration: _catchCopyDuration,
          catchCopy: _catchCopies[DemoShowcaseScreen.demoSeed % _catchCopies.length],
        );
      case _Phase.characterIntro:
        return CharacterIntroOverlay(
          humanFaction: Faction.savior,
          onDone: () {},
        );
      case _Phase.board:
        return _boardLayer();
      case _Phase.resultCharacter:
        final winner = _controller.score.winner;
        return ResultCharacterOverlay(
          faction: winner ?? Faction.savior,
          message: winner == Faction.savior ? '希望は未来へ受け継がれる。' : '裁きは完遂された。',
          isVictory: true,
          onDone: () {},
        );
      case _Phase.result:
        final winner = _controller.score.winner;
        return ResultBannerView(
          winnerLabel: winner == Faction.savior ? '救済者の勝利' : '執行者の勝利',
          isPlayerWin: winner == Faction.savior,
          saviorScore: _controller.scores[Faction.savior]!,
          executorScore: _controller.scores[Faction.executor]!,
          duration: _resultDuration,
        );
      case _Phase.rating:
        return const RatingShowcaseView();
      case _Phase.recruitment:
        return RecruitmentCardView(gameUrl: widget.gameUrl);
    }
  }

  Widget _boardLayer() {
    Widget board = Column(
      children: [
        _header(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IgnorePointer(
              child: BoardArea(controller: _controller, onTargetTap: (_) {}),
            ),
          ),
        ),
      ],
    );
    if (_shake) board = JudgeShake(duration: _judgeSpotlight, child: board);
    return Stack(
      children: [
        Positioned.fill(child: board),
        if (_activeEffect != null) Positioned.fill(child: _activeEffect!),
      ],
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _factionScore('救済者', _controller.scores[Faction.savior]!, GameColors.savior),
        const Text(
          '9人の審判',
          style: TextStyle(color: GameColors.gold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        _factionScore('執行者', _controller.scores[Faction.executor]!, GameColors.executor),
      ],
    ),
  );

  Widget _factionScore(String label, int score, Color color) => Column(
    children: [
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      Text('$score', style: const TextStyle(color: Colors.white, fontSize: 18)),
    ],
  );
}
