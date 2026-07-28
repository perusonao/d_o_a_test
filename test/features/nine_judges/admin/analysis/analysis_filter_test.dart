import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('AnalysisFilter', () {
    test('デフォルトは最新50件・基本分析でフィールド絞り込みなし', () {
      const filter = AnalysisFilter();
      expect(filter.source, AnalysisSource.latest50);
      expect(filter.mode, AnalysisMode.basic);
      expect(filter.hasFieldFilters, isFalse);
    });

    test('rulesVersion/playerFaction/winner等の完全一致フィルター', () {
      final record = buildRecord(
        gameId: 'g1',
        rulesVersion: '1.2',
        playerFaction: 'savior',
        winner: 'savior',
        firstPlayer: 'savior',
        cpuDifficulty: 'balanced',
      );
      expect(
        const AnalysisFilter().copyWith(rulesVersion: '1.1').matches(record),
        isFalse,
      );
      expect(
        const AnalysisFilter().copyWith(rulesVersion: '1.2').matches(record),
        isTrue,
      );
      expect(
        const AnalysisFilter().copyWith(cpuDifficulty: 'hard').matches(record),
        isFalse,
      );
    });

    test('ratedOnly/commentedOnlyフィルター', () {
      final rated = buildRecord(gameId: 'g1', funRating: 4);
      final unrated = buildRecord(gameId: 'g2');
      final commented = buildRecord(gameId: 'g3', feedbackComment: 'よかった');

      expect(const AnalysisFilter(ratedOnly: true).matches(rated), isTrue);
      expect(const AnalysisFilter(ratedOnly: true).matches(unrated), isFalse);
      expect(
        const AnalysisFilter(commentedOnly: true).matches(commented),
        isTrue,
      );
      expect(
        const AnalysisFilter(commentedOnly: true).matches(unrated),
        isFalse,
      );
    });

    test('日付範囲フィルターはfinishedAtで判定する', () {
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
      final filter = AnalysisFilter(
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 7, 1),
      );
      expect(filter.matches(inRange), isTrue);
      expect(filter.matches(outOfRange), isFalse);
    });

    test('copyWithのclearフラグでフィールドを解除できる', () {
      final withFilter = const AnalysisFilter().copyWith(rulesVersion: '1.2');
      expect(withFilter.hasFieldFilters, isTrue);
      final cleared = withFilter.copyWith(clearRulesVersion: true);
      expect(cleared.rulesVersion, isNull);
      expect(cleared.hasFieldFilters, isFalse);
    });
  });
}
