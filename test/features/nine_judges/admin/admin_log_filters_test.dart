import 'package:dead_or_alive/features/nine_judges/admin/services/admin_log_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('AdminLogFilters', () {
    test('デフォルトはisActive=falseで全件通す', () {
      const filters = AdminLogFilters();
      expect(filters.isActive, isFalse);
      expect(filters.matches(buildRecord(gameId: 'g1'), 'Player 001'), isTrue);
    });

    test('gameIdは部分一致(大文字小文字を区別しない)', () {
      final filters = const AdminLogFilters().copyWith(gameId: 'ABC');
      expect(filters.matches(buildRecord(gameId: 'game-abc-1'), 'Player 001'), isTrue);
      expect(filters.matches(buildRecord(gameId: 'game-xyz-1'), 'Player 001'), isFalse);
    });

    test('testerLabelは匿名化済みラベルに対して一致する(生のtesterIdは見ない)', () {
      final filters = const AdminLogFilters().copyWith(testerLabel: '001');
      expect(filters.matches(buildRecord(gameId: 'g1'), 'Player 001'), isTrue);
      expect(filters.matches(buildRecord(gameId: 'g1'), 'Player 002'), isFalse);
    });

    test('rulesVersion/playerFaction/winner/firstPlayer/cpuDifficultyの完全一致', () {
      final record = buildRecord(
        gameId: 'g1',
        rulesVersion: '1.2',
        playerFaction: 'savior',
        winner: 'savior',
        firstPlayer: 'savior',
        cpuDifficulty: 'balanced',
      );
      expect(
        const AdminLogFilters().copyWith(rulesVersion: '1.1').matches(record, 'Player 001'),
        isFalse,
      );
      expect(
        const AdminLogFilters().copyWith(rulesVersion: '1.2').matches(record, 'Player 001'),
        isTrue,
      );
    });

    test('isFirstGameフィルター', () {
      final firstGame = buildRecord(gameId: 'g1', isFirstGame: true);
      final laterGame = buildRecord(gameId: 'g2', isFirstGame: false);
      final filters = const AdminLogFilters().copyWith(isFirstGame: true);
      expect(filters.matches(firstGame, 'Player 001'), isTrue);
      expect(filters.matches(laterGame, 'Player 001'), isFalse);
    });

    test('hasFeedbackCommentフィルター', () {
      final withComment = buildRecord(gameId: 'g1', feedbackComment: '楽しかった');
      final withoutComment = buildRecord(gameId: 'g2');
      final filters = const AdminLogFilters().copyWith(hasFeedbackComment: true);
      expect(filters.matches(withComment, 'Player 001'), isTrue);
      expect(filters.matches(withoutComment, 'Player 001'), isFalse);
    });

    test('hasAnyRatingフィルター', () {
      final rated = buildRecord(gameId: 'g1', funRating: 4);
      final unrated = buildRecord(gameId: 'g2');
      final filters = const AdminLogFilters().copyWith(hasAnyRating: true);
      expect(filters.matches(rated, 'Player 001'), isTrue);
      expect(filters.matches(unrated, 'Player 001'), isFalse);
    });

    test('日付範囲(from/to)はfinishedAtで判定する', () {
      final inRange = buildRecord(
        gameId: 'g1',
        startedAt: DateTime(2026, 6, 1),
        finishedAt: DateTime(2026, 6, 1, 0, 10),
      );
      final outOfRange = buildRecord(
        gameId: 'g2',
        startedAt: DateTime(2026, 8, 1),
        finishedAt: DateTime(2026, 8, 1, 0, 10),
      );
      final filters = const AdminLogFilters().copyWith(
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 7, 1),
      );
      expect(filters.matches(inRange, 'Player 001'), isTrue);
      expect(filters.matches(outOfRange, 'Player 001'), isFalse);
    });

    test('clearAllで全フィルターが解除される', () {
      final filters = const AdminLogFilters().copyWith(gameId: 'abc', isFirstGame: true);
      expect(filters.isActive, isTrue);
      expect(filters.clearAll().isActive, isFalse);
    });
  });
}
