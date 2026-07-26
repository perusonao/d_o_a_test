import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/online/online_models.dart';
import 'package:dead_or_alive/features/nine_judges/services/firebase_bootstrap.dart';

class OnlineRoomRepository {
  OnlineRoomRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String get _uid {
    final value = FirebaseBootstrap.uid;
    if (value == null) throw StateError('Firebase匿名認証が必要です');
    return value;
  }

  Future<String> createRoom() async {
    final code = (100000 + Random.secure().nextInt(900000)).toString();
    final room = _firestore.collection('rooms').doc(code);
    await room.set({
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'hostUid': _uid,
      'guestUid': null,
      'currentTurnUid': _uid,
      'firstPlayerUid': _uid,
      'rulesVersion': NineJudgesConfig.rulesVersion,
      'gameVersion': NineJudgesConfig.gameVersion,
      'revision': 0,
      'winner': null,
      'finishedAt': null,
      'playerUids': [_uid],
      // TODO(nine-verdicts-online): Cloud Functionsで真の盤面とbonusOrderを生成する。
    });
    await room.collection('players').doc(_uid).set({
      'faction': 'savior',
      'knownAttributes': <String, String>{},
      'knownBonus': null,
      'eyeKnowledge': <String, String>{},
    });
    return code;
  }

  Future<void> joinRoom(String code) async {
    final room = _firestore.collection('rooms').doc(code);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(room);
      if (!snapshot.exists) throw StateError('ルームが見つかりません');
      final data = snapshot.data()!;
      if (data['guestUid'] != null && data['guestUid'] != _uid) {
        throw StateError('ルームは満員です');
      }
      transaction.update(room, {
        'guestUid': _uid,
        'status': 'playing',
        'updatedAt': FieldValue.serverTimestamp(),
        'playerUids': [data['hostUid'], _uid],
      });
    });
    await room.collection('players').doc(_uid).set({
      'faction': 'executor',
      'knownAttributes': <String, String>{},
      'knownBonus': null,
      'eyeKnowledge': <String, String>{},
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String code) =>
      _firestore.collection('rooms').doc(code).snapshots();

  Future<void> submitAction(String code, OnlineActionRequest request) async {
    final room = _firestore.collection('rooms').doc(code);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(room);
      final data = snapshot.data();
      if (data == null) throw StateError('ルームがありません');
      if (!(List<String>.from(data['playerUids'] as List)).contains(_uid)) {
        throw StateError('ルーム参加者ではありません');
      }
      if (data['currentTurnUid'] != _uid) throw StateError('相手の手番です');
      if (data['revision'] != request.clientRevision) {
        throw StateError('盤面が更新されています');
      }
      final nextUid = data['hostUid'] == _uid
          ? data['guestUid']
          : data['hostUid'];
      transaction
          .set(room.collection('actions').doc(request.actionIndex.toString()), {
            'actorUid': _uid,
            'actionIndex': request.actionIndex,
            'actionType': request.action.name,
            'targetPersonId': request.targetIndex,
            'clientRevision': request.clientRevision,
            'createdAt': FieldValue.serverTimestamp(),
          });
      transaction.update(room, {
        'revision': request.clientRevision + 1,
        'currentTurnUid': nextUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
