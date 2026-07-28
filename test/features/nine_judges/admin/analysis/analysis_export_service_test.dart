import 'dart:convert';

import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_filter.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/models/analysis_report.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/analysis_export_service.dart';
import 'package:dead_or_alive/features/nine_judges/admin/analysis/services/external_test_analysis_service.dart';
import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('AnalysisExportService — JSON', () {
    test('reportSchemaVersionを含み、jsonDecodeで往復できる', () {
      final report = buildAnalysisReport(
        pool: [buildRecord(gameId: 'g1')],
        filter: const AnalysisFilter(),
        projectId: 'nine-verdicts',
        anonymizer: TesterAnonymizer(),
      );
      final jsonText = AnalysisExportService.buildJson(report);
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      expect(decoded['reportSchemaVersion'], analysisReportSchemaVersion);
      expect(decoded.containsKey('summary'), isTrue);
      expect(decoded.containsKey('balance'), isTrue);
      expect(decoded.containsKey('eyeAnalysis'), isTrue);
      expect(decoded.containsKey('judgeAnalysis'), isTrue);
      expect(decoded.containsKey('reverseAnalysis'), isTrue);
      expect(decoded.containsKey('firstGameComparison'), isTrue);
      expect(decoded.containsKey('cpuDifficultyAnalysis'), isTrue);
      expect(decoded.containsKey('kpis'), isTrue);
      expect(decoded.containsKey('findings'), isTrue);
      expect(decoded.containsKey('feedback'), isTrue);
      expect(decoded.containsKey('metadata'), isTrue);
    });

    test('0件データでもJSON生成が失敗しない', () {
      final report = buildAnalysisReport(
        pool: const [],
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(() => AnalysisExportService.buildJson(report), returnsNormally);
    });

    test('actionsの取得に失敗したゲームIDがmetadataに記録される', () {
      final report = buildAnalysisReport(
        pool: [buildRecord(gameId: 'g1')],
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
        failedActionGameCount: 2,
        failedGameIds: const ['g2', 'g3'],
      );
      expect(report.metadata['failedActionGameCount'], 2);
      expect(report.metadata['failedGameIds'], ['g2', 'g3']);
    });
  });

  group('AnalysisExportService — Markdown', () {
    test('必須セクション見出しと固定の依頼文を含む', () {
      final report = buildAnalysisReport(
        pool: [buildRecord(gameId: 'g1')],
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      final markdown = AnalysisExportService.buildMarkdown(report);
      for (final heading in [
        '## 分析条件',
        '## エグゼクティブサマリー',
        '## 全体統計',
        '## ゲームバランス',
        '## 評価結果',
        '## 初回プレイヤーと経験者',
        '## EYE分析',
        '## JUDGE分析',
        '## reverse分析',
        '## CPU難易度別',
        '## KPI',
        '## 自由記述',
        '## 自動検出された注目点',
        '## AIに分析してほしいこと',
      ]) {
        expect(markdown, contains(heading));
      }
      expect(markdown, contains('救済者と執行者のバランス'));
      expect(markdown, contains('データから確認できる事実'));
      expect(markdown, contains('外部AIへ自動送信されません'));
    });

    test('自由記述の改行を保持する', () {
      final report = buildAnalysisReport(
        pool: [buildRecord(gameId: 'g1', feedbackComment: '1行目\n2行目')],
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      final markdown = AnalysisExportService.buildMarkdown(report);
      expect(markdown, contains('1行目'));
      expect(markdown, contains('2行目'));
    });

    test('0件データでもMarkdown生成が失敗しない', () {
      final report = buildAnalysisReport(
        pool: const [],
        filter: const AnalysisFilter(),
        projectId: 'p',
        anonymizer: TesterAnonymizer(),
      );
      expect(() => AnalysisExportService.buildMarkdown(report), returnsNormally);
    });
  });

  group('AnalysisExportService — filenames', () {
    test('日付を含むファイル名を生成する', () {
      final now = DateTime(2026, 7, 28);
      expect(
        AnalysisExportService.jsonFileName(now),
        'nine_verdicts_analysis_report_2026-07-28.json',
      );
      expect(
        AnalysisExportService.markdownFileName(now),
        'nine_verdicts_analysis_report_2026-07-28.md',
      );
    });
  });
}
