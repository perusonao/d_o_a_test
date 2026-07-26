import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebasePlaytestRepository {
  const FirebasePlaytestRepository();

  Future<bool> wasSent(String gameId) async =>
      (await SharedPreferences.getInstance()).getBool('sent.$gameId') ?? false;

  Future<void> send({
    required GameSession session,
    required Map<String, int> ratings,
    required String notes,
  }) async {
    final uid = FirebaseBootstrap.uid;
    if (!FirebaseBootstrap.available || uid == null) {
      throw StateError('Firebaseが未設定のため送信できません');
    }
    if (await wasSent(session.gameId)) return;
    final data = session.toJson();
    data.remove('actions');
    await FirebaseFirestore.instance
        .collection('playtests')
        .doc(session.gameId)
        .set({
          ...data,
          'testerId': uid,
          'ratings': ratings,
          'notes': notes,
          'createdAt': FieldValue.serverTimestamp(),
        });
    final batch = FirebaseFirestore.instance.batch();
    for (final action in session.actions) {
      batch.set(
        FirebaseFirestore.instance
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
