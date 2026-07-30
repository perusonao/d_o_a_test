import 'dart:async';
import 'dart:math';

import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/promo/models/promo_script.dart';
import 'package:dead_or_alive/features/nine_judges/promo/services/promo_audio.dart';
import 'package:flutter/foundation.dart';

/// The camera transform in effect at one instant — a pure snapshot
/// [PromoCameraView] renders, recomputed on every [PromoTimelineController]
/// tick. [elapsedSeconds] is carried along so the view can derive a
/// deterministic (never [Random]-based) shake waveform from it.
class PromoCameraState {
  const PromoCameraState({
    this.scale = 1,
    this.dx = 0,
    this.dy = 0,
    this.opacity = 1,
    this.shakeIntensity = 0,
    this.elapsedSeconds = 0,
  });

  final double scale;
  final double dx;
  final double dy;
  final double opacity;
  final double shakeIntensity;
  final double elapsedSeconds;
}

/// Drives one promo playthrough: advances a [PromoScript] against a real
/// (but otherwise ordinary) [NineJudgesController], firing scripted actions
/// via [NineJudgesController.performTutorialAction] — the same "bypass
/// human/CPU input gating, but still go through the production rules
/// engine" entry point the guided tutorial already uses — so nothing here
/// is a second rules implementation. Never touches [NineJudgesGameScreen]
/// or any other real-game widget; a caller supplies its own controller
/// instance dedicated to this promo session.
///
/// [advanceTo] is the pure core (no timers, no real waiting) — exactly what
/// a test calls directly to assert deterministic behavior at a given
/// elapsed time. [start] is the only piece that involves a real [Timer],
/// used solely by [PromoPlayerScreen].
class PromoTimelineController extends ChangeNotifier {
  PromoTimelineController({
    required this.controller,
    required this.script,
    this.audio = const NoopPromoAudio(),
  });

  final NineJudgesController controller;
  final PromoScript script;
  final PromoAudio audio;

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  final Set<PromoActionCue> _firedActions = {};
  final Set<PromoSfxCue> _firedSfx = {};
  bool _bgmStarted = false;
  bool _bgmStopped = false;

  String? activeCaption;
  PromoCameraState cameraState = const PromoCameraState();

  /// Whether [PromoScript.endCard] should be showing right now.
  bool showEndCard = false;

  bool get isRunning => _timer != null;

  /// Starts a real [Timer.periodic] advancing the timeline against actual
  /// wall-clock time. Idempotent — calling twice is a no-op.
  void start({Duration tickInterval = const Duration(milliseconds: 100)}) {
    if (_timer != null) return;
    _stopwatch
      ..reset()
      ..start();
    advanceTo(Duration.zero);
    _timer = Timer.periodic(tickInterval, (_) => advanceTo(_stopwatch.elapsed));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
  }

  /// The pure core: given an explicit elapsed time, fires every due
  /// scripted action (at most once each — see [_firedActions]), updates the
  /// active caption/camera state, and fires SFX cues. Deterministic and
  /// side-effect-free beyond mutating [controller]/[activeCaption]/
  /// [cameraState] — no [Random], no wall-clock reads — so calling it twice
  /// with the same [elapsed] is safe and calling it out of order in a test
  /// is meaningful.
  void advanceTo(Duration elapsed) {
    final seconds = elapsed.inMilliseconds / 1000;
    if (controller.awaitingConfirmationReveal) {
      controller.confirmConfirmationReveal();
    }
    _updateCaption(seconds);
    _updateCamera(seconds);
    _fireSfx(seconds);
    // A hit-stop pauses game *progression* only — captions/camera above
    // keep advancing normally so a caption can still land during the beat.
    final hitStopped = script.hitStops.any((cue) => cue.isActiveAt(seconds));
    if (!hitStopped) _fireDueActions(seconds);
    final endCard = script.endCard;
    showEndCard = endCard != null && seconds >= endCard.at;
    final bgm = script.bgm;
    if (bgm != null && !_bgmStarted) {
      audio.playBgm(bgm.track);
      _bgmStarted = true;
    }
    if (bgm?.fadeOutAt != null && !_bgmStopped && seconds >= bgm!.fadeOutAt!) {
      audio.stopBgm(fadeOut: const Duration(seconds: 1));
      _bgmStopped = true;
    }
    notifyListeners();
  }

  void _updateCaption(double seconds) {
    for (final cue in script.captions) {
      if (cue.isActiveAt(seconds)) {
        activeCaption = cue.text;
        return;
      }
    }
    activeCaption = null;
  }

  void _updateCamera(double seconds) {
    PromoCameraCue? current;
    for (final cue in script.camera) {
      if (seconds >= cue.time) {
        current = cue;
      } else {
        break;
      }
    }
    if (current == null) {
      cameraState = PromoCameraState(elapsedSeconds: seconds);
      return;
    }
    final progress = ((seconds - current.time) / current.duration).clamp(
      0.0,
      1.0,
    );
    cameraState = switch (current.type) {
      PromoCameraEffectType.zoom => PromoCameraState(
        scale: 1 + ((current.scale ?? 1) - 1) * progress,
        elapsedSeconds: seconds,
      ),
      PromoCameraEffectType.pan => PromoCameraState(
        dx: (current.dx ?? 0) * progress,
        dy: (current.dy ?? 0) * progress,
        elapsedSeconds: seconds,
      ),
      PromoCameraEffectType.fade => PromoCameraState(
        opacity: 1 + ((current.opacity ?? 1) - 1) * progress,
        elapsedSeconds: seconds,
      ),
      PromoCameraEffectType.shake => PromoCameraState(
        shakeIntensity: progress < 1 ? (current.intensity ?? 1) : 0,
        elapsedSeconds: seconds,
      ),
    };
  }

  void _fireSfx(double seconds) {
    for (final cue in script.sfx) {
      if (!_firedSfx.contains(cue) && seconds >= cue.time) {
        _firedSfx.add(cue);
        audio.playSfx(cue.sound);
      }
    }
  }

  void _fireDueActions(double seconds) {
    for (final cue in script.actions) {
      if (_firedActions.contains(cue) || seconds < cue.time) continue;
      _firedActions.add(cue);
      _executeAction(cue);
    }
  }

  void _executeAction(PromoActionCue cue) {
    final actionType = cue.actionType;
    // 'showBoard' and any unrecognized action name are markers only — a
    // live recording should never crash over an unknown/no-op beat.
    if (actionType == null) return;
    final index = controller.board.indexWhere(
      (slot) => slot.person.id == cue.target,
    );
    if (index < 0) return;
    controller.performTutorialAction(actionType, index);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
