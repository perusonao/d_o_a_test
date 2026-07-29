import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CPU-strength "make it stronger" round: CpuLevel.values must list
/// difficulties from weakest to strongest measured strength (verified via
/// cross-play round-robin testing, not just intuition from the persona
/// names), and each entry must carry an easy-to-read strength tier label
/// alongside its existing (unchanged, backward-compatible) uiLabel/
/// strategyLabel/description fields.
void main() {
  test('CpuLevel.valuesは実測の弱い順→強い順に並ぶ', () {
    expect(CpuLevel.values, [
      CpuLevel.random,
      CpuLevel.aggressive,
      CpuLevel.expert,
      CpuLevel.defensive,
      CpuLevel.balanced,
    ]);
  });

  test('各段階にstrengthLabelが弱い順→強い順で設定されている', () {
    expect(CpuLevel.values.map((l) => l.strengthLabel).toList(), [
      'EASY',
      'NORMAL',
      'HARD',
      'HARDER',
      'HARDEST',
    ]);
  });

  test('既存のuiLabel/strategyLabel/descriptionは変更されていない(後方互換)', () {
    expect(CpuLevel.random.uiLabel, 'ランダム');
    expect(CpuLevel.random.strategyLabel, 'RANDOM');
    expect(CpuLevel.balanced.uiLabel, 'バランス');
    expect(CpuLevel.balanced.strategyLabel, 'BALANCED');
    expect(CpuLevel.aggressive.uiLabel, '攻撃的');
    expect(CpuLevel.aggressive.strategyLabel, 'AGGRESSIVE');
    expect(CpuLevel.defensive.uiLabel, '守備的');
    expect(CpuLevel.defensive.strategyLabel, 'DEFENSIVE');
    expect(CpuLevel.expert.uiLabel, '熟練');
    expect(CpuLevel.expert.strategyLabel, 'EXPERT');
  });

  testWidgets('AI思考ドロップダウンは既定選択(バランス)をuiLabel（strengthLabel）形式で表示する', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NineJudgesModeSelectScreen(onStart: _noopOnStart),
      ),
    );
    expect(find.byKey(const Key('cpu-level-dropdown')), findsOneWidget);
    expect(find.text('バランス（HARDEST）'), findsOneWidget);
  });
}

void _noopOnStart(NineJudgesGameSettings settings) {}
