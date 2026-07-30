import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/promo/controllers/promo_timeline.dart';
import 'package:dead_or_alive/features/nine_judges/promo/models/promo_script.dart';
import 'package:dead_or_alive/features/nine_judges/promo/services/promo_audio.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAudio implements PromoAudio {
  _RecordingAudio(this.calls);
  final List<String> calls;

  @override
  void playSfx(String name) => calls.add('sfx:$name');

  @override
  void playBgm(String track) => calls.add('bgm:$track');

  @override
  void stopBgm({Duration fadeOut = Duration.zero}) => calls.add('stopBgm');
}

void main() {
  test(
    'advanceTo fires a due scripted action exactly once via performTutorialAction',
    () {
      final controller = NineJudgesController(
        seed: 42,
        settings: const NineJudgesGameSettings(),
      );
      final targetId = controller.board[0].person.id;
      final script = PromoScript(
        actions: [
          const PromoActionCue(time: 0, action: 'showBoard'),
          PromoActionCue(time: 1, action: 'life', target: targetId),
        ],
      );
      final timeline = PromoTimelineController(
        controller: controller,
        script: script,
      );

      timeline.advanceTo(Duration.zero);
      expect(controller.board[0].person.verdictActionCount, 0);

      timeline.advanceTo(const Duration(seconds: 1));
      expect(controller.board[0].person.verdictActionCount, 1);

      // Advancing again later must not re-fire the same cue.
      timeline.advanceTo(const Duration(seconds: 2));
      expect(controller.board[0].person.verdictActionCount, 1);
    },
  );

  test('an unknown target id is skipped rather than crashing', () {
    final controller = NineJudgesController(
      seed: 7,
      settings: const NineJudgesGameSettings(),
    );
    final script = PromoScript(
      actions: const [
        PromoActionCue(time: 0, action: 'life', target: 'no-such-person'),
      ],
    );
    final timeline = PromoTimelineController(
      controller: controller,
      script: script,
    );
    expect(() => timeline.advanceTo(Duration.zero), returnsNormally);
  });

  test('caption and camera state respond to elapsed time', () {
    final controller = NineJudgesController(
      seed: 1,
      settings: const NineJudgesGameSettings(),
    );
    final script = PromoScript(
      actions: const [],
      captions: const [PromoCaptionCue(start: 0, end: 2, text: 'hello')],
      camera: const [
        PromoCameraCue(
          time: 0,
          type: PromoCameraEffectType.zoom,
          scale: 1.2,
          duration: 1,
        ),
      ],
    );
    final timeline = PromoTimelineController(
      controller: controller,
      script: script,
    );

    timeline.advanceTo(Duration.zero);
    expect(timeline.activeCaption, 'hello');
    expect(timeline.cameraState.scale, closeTo(1.0, 0.001));

    timeline.advanceTo(const Duration(milliseconds: 500));
    expect(timeline.cameraState.scale, closeTo(1.1, 0.05));

    timeline.advanceTo(const Duration(seconds: 3));
    expect(timeline.activeCaption, isNull);
    expect(timeline.cameraState.scale, closeTo(1.2, 0.001));
  });

  test('sfx/bgm cues fire via PromoAudio exactly once each', () {
    final calls = <String>[];
    final audio = _RecordingAudio(calls);
    final controller = NineJudgesController(
      seed: 2,
      settings: const NineJudgesGameSettings(),
    );
    final script = PromoScript(
      actions: const [],
      sfx: const [PromoSfxCue(time: 1, sound: 'boop')],
      bgm: const PromoBgmCue(track: 'theme', fadeOutAt: 2),
    );
    final timeline = PromoTimelineController(
      controller: controller,
      script: script,
      audio: audio,
    );

    timeline.advanceTo(Duration.zero);
    expect(calls, contains('bgm:theme'));

    timeline.advanceTo(const Duration(seconds: 1));
    expect(calls, contains('sfx:boop'));

    timeline.advanceTo(const Duration(seconds: 2));
    expect(calls, contains('stopBgm'));

    timeline.advanceTo(const Duration(seconds: 3));
    expect(calls.where((c) => c == 'sfx:boop').length, 1);
    expect(calls.where((c) => c == 'stopBgm').length, 1);
  });
}
