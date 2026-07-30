import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/promo/controllers/promo_timeline.dart';
import 'package:dead_or_alive/features/nine_judges/promo/models/promo_script.dart';
import 'package:dead_or_alive/features/nine_judges/promo/screens/promo_player_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Empirical check (not just "does JSON parse") that the bundled default
/// promo script actually plays out cleanly against the exact fixed seed
/// [PromoPlayerScreen] uses: every scripted action must be legal at the
/// moment it fires (a mismatch would silently no-op instead of crashing —
/// see [PromoTimelineController.performTutorialAction] usage — so this
/// test exists specifically to catch that silent case).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every action in assets/promo/default_script.json actually applies', () async {
    final source = await rootBundle.loadString(
      'assets/promo/default_script.json',
    );
    final script = PromoScript.fromJsonString(source);
    expect(script.actions, isNotEmpty);

    final controller = NineJudgesController(
      seed: PromoPlayerScreen.seed,
      settings: const NineJudgesGameSettings(
        mode: GameMode.cpu,
        skipCpuDelays: true,
      ),
    );
    final timeline = PromoTimelineController(
      controller: controller,
      script: script,
    );

    for (final cue in script.actions) {
      timeline.advanceTo(Duration(milliseconds: (cue.time * 1000).round()));
      final actionType = cue.actionType;
      if (actionType == null || cue.target == null) continue; // e.g. showBoard
      final index = controller.board.indexWhere(
        (slot) => slot.person.id == cue.target,
      );
      expect(
        index,
        greaterThanOrEqualTo(0),
        reason: '${cue.target} must exist on the board',
      );
      final person = controller.board[index].person;
      // If the scripted action actually applied, the target must show some
      // resulting effect: EYE reveals the attribute is now known, LIFE/
      // DEATH grows the verdict history, specialVerdict confirms outright.
      final applied = switch (actionType) {
        ActionType.eye =>
          controller.knowsAttribute(person, Faction.savior) ||
              controller.knowsAttribute(person, Faction.executor),
        ActionType.life ||
        ActionType.death => person.verdictActionCount > 0 || person.isConfirmed,
        ActionType.specialVerdict => person.isConfirmed,
      };
      expect(
        applied,
        isTrue,
        reason:
            '${cue.action} on ${cue.target} at t=${cue.time}s was not legal '
            'at that point in the fixed-seed match and silently no-opped — '
            'the default script needs a different target/timing for this '
            'seed.',
      );
    }
  });
}
