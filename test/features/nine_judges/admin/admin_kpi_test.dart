import 'package:dead_or_alive/features/nine_judges/admin/services/admin_kpi.dart';
import 'package:dead_or_alive/features/nine_judges/analysis/external_test_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('buildAdminKpiReport', () {
    test('tool/run_external_test_analysis.dartと同じExternalTestReport.buildを使う', () {
      final records = [
        buildRecord(gameId: 'g1', funRating: 5, ruleUnderstandingRating: 4),
        buildRecord(gameId: 'g2', funRating: 3, ruleUnderstandingRating: 3),
      ];
      final viaHelper = buildAdminKpiReport(records);
      final viaDirect = ExternalTestReport.build(
        sessions: records.map((r) => r.session).toList(),
        tutorialEvents: const [],
        oneSidedThreshold: 15,
      );
      expect(viaHelper.toJson(), viaDirect.toJson());
    });

    test('チュートリアルKPIは常にN/A(Firestoreに送信されていないため)', () {
      final report = buildAdminKpiReport([buildRecord(gameId: 'g1')]);
      final tutorial = report.values['tutorial']! as Map<String, Object?>;
      expect(tutorial['startedCount'], 0);
      expect(tutorial['completionRate'], 0);
    });
  });

  group('kpiSampleSizeGuidance', () {
    test('サンプルサイズの目安がセクション17の区分と一致する', () {
      expect(kpiSampleSizeGuidance(0), contains('データがありません'));
      expect(kpiSampleSizeGuidance(3), contains('参考値'));
      expect(kpiSampleSizeGuidance(7), contains('初期傾向'));
      expect(kpiSampleSizeGuidance(15), contains('改善候補'));
      expect(kpiSampleSizeGuidance(25), contains('一定の傾向評価'));
    });
  });
}
