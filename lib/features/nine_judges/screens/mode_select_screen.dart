import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:flutter/material.dart';

class NineJudgesModeSelectScreen extends StatefulWidget {
  const NineJudgesModeSelectScreen({required this.onStart, super.key});

  final ValueChanged<NineJudgesGameSettings> onStart;

  @override
  State<NineJudgesModeSelectScreen> createState() =>
      _NineJudgesModeSelectScreenState();
}

class _NineJudgesModeSelectScreenState
    extends State<NineJudgesModeSelectScreen> {
  GameMode mode = GameMode.cpu;
  CpuLevel level = CpuLevel.basic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                    const SizedBox(height: 28),
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
                  const SizedBox(height: 36),
                  FilledButton(
                    key: const Key('start-game'),
                    onPressed: () => widget.onStart(
                      NineJudgesGameSettings(mode: mode, cpuLevel: level),
                    ),
                    child: const Text('ゲーム開始'),
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
