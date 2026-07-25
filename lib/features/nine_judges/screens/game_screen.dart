import 'package:dead_or_alive/features/nine_judges/game/game_controller.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/screens/handoff_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/mode_select_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/result_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/play_log_screen.dart';
import 'package:dead_or_alive/features/nine_judges/logging/game_log_repository.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/action_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/board_grid.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/selected_card_panel.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/hand_status_panel.dart';
import 'package:flutter/material.dart';

class NineJudgesGameScreen extends StatefulWidget {
  const NineJudgesGameScreen({this.initialSettings, super.key});

  final NineJudgesGameSettings? initialSettings;

  @override
  State<NineJudgesGameScreen> createState() => _NineJudgesGameScreenState();
}

class _NineJudgesGameScreenState extends State<NineJudgesGameScreen> {
  NineJudgesController? controller;
  bool _cpuSequenceRunning = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSettings case final settings?) {
      _startGame(settings);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _startGame(NineJudgesGameSettings settings) {
    controller?.removeListener(_handleControllerChanged);
    controller?.dispose();
    controller = NineJudgesController(
      settings: settings,
      logRepository: LocalGameLogRepository.instance,
    )..addListener(_handleControllerChanged);
    _handleControllerChanged();
    if (mounted) setState(() {});
  }

  void _handleControllerChanged() {
    final game = controller;
    if (game == null ||
        !game.isCpuTurn ||
        game.awaitingHandoff ||
        game.isFinished ||
        _cpuSequenceRunning) {
      return;
    }
    _runCpuSequence();
  }

  Future<void> _runCpuSequence() async {
    final game = controller;
    if (game == null) return;
    _cpuSequenceRunning = true;
    await Future<void>.delayed(
      game.settings.skipCpuDelays
          ? Duration.zero
          : const Duration(milliseconds: 550),
    );
    if (!mounted || game != controller || !game.isCpuTurn) {
      _cpuSequenceRunning = false;
      return;
    }
    game.performCpuAction();
    await Future<void>.delayed(
      game.settings.skipCpuDelays
          ? Duration.zero
          : const Duration(milliseconds: 950),
    );
    if (mounted && game == controller) game.clearCpuFeedback();
    _cpuSequenceRunning = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = controller;
    if (game == null) {
      return NineJudgesModeSelectScreen(
        onStart: _startGame,
        onOpenLogs: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PlayLogScreen(repository: LocalGameLogRepository.instance),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        if (game.isFinished) return ResultScreen(controller: game);
        if (game.awaitingHandoff) {
          return HandoffScreen(
            nextPlayer: game.currentPlayer,
            onReady: game.confirmHandoff,
          );
        }
        return _GameBoard(controller: game);
      },
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({required this.controller});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 6),
              child: Column(
                children: [
                  _Header(
                    controller: controller,
                    onSettings: () => _showSettings(context),
                    onHelp: () => _showRules(context),
                  ),
                  const SizedBox(height: 4),
                  _PhaseBanner(controller: controller),
                  if (!controller.isCpuTurn) ...[
                    const SizedBox(height: 3),
                    _InitialKnowledgeBanner(controller: controller),
                  ],
                  const SizedBox(height: 4),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        BoardGrid(controller: controller),
                        if (controller.lastCpuActionMessage != null)
                          _CpuMessage(controller: controller),
                      ],
                    ),
                  ),
                  SelectedCardPanel(controller: controller),
                  HandStatusPanel(controller: controller),
                  ActionPanel(controller: controller),
                  const SizedBox(height: 8),
                  if (controller.debugMode)
                    SizedBox(
                      height: 21,
                      child: TextButton(
                        onPressed: () => showGameLogs(context, controller),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text(
                          '検証ログを表示',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRules(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _RulesDialog(),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('検証設定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  key: const Key('debug-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('デバッグモード'),
                  subtitle: const Text('完全情報・得点・ログを表示'),
                  value: controller.debugMode,
                  onChanged: (value) {
                    controller.setDebugMode(value);
                    setDialogState(() {});
                  },
                ),
                if (controller.isCpuGame) ...[
                  DropdownButtonFormField<CpuLevel>(
                    key: const Key('settings-cpu-level'),
                    initialValue: controller.settings.cpuLevel,
                    decoration: const InputDecoration(labelText: 'CPUレベル'),
                    items: const [
                      DropdownMenuItem(
                        value: CpuLevel.random,
                        child: Text('EASY / RANDOM'),
                      ),
                      DropdownMenuItem(
                        value: CpuLevel.basic,
                        child: Text('NORMAL / BASIC'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      controller.updateSettings(
                        controller.settings.copyWith(cpuLevel: value),
                      );
                      setDialogState(() {});
                    },
                  ),
                  SwitchListTile(
                    key: const Key('skip-cpu-delays'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CPU思考演出をスキップ'),
                    value: controller.settings.skipCpuDelays,
                    onChanged: (value) {
                      controller.updateSettings(
                        controller.settings.copyWith(skipCpuDelays: value),
                      );
                      setDialogState(() {});
                    },
                  ),
                  SwitchListTile(
                    key: const Key('cpu-evaluation-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CPU評価値を表示'),
                    value: controller.settings.showCpuEvaluations,
                    onChanged: (value) {
                      controller.updateSettings(
                        controller.settings.copyWith(showCpuEvaluations: value),
                      );
                      setDialogState(() {});
                    },
                  ),
                  if (controller.settings.showCpuEvaluations &&
                      controller.lastCpuEvaluations.isNotEmpty)
                    Text(
                      controller.lastCpuEvaluations
                          .take(5)
                          .map(
                            (candidate) =>
                                '${candidate.action.label} '
                                'slot${candidate.targetIndex + 1} '
                                '${candidate.score.toStringAsFixed(1)}',
                          )
                          .join('\n'),
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('盤面再シャッフル'),
                  onTap: () {
                    controller.reshuffle();
                    Navigator.pop(dialogContext);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ゲームを即リセット'),
                  onTap: () {
                    controller.reset();
                    Navigator.pop(dialogContext);
                  },
                ),
                if (controller.debugMode)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ゲームログ'),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      showGameLogs(context, controller);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onSettings,
    required this.onHelp,
  });

  final NineJudgesController controller;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final saviorActive = controller.currentPlayer == Faction.savior;
    final executorActive = controller.currentPlayer == Faction.executor;
    return Column(
      children: [
        SizedBox(
          height: 31,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '9人の審判',
                  style: TextStyle(
                    color: Color(0xFFD6B25E),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6B25E)),
                ),
                child: Text(
                  'TURN ${controller.turn} / ${NineJudgesConfig.maxTurns}',
                  style: const TextStyle(
                    color: Color(0xFFE7C979),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                key: const Key('settings-button'),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.only(left: 5),
                constraints: const BoxConstraints(minWidth: 30),
                onPressed: onSettings,
                icon: const Icon(Icons.settings, size: 18),
              ),
              IconButton(
                key: const Key('rules-button'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 27),
                onPressed: onHelp,
                icon: const Icon(Icons.help_outline, size: 19),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(
                child: _FactionLabel(
                  text: controller.isCpuGame
                      ? '救済者（${controller.humanFaction == Faction.savior ? 'あなた' : 'CPU'}）'
                      : '救済者',
                  color: const Color(0xFF62B9F3),
                  active: saviorActive,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const Icon(Icons.balance, size: 19, color: Color(0xFFD6B25E)),
              Expanded(
                child: _FactionLabel(
                  text: controller.isCpuGame
                      ? '執行者（${controller.humanFaction == Faction.executor ? 'あなた' : 'CPU'}）'
                      : '執行者',
                  color: const Color(0xFFF0645A),
                  active: executorActive,
                  alignment: Alignment.centerRight,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Text(
              '判決済み ${controller.judgedCount} / 9',
              style: const TextStyle(
                color: Color(0xFFD6B25E),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: controller.judgedCount / 9,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFD6B25E),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FactionLabel extends StatelessWidget {
  const _FactionLabel({
    required this.text,
    required this.color,
    required this.active,
    required this.alignment,
  });

  final String text;
  final Color color;
  final bool active;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: active ? color : color.withValues(alpha: 0.55),
          fontSize: 11,
          fontWeight: active ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.controller});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final selectingJudge = controller.selectedAction == ActionType.judge;
    final text = controller.isCpuTurn
        ? 'CPUが思考中…'
        : switch (controller.phase) {
            TurnPhase.selectingAction => 'アクションを選択してください',
            TurnPhase.selectingActionTarget =>
              switch (controller.selectedAction!) {
                ActionType.life => 'LIFEを使う人物を選択してください',
                ActionType.death => 'DEATHを使う人物を選択してください',
                ActionType.eye => '正体を見る人物3を選択',
                ActionType.judge => '判決する人物を選択（審議中のみ）',
              },
            TurnPhase.selectingEyeInformation => '確認する情報を選択',
          };
    return AnimatedContainer(
      key: const Key('phase-instruction'),
      duration: const Duration(milliseconds: 120),
      width: double.infinity,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selectingJudge
            ? const Color(0xFF3A2D12)
            : const Color(0xFF201D16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selectingJudge
              ? const Color(0xFFFFD76A)
              : const Color(0xFF806A36),
          width: selectingJudge ? 2 : 1,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selectingJudge
              ? const Color(0xFFFFDF86)
              : const Color(0xFFD6B25E),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InitialKnowledgeBanner extends StatelessWidget {
  const _InitialKnowledgeBanner({required this.controller});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final viewer = controller.currentPlayer;
    final index = controller.initialKnowledgeSlots[viewer]!.single;
    final person = controller.board[index].person;
    return Container(
      key: const Key('initial-knowledge-confirmation'),
      width: double.infinity,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF171B25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF806A36)),
      ),
      child: Text(
        '◆ 初期情報：${person.attribute.label} 3（位置 ${index + 1}）',
        style: const TextStyle(
          color: Color(0xFFE7C979),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CpuMessage extends StatelessWidget {
  const _CpuMessage({required this.controller});

  final NineJudgesController controller;

  @override
  Widget build(BuildContext context) {
    final action = controller.lastCpuActionType;
    final judgment = controller.lastCpuWasJudgment;
    final icon = switch (action) {
      ActionType.life => Icons.favorite,
      ActionType.death => Icons.dangerous,
      ActionType.eye => Icons.visibility,
      ActionType.judge => Icons.balance,
      null => Icons.hourglass_top,
    };
    return GestureDetector(
      key: const Key('cpu-action-message'),
      onTap: controller.clearCpuFeedback,
      child: Container(
        key: judgment
            ? const Key('cpu-judgment-message')
            : const Key('cpu-action-result'),
        width: 245,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xF21B1717),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: judgment ? const Color(0xFFFFD76A) : const Color(0xFFC79255),
            width: judgment ? 3 : 2,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 14, spreadRadius: 3),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              judgment ? 'CPU JUDGMENT' : 'CPU ACTION',
              style: const TextStyle(
                color: Color(0xFFFFD76A),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFFE7C979), size: 22),
                const SizedBox(width: 7),
                Text(
                  action?.label ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              controller.lastCpuActionMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesDialog extends StatelessWidget {
  const _RulesDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('rules-dialog'),
      title: const Row(
        children: [
          Icon(Icons.help_outline, color: Color(0xFFD6B25E)),
          SizedBox(width: 8),
          Text('ルール概要'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RuleSection(
            color: Color(0xFF62B9F3),
            title: '救済者',
            body: 'GOOD・NEUTRAL → 生\nEVIL → 死',
          ),
          _RuleSection(
            color: Color(0xFFF0645A),
            title: '執行者',
            body: 'GOOD・NEUTRAL → 死\nEVIL → 生',
          ),
          Divider(),
          _RuleLine(title: 'LIFE', body: '死→生 / 生ならDEATHを1回防ぐ'),
          _RuleLine(title: 'DEATH', body: '生→死 / 死なら即判決'),
          _RuleLine(title: 'EYE', body: '死状態の人物3の属性を自分だけ確認'),
          _RuleLine(title: 'JUDGE', body: '有限カード。一度審議された人物だけを現在の生死で確定'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.color,
    required this.title,
    required this.body,
  });

  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(child: Text(body, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFD6B25E),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(child: Text(body, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
