import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';

/// One `playtests/{gameId}` Firestore document, parsed with
/// [GameSession.fromJson] (the authoritative schema — see
/// services/firebase_playtest_repository.dart's `send()` for exactly which
/// fields are written) plus the two fields that repository adds on top of
/// `session.toJson()` and that [GameSession] itself has no concept of:
/// `firebaseUid` (the Firebase Auth uid that submitted the log) and
/// `createdAt` (a server timestamp).
class PlaytestRecord {
  const PlaytestRecord({
    required this.session,
    required this.firebaseUid,
    required this.createdAt,
    this.actions,
  });

  final GameSession session;
  final String firebaseUid;
  final DateTime? createdAt;

  /// Populated only once section 12's lazy per-game fetch has run for this
  /// record's detail view; null beforehand (and never fetched on the
  /// dashboard/list screens).
  final List<GameActionLog>? actions;

  String get gameId => session.gameId;

  factory PlaytestRecord.fromFirestore(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    return PlaytestRecord(
      session: GameSession.fromJson(data),
      firebaseUid: data['firebaseUid'] as String? ?? '',
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : null,
    );
  }

  PlaytestRecord withActions(List<GameActionLog> fetchedActions) =>
      PlaytestRecord(
        session: session,
        firebaseUid: firebaseUid,
        createdAt: createdAt,
        actions: fetchedActions,
      );
}
