import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/online/online_lobby_screen.dart';
import 'package:dead_or_alive/features/nine_judges/rules/rules_guide_screen.dart';
import 'package:dead_or_alive/features/nine_judges/tutorial/tutorial_screen.dart';
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
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/branding/app_icon.png',
                        width: 76,
                        height: 76,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '9人の審判',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD6B25E),
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'NINE VERDICTS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('start-game'),
                    onPressed: () => widget.onStart(
                      NineJudgesGameSettings(
                        mode: mode,
                        cpuLevel: level,
                        factionSelection: faction,
                        firstPlayerSelection: firstPlayer,
                      ),
                    ),
                    child: const Text('ゲーム開始'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('open-online'),
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnlineLobbyScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.public),
                    label: const Text('オンライン対戦 β'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          key: const Key('open-tutorial'),
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorialScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.school_outlined),
                          label: const Text('チュートリアル'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          key: const Key('open-rules'),
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RulesGuideScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('遊び方'),
                        ),
                      ),
                    ],
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
