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

/// Which continuous camera transform a [PromoCameraCue] drives. Zoom/pan/
/// fade/shake are implemented today (see [PromoCameraState]); hit-stop and
/// slow-motion are Phase 2 (see `PromoEffects`).
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

/// The full promo script — deliberately one JSON document (not four
/// separate files) so "シナリオを変更するだけで別動画が作れる" means
/// editing exactly one asset. Every list defaults to empty and [bgm] is
/// optional, so a minimal script can be just `{"actions": [...]}`.
class PromoScript {
  const PromoScript({
    required this.actions,
    this.captions = const [],
    this.sfx = const [],
    this.camera = const [],
    this.bgm,
  });

  final List<PromoActionCue> actions;
  final List<PromoCaptionCue> captions;
  final List<PromoSfxCue> sfx;
  final List<PromoCameraCue> camera;
  final PromoBgmCue? bgm;

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
    bgm: json['bgm'] != null
        ? PromoBgmCue.fromJson(json['bgm']! as Map<String, Object?>)
        : null,
  );

  factory PromoScript.fromJsonString(String source) =>
      PromoScript.fromJson(jsonDecode(source) as Map<String, Object?>);
}
