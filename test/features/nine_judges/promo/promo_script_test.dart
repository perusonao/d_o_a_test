import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/promo/models/promo_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses actions/captions/sfx/bgm/camera from JSON, sorted by time', () {
    const source = '''
    {
      "actions": [
        {"time": 7, "action": "specialVerdict", "target": "evil-1"},
        {"time": 0, "action": "showBoard"},
        {"time": 2, "action": "life", "target": "good-2"}
      ],
      "captions": [
        {"start": 3, "end": 5, "text": "正体は分からない。"}
      ],
      "sfx": [
        {"time": 2.1, "sound": "card_select"}
      ],
      "bgm": {"track": "promo_theme", "fadeOutAt": 8.5},
      "camera": [
        {"time": 4, "type": "pan", "dx": -0.3, "duration": 1.0},
        {"time": 2, "type": "zoom", "scale": 1.1, "duration": 1.2}
      ]
    }
    ''';
    final script = PromoScript.fromJsonString(source);

    expect(script.actions.map((a) => a.time).toList(), [0, 2, 7]);
    expect(script.actions[1].actionType, ActionType.life);
    expect(script.actions[1].target, 'good-2');
    expect(script.actions[0].actionType, isNull); // showBoard is a marker
    expect(script.captions.single.text, '正体は分からない。');
    expect(script.captions.single.isActiveAt(4), isTrue);
    expect(script.captions.single.isActiveAt(5), isFalse); // end exclusive
    expect(script.sfx.single.sound, 'card_select');
    expect(script.bgm!.track, 'promo_theme');
    expect(script.bgm!.fadeOutAt, 8.5);
    expect(script.camera.map((c) => c.time).toList(), [2, 4]); // sorted
  });

  test('missing optional sections default to empty/null', () {
    final script = PromoScript.fromJsonString('{"actions": []}');
    expect(script.actions, isEmpty);
    expect(script.captions, isEmpty);
    expect(script.sfx, isEmpty);
    expect(script.camera, isEmpty);
    expect(script.bgm, isNull);
  });
}
