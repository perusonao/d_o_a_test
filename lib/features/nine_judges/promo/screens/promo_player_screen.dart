import 'dart:async';

import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/promo/controllers/promo_timeline.dart';
import 'package:dead_or_alive/features/nine_judges/promo/models/promo_script.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_camera.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_caption.dart';
import 'package:dead_or_alive/features/nine_judges/promo/widgets/promo_end_card.dart';
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
class PromoPlayerScreen extends StatefulWidget {
  const PromoPlayerScreen({
    this.scriptAssetPath = 'assets/promo/default_script.json',
    this.safePlatform = PromoSafePlatform.tiktok,
    this.showSafeAreaGuide = true,
    super.key,
  });

  final String scriptAssetPath;
  final PromoSafePlatform safePlatform;
  final bool showSafeAreaGuide;

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
      final source = await rootBundle.loadString(widget.scriptAssetPath);
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
      timeline.start();
    } catch (exception) {
      if (mounted) {
        setState(
          () => _error = '${widget.scriptAssetPath} の読み込みに失敗しました: $exception',
        );
      }
    }
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          key: const Key('promo-player-stack'),
          // StackFit.expand: the board layer and the two overlays above it
          // must all fill the screen from the incoming constraints — with
          // the default StackFit.loose, an overlay that currently has
          // nothing to show (e.g. no active caption, rendered as a
          // zero-size SizedBox.shrink) would otherwise make the *Stack
          // itself* size down to fit its smallest non-positioned child,
          // collapsing the board underneath to zero along with it.
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
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
            PromoSafeAreaGuide(
              platform: widget.safePlatform,
              visible: widget.showSafeAreaGuide,
            ),
            PromoScoreBanner(controller: _controller),
            PromoCaptionOverlay(text: timeline?.activeCaption),
            if (timeline?.showEndCard ?? false)
              PromoEndCard(cue: timeline!.script.endCard!),
          ],
        ),
      ),
    );
  }
}
