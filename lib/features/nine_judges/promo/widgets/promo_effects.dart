import 'package:dead_or_alive/features/nine_judges/promo/controllers/promo_timeline.dart';

/// Discrete, momentary effects distinct from [PromoCameraView]'s continuous
/// zoom/pan/fade/shake transforms. Phase 1 ships hit-stop and slow-motion
/// as documented no-ops: this class exists now so [PromoTimelineController]'s
/// dependency graph already matches the requested architecture
/// (`PromoPlayer → PromoTimeline → PromoScript/PromoCamera/PromoCaption/
/// PromoAudio/PromoEffects`) — filling these in later is additive, never a
/// restructuring of anything already built.
abstract final class PromoEffects {
  /// Not yet implemented (Phase 2) — briefly freezes playback for a hard
  /// hit beat.
  static void hitStop(PromoTimelineController timeline, Duration duration) {}

  /// Not yet implemented (Phase 2) — temporarily plays the timeline back at
  /// [rate] (e.g. `0.3` for a slow-motion beat).
  static void slowMotion(
    PromoTimelineController timeline,
    Duration duration,
    double rate,
  ) {}
}
