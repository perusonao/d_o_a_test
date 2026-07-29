// Public constructor params are intentionally named without the leading
// underscore their backing fields use, mirroring
// FirebasePlaytestRepository's existing injectable-constructor pattern.
// ignore_for_file: prefer_initializing_formals
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_bootstrap.dart';

/// Records, once per Firebase Auth identity, that this device has completed
/// the tutorial — a durable, cross-device counter distinct from
/// [ExternalTestProfile.markTutorialCompleted] (device-local only, never
/// leaves the browser) and from `GameSession.completedTutorial` (only ever
/// visible if that tester goes on to submit an actual playtest). The admin
/// dashboard's KPI tab reads this collection's size via a server-side
/// `count()` aggregation (see AdminPlaytestRepository.fetchTutorialCompletionCount)
/// so "how many users have completed the tutorial" is answerable without
/// requiring every completer to have also played and submitted a game.
class TutorialCompletionRepository {
  const TutorialCompletionRepository({
    FirebaseFirestore? firestore,
    String? uidOverride,
    bool? availableOverride,
  }) : _firestore = firestore,
       _uidOverride = uidOverride,
       _availableOverride = availableOverride;

  final FirebaseFirestore? _firestore;
  final String? _uidOverride;
  final bool? _availableOverride;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  bool get _available => _availableOverride ?? FirebaseBootstrap.available;
  String? get _uid => _uidOverride ?? FirebaseBootstrap.uid;

  /// Best-effort: swallows any failure (offline, Firebase not configured,
  /// permission denied) exactly like the rest of this app's optional
  /// telemetry — the tutorial itself must never fail or block on this.
  /// Idempotent (`merge: true` on a doc keyed by uid), so completing the
  /// tutorial again on the same device never inflates the admin-visible
  /// count.
  Future<void> recordCompletion({required String testerId}) async {
    final uid = _uid;
    if (!_available || uid == null) return;
    try {
      await _db.collection('tutorialCompletions').doc(uid).set({
        'testerId': testerId,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort telemetry only.
    }
  }
}
