import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class OnlineActionRequest {
  const OnlineActionRequest({
    required this.actorUid,
    required this.actionIndex,
    required this.action,
    required this.targetIndex,
    required this.clientRevision,
  });

  final String actorUid;
  final int actionIndex;
  final ActionType action;
  final int targetIndex;
  final int clientRevision;
}

class OnlineTurnGate {
  const OnlineTurnGate({
    required this.currentTurnUid,
    required this.revision,
    required this.acceptedActionIndexes,
  });

  final String currentTurnUid;
  final int revision;
  final Set<int> acceptedActionIndexes;

  OnlineTurnGate accept(OnlineActionRequest request, String nextUid) {
    if (request.actorUid != currentTurnUid) {
      throw StateError('相手の手番です');
    }
    if (request.clientRevision != revision) {
      throw StateError('盤面が更新されています');
    }
    if (acceptedActionIndexes.contains(request.actionIndex)) {
      throw StateError('同じ手番の行動は送信済みです');
    }
    return OnlineTurnGate(
      currentTurnUid: nextUid,
      revision: revision + 1,
      acceptedActionIndexes: {...acceptedActionIndexes, request.actionIndex},
    );
  }
}

class OnlinePrivateKnowledge {
  const OnlinePrivateKnowledge({this.attributes = const {}, this.currentBonus});

  final Map<int, PersonAttribute> attributes;
  final int? currentBonus;
}

class OnlinePlayerView {
  const OnlinePlayerView({
    required this.knownAttributes,
    required this.visibleBonus,
  });

  final Map<int, PersonAttribute> knownAttributes;
  final int? visibleBonus;

  factory OnlinePlayerView.fromPrivate(OnlinePrivateKnowledge own) =>
      OnlinePlayerView(
        knownAttributes: Map.unmodifiable(own.attributes),
        visibleBonus: own.currentBonus,
      );
}
