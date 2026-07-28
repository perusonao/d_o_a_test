// Public constructor params are intentionally named without the leading
// underscore their backing fields use, so callers in other libraries (tests)
// can pass them — prefer_initializing_formals doesn't apply here.
// ignore_for_file: prefer_initializing_formals
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebasePlaytestRepository {
  /// [firestore]/[uidOverride]/[availableOverride] are injectable (e.g. a
  /// `FakeFirebaseFirestore` plus a fixed uid in tests, see
  /// services/firebase_playtest_repository_test.dart) so this repository's
  /// document/collection structure — including enforcement of the real
  /// firestore.rules text — can be verified without a live Firebase project
  /// or a mocked FirebaseAuth. All default to the real
  /// [FirebaseFirestore.instance]/[FirebaseBootstrap] for production use.
  const FirebasePlaytestRepository({
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

  Future<bool> wasSent(String gameId) async =>
      (await SharedPreferences.getInstance()).getBool('sent.$gameId') ?? false;

  Future<void> send({
    required GameSession session,
    required Map<String, int> ratings,
    required String notes,
  }) async {
    final uid = _uid;
    if (!_available || uid == null) {
      throw StateError('Firebaseが未設定のため送信できません');
    }
    if (await wasSent(session.gameId)) return;
    final data = session.toJson();
    data.remove('actions');
    // `data['testerId']` is the persisted, cross-session anonymous id from
    // ExternalTestProfile (see services/external_test_profile.dart) — keep
    // it as-is rather than overwriting it with the Firebase Auth uid, which
    // is a separate identity and goes in its own field instead. firestore.rules
    // checks `firebaseUid` (not `testerId`) against `request.auth.uid`.
    await _db.collection('playtests').doc(session.gameId).set({
      ...data,
      'firebaseUid': uid,
      'ratings': ratings,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final batch = _db.batch();
    for (final action in session.actions) {
      batch.set(
        _db
            .collection('playtests')
            .doc(session.gameId)
            .collection('actions')
            .doc(action.actionIndex.toString().padLeft(3, '0')),
        action.toJson(),
      );
    }
    await batch.commit();
    await (await SharedPreferences.getInstance()).setBool(
      'sent.${session.gameId}',
      true,
    );
  }
}
