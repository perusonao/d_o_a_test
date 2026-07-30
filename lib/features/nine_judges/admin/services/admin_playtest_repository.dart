import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/admin/models/playtest_record.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/admin_firebase.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';

/// One page of `playtests` documents plus enough state to fetch the next
/// page (section 9/23: never bulk-fetch, always paginate).
class AdminPlaytestPage {
  const AdminPlaytestPage({
    required this.records,
    required this.lastDocument,
    required this.hasMore,
    this.malformedCount = 0,
  });

  final List<PlaytestRecord> records;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  /// Docs that failed to parse (section 21: "malformed data") and were
  /// skipped rather than crashing the screen.
  final int malformedCount;
}

/// Read-only Firestore access for the admin dashboard. [firestore] is
/// injectable (e.g. a `FakeFirebaseFirestore`) so pagination/parsing can be
/// tested without a live Firebase project or Google Sign-In — mirrors
/// [FirebasePlaytestRepository]'s existing injectable-constructor pattern.
class AdminPlaytestRepository {
  AdminPlaytestRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  Future<FirebaseFirestore> get _firestore async =>
      _firestoreOverride ?? await AdminFirebase.firestore();

  /// Section 9: first page defaults to 20, "load more" also loads 20 at a
  /// time.
  static const pageSize = 20;

  Future<AdminPlaytestPage> fetchFirstPage({int limit = pageSize}) async {
    final firestore = await _firestore;
    final snapshot = await firestore
        .collection('playtests')
        .orderBy('finishedAt', descending: true)
        .limit(limit)
        .get();
    return _toPage(snapshot, limit);
  }

  Future<AdminPlaytestPage> fetchNextPage(
    DocumentSnapshot<Map<String, dynamic>> after, {
    int limit = pageSize,
  }) async {
    final firestore = await _firestore;
    final snapshot = await firestore
        .collection('playtests')
        .orderBy('finishedAt', descending: true)
        .startAfterDocument(after)
        .limit(limit)
        .get();
    return _toPage(snapshot, limit);
  }

  AdminPlaytestPage _toPage(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int limit,
  ) {
    final records = <PlaytestRecord>[];
    var malformed = 0;
    for (final doc in snapshot.docs) {
      try {
        records.add(PlaytestRecord.fromFirestore(doc.data()));
      } catch (_) {
        malformed++;
      }
    }
    return AdminPlaytestPage(
      records: records,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length >= limit,
      malformedCount: malformed,
    );
  }

  /// Section 12: fetch a game's action log ONLY when its detail view is
  /// opened — never as part of the dashboard/list load. Ordered by the
  /// zero-padded document id, which matches `actionIndex` ordering (see
  /// FirebasePlaytestRepository.send).
  Future<List<GameActionLog>> fetchActions(String gameId) async {
    final firestore = await _firestore;
    final snapshot = await firestore
        .collection('playtests')
        .doc(gameId)
        .collection('actions')
        .orderBy(FieldPath.documentId)
        .get();
    return snapshot.docs
        .map((doc) => GameActionLog.fromJson(doc.data()))
        .toList();
  }

  /// One tester's complete match history (faction/first-or-second/result
  /// per game) — fetched directly from Firestore rather than relying on
  /// whatever pages the dashboard's own pagination happens to have loaded,
  /// since a tester's earlier games can easily fall off the currently
  /// loaded window. A single-field `where` (no `orderBy`) so no composite
  /// Firestore index is required; sorted client-side by `playNumber`
  /// instead.
  Future<List<PlaytestRecord>> fetchByTester(String testerId) async {
    final firestore = await _firestore;
    final snapshot = await firestore
        .collection('playtests')
        .where('testerId', isEqualTo: testerId)
        .get();
    final records = <PlaytestRecord>[];
    for (final doc in snapshot.docs) {
      try {
        records.add(PlaytestRecord.fromFirestore(doc.data()));
      } catch (_) {
        // Malformed docs are skipped here too (see _toPage above).
      }
    }
    records.sort(
      (a, b) => (a.session.playNumber ?? 0).compareTo(b.session.playNumber ?? 0),
    );
    return records;
  }

  /// A durable, cross-device count of how many distinct users have
  /// completed the tutorial (see
  /// services/tutorial_completion_repository.dart) — computed with
  /// Firestore's server-side `count()` aggregation so this never needs to
  /// download every `tutorialCompletions` document.
  Future<int> fetchTutorialCompletionCount() async {
    final firestore = await _firestore;
    final aggregate = await firestore
        .collection('tutorialCompletions')
        .count()
        .get();
    return aggregate.count ?? 0;
  }

  /// Raw, never-deduplicated totals from AppStatsRepository's counters —
  /// "how many times has the site been loaded" / "how many times has a
  /// real game actually started", independent of the `playtests` collection
  /// (which only reflects games whose player went on to submit feedback).
  Future<int> fetchVisitCount() => _fetchAppStatCount('visits');
  Future<int> fetchPlayCount() => _fetchAppStatCount('plays');

  Future<int> _fetchAppStatCount(String docId) async {
    final firestore = await _firestore;
    final doc = await firestore.collection('appStats').doc(docId).get();
    return (doc.data()?['count'] as num?)?.toInt() ?? 0;
  }
}
