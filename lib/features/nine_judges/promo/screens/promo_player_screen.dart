import 'dart:async';

import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/promo/controllers/promo_timeline.dart';
import 'package:dead_or_alive/features/nine_judges/promo/models/promo_script.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_camera.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_caption.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_end_card.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_recording_frame.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_recording_start_overlay.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_safe_area_guide.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_score_banner.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Section 2's "🎬 プロモーション動画": a hidden route/admin-launched screen
/// that auto-plays a fixed-seed, JSON-scripted match end to end for SNS
/// promo recording. No randomness reaches the screen — [_seed] is a fixed
/// constant, never [DateTime.now()]-derived — so the exact same script
/// always produces the exact same footage. Never touches the real
/// [NineJudgesGameScreen]/[NineJudgesController] used by actual play: this
/// screen builds its own dedicated controller instance and its own widget
/// tree (reusing only the real, unmodified [BoardArea] for the board
/// itself), and carries no debug/FPS/admin chrome at all — there is simply
/// nothing here to hide, by construction, rather than a setting that hides
/// it.
///
/// Recording-mode layout: content sits inside a [PromoRecordingFrame] (a
/// centered, letterboxed 9:16 box) so a capture of any browser window shape
/// reads as a native phone-app recording rather than "a browser recording a
/// game". The board itself is auto-zoomed by [recordingZoom] to crop the
/// residual outer margin, and the whole thing starts gated behind a single
/// [PromoRecordingStartOverlay] tap — the safe-area guide stays visible
/// during that setup pause so the operator can line up their capture, then
/// disappears the instant recording actually starts, and nothing plays
/// until that tap so every take is free of dead air up front.
class PromoPlayerScreen extends StatefulWidget {
  const PromoPlayerScreen({
    this.scriptAssetPath = 'assets/promo/default_script.json',
    this.safePlatform = PromoSafePlatform.recording,
    this.showSafeAreaGuide = true,
    this.recordingZoom = 1.06,
    this.backgroundColor = Colors.black,
    super.key,
  });

  final String scriptAssetPath;
  final PromoSafePlatform safePlatform;
  final bool showSafeAreaGuide;

  /// How much to scale up just the board layer once recording starts, so
  /// the outer edge of the 3x3 grid bleeds slightly past the frame instead
  /// of leaving a visible margin. 1.05-1.10 per the "スマホアプリを録画した
  /// ような見た目" brief — kept well short of clipping into card content.
  final double recordingZoom;

  /// The frame's letterbox/background color — black by default, but a
  /// brand color works too (see [PromoRecordingFrame]).
  final Color backgroundColor;

  /// Fixed on purpose — never [Random]/[DateTime.now()]-derived (see the
  /// "乱数は禁止" requirement) — so the board's shuffle is identical on
  /// every recording. Any fixed integer works; this one is arbitrary. Public
  /// so a test can construct the exact same [NineJudgesController] this
  /// screen uses and verify a script against it directly.
  static const seed = 913_205;

  @override
  State<PromoPlayerScreen> createState() => _PromoPlayerScreenState();
}

class _PromoPlayerScreenState extends State<PromoPlayerScreen> {
  late final NineJudgesController _controller;
  PromoTimelineController? _timeline;
  String? _error;

  /// True only after the operator taps [PromoRecordingStartOverlay] — the
  /// script is loaded well before this (so the board is already sitting on
  /// its first frame the instant the button appears), but
  /// [PromoTimelineController.start] itself is deliberately deferred until
  /// then so no take ever has dead air at the front.
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = NineJudgesController(
      seed: PromoPlayerScreen.seed,
      settings: const NineJudgesGameSettings(
        mode: GameMode.cpu,
        skipCpuDelays: true,
      ),
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final source = await rootBundle.loadString(
        widget.scriptAssetPath,
        cache: false,
      );
      final script = PromoScript.fromJsonString(source);
      final timeline = PromoTimelineController(
        controller: _controller,
        script: script,
      )..addListener(_onTimelineTick);
      if (!mounted) {
        timeline.dispose();
        return;
      }
      setState(() => _timeline = timeline);
    } catch (exception) {
      if (mounted) {
        setState(
          () => _error = '${widget.scriptAssetPath} の読み込みに失敗しました: $exception',
        );
      }
    }
  }

  void _beginRecording() {
    setState(() => _started = true);
    _timeline?.start();
  }

  void _onTimelineTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timeline?.removeListener(_onTimelineTick);
    _timeline?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              key: const Key('promo-error'),
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final timeline = _timeline;
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        child: PromoRecordingFrame(
          backgroundColor: widget.backgroundColor,
          child: Stack(
            key: const Key('promo-player-stack'),
            // StackFit.expand: the board layer and the overlays above it
            // must all fill the frame from the incoming constraints — with
            // the default StackFit.loose, an overlay that currently has
            // nothing to show (e.g. no active caption, rendered as a
            // zero-size SizedBox.shrink) would otherwise make the *Stack
            // itself* size down to fit its smallest non-positioned child,
            // collapsing the board underneath to zero along with it.
            fit: StackFit.expand,
            children: [
              // No outer padding and a slight zoom baked in here — the
              // recording layout's whole point is to leave no visible
              // margin/frame around the board itself. Only this board layer
              // is scaled (never the caption/guide/banner/end-card layers
              // above it), so overlay text stays exactly where the safe-area
              // fractions place it.
              ClipRect(
                child: Transform.scale(
                  scale: widget.recordingZoom,
                  child: PromoCameraView(
                    state: timeline?.cameraState ?? const PromoCameraState(),
                    child: IgnorePointer(
                      child: BoardArea(
                        controller: _controller,
                        onTargetTap: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
              // The guide is a setup aid only — it disappears the instant
              // recording actually starts so it never bakes into a take.
              PromoSafeAreaGuide(
                platform: widget.safePlatform,
                visible: widget.showSafeAreaGuide && !_started,
              ),
              PromoScoreBanner(controller: _controller),
              PromoCaptionOverlay(text: timeline?.activeCaption),
              if (timeline?.showEndCard ?? false)
                PromoEndCard(cue: timeline!.script.endCard!),
              if (timeline != null && !_started)
                PromoRecordingStartOverlay(onStart: _beginRecording),
            ],
          ),
        ),
      ),
    );
  }
}
