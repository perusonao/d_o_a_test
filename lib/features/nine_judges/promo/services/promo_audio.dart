/// JSON-driven SFX/BGM trigger hooks for [PromoTimelineController]. Phase 1
/// ships no real audio backend or asset files — the repository has neither
/// today (confirmed before starting this feature) — only [NoopPromoAudio],
/// so `promo_script.json`'s `sfx`/`bgm` sections are already fully parsed
/// and fired at the right times, ready to wire to a real player later
/// without touching [PromoTimelineController] at all.
abstract class PromoAudio {
  void playSfx(String name);
  void playBgm(String track);
  void stopBgm({Duration fadeOut = Duration.zero});
}

class NoopPromoAudio implements PromoAudio {
  const NoopPromoAudio();

  @override
  void playSfx(String name) {}

  @override
  void playBgm(String track) {}

  @override
  void stopBgm({Duration fadeOut = Duration.zero}) {}
}
