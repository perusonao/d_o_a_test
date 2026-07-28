import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_filter.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/external_test_analysis_service.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('分析レポートの匿名化(section 9)', () {
    test('生成JSONにtesterId/firebaseUidの生値が一切含まれない', () {
      final pool = [
        buildRecord(
          gameId: 'g1',
          testerId: 'raw-tester-id-should-not-leak',
          firebaseUid: 'raw-firebase-uid-should-not-leak',
          feedbackComment: 'とても楽しかったです',
        ),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      final json = jsonEncode(report.toJson());
      expect(json.contains('raw-tester-id-should-not-leak'), isFalse);
      expect(json.contains('raw-firebase-uid-should-not-leak'), isFalse);
    });

    test('同一testerIdは常に同じPlayer番号、異なるtesterIdは異なる番号になる', () {
      final anonymizer = TesterAnonymizer();
      final pool = [
        buildRecord(gameId: 'g1', testerId: 'tester-a', feedbackComment: 'コメントA-1'),
        buildRecord(gameId: 'g2', testerId: 'tester-b', feedbackComment: 'コメントB'),
        buildRecord(gameId: 'g3', testerId: 'tester-a', feedbackComment: 'コメントA-2'),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: anonymizer,
      );
      final labels = {
        for (final f in report.feedback) f['gameId']: f['anonymousPlayerLabel'],
      };
      expect(labels['g1'], labels['g3']);
      expect(labels['g1'], isNot(labels['g2']));
    });

    test('空コメントは自由記述リストから除外される', () {
      final pool = [
        buildRecord(gameId: 'g1', feedbackComment: ''),
        buildRecord(gameId: 'g2', feedbackComment: '  '),
        buildRecord(gameId: 'g3', feedbackComment: '中身あり'),
      ];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.feedback.length, 1);
      expect(report.feedback.single['gameId'], 'g3');
    });

    test('コメントは改変されず保持される(改行・特殊文字含む)', () {
      const comment = '1行目\n2行目\n"引用符" & <タグ風> 🎲';
      final pool = [buildRecord(gameId: 'g1', feedbackComment: comment)];
      final report = buildAnalysisReport(
        pool: pool,
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(report.feedback.single['feedbackComment'], comment);
    });
  });
}
