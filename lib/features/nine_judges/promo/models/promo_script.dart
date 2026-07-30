import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

/// One turn-level directive: either a marker (`showBoard`) or a specific
/// game action (`life`/`death`/`eye`/`specialVerdict`) forced onto a named
/// [target] person ([PersonCard.id], e.g. `'good-2'`) at [time] seconds
/// into the promo. IDs — not board indices — are used so a script keeps
/// working regardless of which slot that person's shuffle lands them on for
/// a given seed.
class PromoActionCue {
  const PromoActionCue({required this.time, required this.action, this.target});

  final double time;
  final String action;
  final String? target;

  /// `null` for `'showBoard'` (a no-op marker beat, useful for camera/
  /// caption cues that want a fixed timestamp with no game action) and for
  /// any unrecognized action name — [PromoTimelineController] silently
  /// skips those rather than crashing a live recording.
  ActionType? get actionType => switch (action) {
    'life' => ActionType.life,
    'death' => ActionType.death,
    'eye' => ActionType.eye,
    'specialVerdict' => ActionType.specialVerdict,
    _ => null,
  };

  factory PromoActionCue.fromJson(Map<String, Object?> json) => PromoActionCue(
    time: (json['time']! as num).toDouble(),
    action: json['action']! as String,
    target: json['target'] as String?,
  );
}

/// A caption shown for `[start, end)` seconds — overlaid on top of the
/// board, never altering it.
class PromoCaptionCue {
  const PromoCaptionCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final double start;
  final double end;
  final String text;

  bool isActiveAt(double seconds) => seconds >= start && seconds < end;

  factory PromoCaptionCue.fromJson(Map<String, Object?> json) =>
      PromoCaptionCue(
        start: (json['start']! as num).toDouble(),
        end: (json['end']! as num).toDouble(),
        text: json['text']! as String,
      );
}

class PromoSfxCue {
  const PromoSfxCue({required this.time, required this.sound});

  final double time;
  final String sound;

  factory PromoSfxCue.fromJson(Map<String, Object?> json) => PromoSfxCue(
    time: (json['time']! as num).toDouble(),
    sound: json['sound']! as String,
  );
}

class PromoBgmCue {
  const PromoBgmCue({required this.track, this.fadeOutAt});

  final String track;

  /// Seconds into the promo to start fading the BGM out, or `null` to let
  /// it play until [PromoTimelineController.stop].
  final double? fadeOutAt;

  factory PromoBgmCue.fromJson(Map<String, Object?> json) => PromoBgmCue(
    track: json['track']! as String,
    fadeOutAt: (json['fadeOutAt'] as num?)?.toDouble(),
  );
}

/// A brief pause in game *progression* only — no scripted action fires
/// while `(time, time+duration)` is active — so a dramatic beat (e.g. right
/// as SPECIAL VERDICT lands) gets an extra held frame. The lower bound is
/// exclusive on purpose: an action cue scheduled at exactly [time] (the
/// usual case — the hit-stop punctuates that very action) must still fire
/// on that tick, and only ticks *after* it are held. Captions and camera
/// cues keep advancing normally during it; pair it with a `zoom`/`shake`
/// camera cue at the same [time] for the punch-in look.
class PromoHitStopCue {
  const PromoHitStopCue({required this.time, required this.duration});

  final double time;
  final double duration;

  bool isActiveAt(double seconds) => seconds > time && seconds < time + duration;

  factory PromoHitStopCue.fromJson(Map<String, Object?> json) =>
      PromoHitStopCue(
        time: (json['time']! as num).toDouble(),
        duration: (json['duration']! as num).toDouble(),
      );
}

/// Which continuous camera transform a [PromoCameraCue] drives. Zoom/pan/
/// fade/shake are implemented today (see [PromoCameraState]); slow-motion
/// is Phase 2 (see `PromoEffects`) — hit-stop is [PromoHitStopCue] instead,
/// since it pauses game progression rather than transforming the camera.
enum PromoCameraEffectType { zoom, pan, fade, shake }

/// One camera move starting at [time] and easing linearly over [duration]
/// seconds, then holding until the next cue's window begins. Only the
/// field(s) relevant to [type] need be set in JSON; the rest default to a
/// no-op for that axis.
class PromoCameraCue {
  const PromoCameraCue({
    required this.time,
    required this.type,
    this.duration = 0.6,
    this.scale,
    this.dx,
    this.dy,
    this.opacity,
    this.intensity,
  });

