import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/logging/game_log_models.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

abstract interface class GameLogRepository {
  Future<void> saveGame(GameSession session);
  Future<List<GameSession>> listGames();
  Future<GameSession?> loadGame(String gameId);
  Future<void> deleteGame(String gameId);
  Future<void> deleteAllGames();
  Future<String> exportGame(String gameId);
  Future<String> exportAllGames();
}

class LocalGameLogRepository implements GameLogRepository {
  LocalGameLogRepository._();

  static final LocalGameLogRepository instance = LocalGameLogRepository._();
  static const _boxName = 'nine_judges_game_logs_v03';
  Box<dynamic>? _box;

  Future<Box<dynamic>> _open() async {
    if (_box case final box?) return box;
    await Hive.initFlutter();
    return _box = await Hive.openBox<dynamic>(_boxName);
  }

  @override
  Future<void> saveGame(GameSession session) async {
    final box = await _open();
    await box.put(session.gameId, session.toJson());
  }

  @override
  Future<List<GameSession>> listGames() async {
    final box = await _open();
    final games =
        box.values
            .map(
              (value) =>
                  GameSession.fromJson((value as Map).cast<String, dynamic>()),
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return games;
  }

  @override
  Future<GameSession?> loadGame(String gameId) async {
    final value = (await _open()).get(gameId);
    return value == null
        ? null
        : GameSession.fromJson((value as Map).cast<String, dynamic>());
  }

  @override
  Future<void> deleteGame(String gameId) async =>
      (await _open()).delete(gameId);

  @override
  Future<void> deleteAllGames() async => (await _open()).clear();

  @override
  Future<String> exportGame(String gameId) async =>
      (await loadGame(gameId))?.toPrettyJson() ?? '{}';

  @override
  Future<String> exportAllGames() async => const JsonEncoder.withIndent(
    '  ',
  ).convert((await listGames()).map((e) => e.toJson()).toList());
}

class MemoryGameLogRepository implements GameLogRepository {
  final Map<String, GameSession> games = {};

  @override
  Future<void> saveGame(GameSession session) async =>
      games[session.gameId] = session;
  @override
  Future<List<GameSession>> listGames() async =>
      games.values.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  @override
  Future<GameSession?> loadGame(String gameId) async => games[gameId];
  @override
  Future<void> deleteGame(String gameId) async => games.remove(gameId);
  @override
  Future<void> deleteAllGames() async => games.clear();
  @override
  Future<String> exportGame(String gameId) async =>
      games[gameId]?.toPrettyJson() ?? '{}';
  @override
  Future<String> exportAllGames() async =>
      jsonEncode(games.values.map((e) => e.toJson()).toList());
}
