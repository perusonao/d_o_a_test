import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-device identity for the external test cohort: an anonymous, persisted
/// [testerId] (no email/name/IP collected) and a play counter so the same
/// tester's 1st/2nd/3rd... games can be compared. Deliberately separate from
/// [NineJudgesController]/[GameSession], which stay synchronous and
/// storage-free so existing tests never need to mock a platform channel.
class ExternalTestProfile {
  const ExternalTestProfile({
    required this.testerId,
    required this.playNumber,
    required this.isFirstGame,
    required this.hasCompletedTutorial,
    required this.hasSkippedTutorial,
  });

  final String testerId;

  /// This game's 1-based play count for this device (localPlayCount + 1 at
  /// the time the game started).
  final int playNumber;

  /// True if this is the first game ever started on this device.
  final bool isFirstGame;

  /// Whether this device had ever completed/skipped the tutorial as of the
  /// moment this game started (see [markTutorialCompleted]/
  /// [markTutorialSkipped]).
  final bool hasCompletedTutorial;
  final bool hasSkippedTutorial;

  static const _testerIdKey = 'external_test.testerId';
  static const _playCountKey = 'external_test.localPlayCount';
  static const _tutorialCompletedKey = 'external_test.tutorialCompleted';
  static const _tutorialSkippedKey = 'external_test.tutorialSkipped';

  static Future<ExternalTestProfile> loadForNewGame() async {
    final prefs = await SharedPreferences.getInstance();
    var testerId = prefs.getString(_testerIdKey);
    if (testerId == null) {
      testerId = generateAnonymousId();
      await prefs.setString(_testerIdKey, testerId);
    }
    final previousCount = prefs.getInt(_playCountKey) ?? 0;
    return ExternalTestProfile(
      testerId: testerId,
      playNumber: previousCount + 1,
      isFirstGame: previousCount == 0,
      hasCompletedTutorial: prefs.getBool(_tutorialCompletedKey) ?? false,
      hasSkippedTutorial: prefs.getBool(_tutorialSkippedKey) ?? false,
    );
  }

  /// Call once the game this profile was loaded for has finished, so the
  /// next game sees an incremented [playNumber].
  Future<void> recordGameFinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playCountKey, playNumber);
  }

  static Future<void> markTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialCompletedKey, true);
  }

  static Future<void> markTutorialSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialSkippedKey, true);
  }
}

/// A random, non-identifying id (UUID v4 shape) generated without adding a
/// `uuid` package dependency. Used for both [ExternalTestProfile.testerId]
/// and the process-lifetime [appSessionId].
String generateAnonymousId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// One id shared by every game/tutorial/rules event for the lifetime of this
/// app process (a browser tab / app launch), so a tester's actions across
/// multiple games in one sitting can be grouped without persisting anything.
String get appSessionId => _appSessionId ??= generateAnonymousId();
String? _appSessionId;

/// Test-only: forces the next [appSessionId] access to generate a fresh id.
void resetAppSessionIdForTest() => _appSessionId = null;
