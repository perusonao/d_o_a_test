// Public constructor params are intentionally named without the leading
// underscore their backing fields use, mirroring
// TutorialCompletionRepository's existing injectable-constructor pattern.
// ignore_for_file: prefer_initializing_formals
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_bootstrap.dart';

/// Best-effort, durable, cross-device raw counters for two numbers nothing
/// else in this app currently answers: "how many times has the site
/// actually been loaded" and "how many times has a real game actually
/// started" — both counted on *every* occurrence, deliberately never
/// deduplicated by device/tester (that's what [TutorialCompletionRepository]'s
/// per-uid-doc pattern is for; `playtests` only reflects games whose player
/// went on to submit end-of-game feedback, which undercounts real play).
///
/// One `appStats/{visits|plays}` doc per counter holds the all-time total;
/// a `days/{yyyy-MM-dd}` subcollection under each holds the same count
/// bucketed by calendar day (JST, since the admin dashboard viewing this is
/// Japan-facing) so the admin dashboard can show a daily trend, not just a
/// lifetime sum. Every doc holds a single `count` field incremented
/// atomically via [FieldValue.increment] — see firestore.rules' `appStats`
/// match block for the exact-plus-one security rule that lets every
/// legitimate visit/play through while still rejecting a client trying to
/// set/reset the count to an arbitrary value.
class AppStatsRepository {
  const AppStatsRepository({
    FirebaseFirestore? firestore,
    bool? availableOverride,
    DateTime Function()? nowOverride,
  }) : _firestore = firestore,
       _availableOverride = availableOverride,
       _nowOverride = nowOverride;

  final FirebaseFirestore? _firestore;
  final bool? _availableOverride;
  final DateTime Function()? _nowOverride;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  bool get _available => _availableOverride ?? FirebaseBootstrap.available;
  DateTime get _now => (_nowOverride ?? DateTime.now)();

  /// Call once per app load (see lib/main.dart), regardless of which route
  /// it lands on.
  Future<void> recordVisit() => _incrementBoth('visits');

  /// Call once per real game start (see game_screen.dart's `_startGame`) —
  /// never from the tutorial/showcase/promo screens' own controllers.
  Future<void> recordPlay() => _incrementBoth('plays');

  Future<void> _incrementBoth(String statId) async {
    await _increment(statId);
    await _incrementToday(statId);
  }

  /// Best-effort: swallows any failure (offline, Firebase not configured,
  /// permission denied) exactly like the rest of this app's optional
  /// telemetry — recording a visit/play must never fail or block anything.
  Future<void> _increment(String docId) async {
    if (!_available) return;
    try {
      await _db.collection('appStats').doc(docId).set({
        'count': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort telemetry only.
    }
  }

  Future<void> _incrementToday(String statId) async {
    if (!_available) return;
    try {
      await _db
          .collection('appStats')
          .doc(statId)
          .collection('days')
          .doc(jstDateKey(_now))
          .set({'count': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (_) {
      // Best-effort telemetry only.
    }
  }
}

/// `yyyy-MM-dd` for [instant] converted to JST (UTC+9, no DST) — shared by
/// both the write side above and AdminPlaytestRepository's read side so the
/// two can never disagree on where a day's boundary falls.
String jstDateKey(DateTime instant) {
  final jst = instant.toUtc().add(const Duration(hours: 9));
  String pad2(int n) => n.toString().padLeft(2, '0');
  return '${jst.year}-${pad2(jst.month)}-${pad2(jst.day)}';
}
