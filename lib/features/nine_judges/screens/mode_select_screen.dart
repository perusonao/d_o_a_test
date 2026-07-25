import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class NineJudgesModeSelectScreen extends StatefulWidget {
  const NineJudgesModeSelectScreen({
    required this.onStart,
    this.onOpenLogs,
    super.key,
  });

  final ValueChanged<NineJudgesGameSettings> onStart;
  final VoidCallback? onOpenLogs;

  @override
  State<NineJudgesModeSelectScreen> createState() =>
      _NineJudgesModeSelectScreenState();
}

class _NineJudgesModeSelectScreenState
    extends State<NineJudgesModeSelectScreen> {
  GameMode mode = GameMode.cpu;
  CpuLevel level = CpuLevel.basic;
  FactionSelection faction = FactionSelection.random;
  FirstPlayerSelection firstPlayer = FirstPlayerSelection.random;
  bool scoreVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.balance, color: Color(0xFFD6B25E), size: 52),
                  const SizedBox(height: 12),
                  const Text(
                    '9人の審判',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD6B25E),
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text('対戦モード', textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  SegmentedButton<GameMode>(
                    key: const Key('game-mode-selector'),
                    segments: const [
                      ButtonSegment(
                        value: GameMode.cpu,
                        icon: Icon(Icons.smart_toy_outlined),
                        label: Text('CPU対戦'),
                      ),
                      ButtonSegment(
                        value: GameMode.hotseat,
                        icon: Icon(Icons.people_outline),
                        label: Text('2人対戦'),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (value) =>
                        setState(() => mode = value.first),
                  ),
                  if (mode == GameMode.cpu) ...[
                    const SizedBox(height: 16),
                    const Text('陣営', textAlign: TextAlign.center),
                    SegmentedButton<FactionSelection>(
                      key: const Key('faction-selector'),
                      segments: const [
                        ButtonSegment(
                          value: FactionSelection.savior,
                          label: Text('救済者'),
                        ),
                        ButtonSegment(
                          value: FactionSelection.executor,
                          label: Text('執行者'),
                        ),
                        ButtonSegment(
                          value: FactionSelection.random,
                          label: Text('ランダム'),
                        ),
                      ],
                      selected: {faction},
                      onSelectionChanged: (v) =>
                          setState(() => faction = v.first),
                    ),
                    const SizedBox(height: 10),
                    const Text('先攻', textAlign: TextAlign.center),
                    SegmentedButton<FirstPlayerSelection>(
                      key: const Key('first-player-selector'),
                      segments: const [
                        ButtonSegment(
                          value: FirstPlayerSelection.human,
                          label: Text('自分'),
                        ),
                        ButtonSegment(
                          value: FirstPlayerSelection.cpu,
                          label: Text('CPU'),
                        ),
                        ButtonSegment(
                          value: FirstPlayerSelection.random,
                          label: Text('ランダム'),
                        ),
                      ],
                      selected: {firstPlayer},
                      onSelectionChanged: (v) =>
                          setState(() => firstPlayer = v.first),
                    ),
                    const SizedBox(height: 14),
                    const Text('CPUレベル', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    SegmentedButton<CpuLevel>(
                      key: const Key('cpu-level-selector'),
                      segments: const [
                        ButtonSegment(
                          value: CpuLevel.random,
                          label: Text('EASY'),
                        ),
                        ButtonSegment(
                          value: CpuLevel.basic,
                          label: Text('NORMAL'),
                        ),
                      ],
                      selected: {level},
                      onSelectionChanged: (value) =>
                          setState(() => level = value.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      level == CpuLevel.random
                          ? 'RANDOM：合法手からランダムに選択'
                          : 'BASIC：人物価値と陣営目的で評価',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SwitchListTile(
                    key: const Key('score-visible-switch'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('得点を公開'),
                    subtitle: Text(
                      scoreVisible
                          ? '1・2・3点を表示（rank固定列）'
                          : 'EYEで確認するまで非公開（ランダム配置）',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: scoreVisible,
                    onChanged: (value) => setState(() => scoreVisible = value),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('start-game'),
                    onPressed: () => widget.onStart(
                      NineJudgesGameSettings(
                        mode: mode,
                        cpuLevel: level,
                        factionSelection: faction,
                        firstPlayerSelection: firstPlayer,
                        scoreVisible: scoreVisible,
                      ),
                    ),
                    child: const Text('ゲーム開始'),
                  ),
                  TextButton.icon(
                    key: const Key('open-play-logs'),
                    onPressed: widget.onOpenLogs,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('プレイログ・分析'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