  final double time;
  final PromoCameraEffectType type;
  final double duration;
  final double? scale;
  final double? dx;
  final double? dy;
  final double? opacity;
  final double? intensity;

  factory PromoCameraCue.fromJson(Map<String, Object?> json) => PromoCameraCue(
    time: (json['time']! as num).toDouble(),
    type: PromoCameraEffectType.values.byName(json['type']! as String),
    duration: (json['duration'] as num?)?.toDouble() ?? 0.6,
    scale: (json['scale'] as num?)?.toDouble(),
    dx: (json['dx'] as num?)?.toDouble(),
    dy: (json['dy'] as num?)?.toDouble(),
    opacity: (json['opacity'] as num?)?.toDouble(),
    intensity: (json['intensity'] as num?)?.toDouble(),
  );
}

/// The branded closing card — logo + "無料でプレイ" + a question-style CTA —
/// shown from [at] seconds onward (holds until the promo loops). A full
/// overlay is the one deliberate exception to "never hide the board": by
/// this point the gameplay demonstration is over and this is explicitly a
/// branded end card, same as any short-form video's outro.
class PromoEndCardCue {
  const PromoEndCardCue({
    required this.at,
    this.logoAsset = 'assets/branding/menu_hero.png',
    this.freeToPlayText = '無料でプレイ',
    this.ctaText = 'あなたなら誰を裁く？',
  });

  final double at;
  final String logoAsset;
  final String freeToPlayText;
  final String ctaText;

  factory PromoEndCardCue.fromJson(Map<String, Object?> json) =>
      PromoEndCardCue(
        at: (json['at']! as num).toDouble(),
        logoAsset: json['logoAsset'] as String? ?? 'assets/branding/menu_hero.png',
        freeToPlayText: json['freeToPlayText'] as String? ?? '無料でプレイ',
        ctaText: json['ctaText'] as String? ?? 'あなたなら誰を裁く？',
      );
}

/// The full promo script — deliberately one JSON document (not four
/// separate files) so "シナリオを変更するだけで別動画が作れる" means
/// editing exactly one asset. Every list defaults to empty and [bgm]/
/// [endCard] are optional, so a minimal script can be just
/// `{"actions": [...]}`.
class PromoScript {
  const PromoScript({
    required this.actions,
    this.captions = const [],
    this.sfx = const [],
    this.camera = const [],
    this.hitStops = const [],
    this.bgm,
    this.endCard,
  });

  final List<PromoActionCue> actions;
  final List<PromoCaptionCue> captions;
  final List<PromoSfxCue> sfx;
  final List<PromoCameraCue> camera;
  final List<PromoHitStopCue> hitStops;
  final PromoBgmCue? bgm;
  final PromoEndCardCue? endCard;

  factory PromoScript.fromJson(Map<String, Object?> json) => PromoScript(
    actions:
        [
          for (final entry in (json['actions'] as List?) ?? const [])
            PromoActionCue.fromJson(entry as Map<String, Object?>),
        ]..sort((a, b) => a.time.compareTo(b.time)),
    captions: [
      for (final entry in (json['captions'] as List?) ?? const [])
        PromoCaptionCue.fromJson(entry as Map<String, Object?>),
    ],
    sfx: [
      for (final entry in (json['sfx'] as List?) ?? const [])
        PromoSfxCue.fromJson(entry as Map<String, Object?>),
    ],
    camera:
        [
          for (final entry in (json['camera'] as List?) ?? const [])
            PromoCameraCue.fromJson(entry as Map<String, Object?>),
        ]..sort((a, b) => a.time.compareTo(b.time)),
    hitStops: [
      for (final entry in (json['hitStops'] as List?) ?? const [])
        PromoHitStopCue.fromJson(entry as Map<String, Object?>),
    ],
    bgm: json['bgm'] != null
        ? PromoBgmCue.fromJson(json['bgm']! as Map<String, Object?>)
        : null,
    endCard: json['endCard'] != null
        ? PromoEndCardCue.fromJson(json['endCard']! as Map<String, Object?>)
        : null,
  );

  factory PromoScript.fromJsonString(String source) =>
      PromoScript.fromJson(jsonDecode(source) as Map<String, Object?>);
}
