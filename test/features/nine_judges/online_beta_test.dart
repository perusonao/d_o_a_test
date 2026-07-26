import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/online/online_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('online turn gate', () {
    const valid = OnlineActionRequest(
      actorUid: 'host',
      actionIndex: 1,
      action: ActionType.eye,
      targetIndex: 4,
      clientRevision: 3,
    );
    const gate = OnlineTurnGate(
      currentTurnUid: 'host',
      revision: 3,
      acceptedActionIndexes: {},
    );

    test('accepts exactly the current player and revision', () {
      final next = gate.accept(valid, 'guest');
      expect(next.currentTurnUid, 'guest');
      expect(next.revision, 4);
      expect(next.acceptedActionIndexes, contains(1));
    });

    test('rejects opponent turn, stale revision and duplicate action', () {
      expect(
        () => gate.accept(
          const OnlineActionRequest(
            actorUid: 'guest',
            actionIndex: 1,
            action: ActionType.eye,
            targetIndex: 4,
            clientRevision: 3,
          ),
          'host',
        ),
        throwsStateError,
      );
      expect(
        () => gate.accept(
          const OnlineActionRequest(
            actorUid: 'host',
            actionIndex: 1,
            action: ActionType.eye,
            targetIndex: 4,
            clientRevision: 2,
          ),
          'guest',
        ),
        throwsStateError,
      );
      expect(
        () => const OnlineTurnGate(
          currentTurnUid: 'host',
          revision: 3,
          acceptedActionIndexes: {1},
        ).accept(valid, 'guest'),
        throwsStateError,
      );
    });
  });

  test('player view contains only the supplied private knowledge', () {
    const own = OnlinePrivateKnowledge(
      attributes: {6: PersonAttribute.good},
      currentBonus: 8,
    );
    const opponent = OnlinePrivateKnowledge(
      attributes: {0: PersonAttribute.evil},
      currentBonus: 3,
    );

    final view = OnlinePlayerView.fromPrivate(own);

    expect(view.knownAttributes, {6: PersonAttribute.good});
    expect(view.knownAttributes, isNot(containsPair(0, PersonAttribute.evil)));
    expect(view.visibleBonus, 8);
    expect(view.visibleBonus, isNot(opponent.currentBonus));
  });
}
