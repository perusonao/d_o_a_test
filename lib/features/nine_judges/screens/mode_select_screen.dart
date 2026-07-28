import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/online/online_lobby_screen.dart';
import 'package:dead_or_alive/features/nine_judges/rules/rules_guide_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/download_center_screen.dart';
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
  CpuLevel level = CpuLevel.balanced;
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Hero(),
                  const SizedBox(height: 26),
                  _SectionCard(
                    title: 'はじめる',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                          const SizedBox(height: 18),
                          _CpuOptions(
                            faction: faction,
                            firstPlayer: firstPlayer,
                            level: level,
                            onFaction: (v) => setState(() => faction = v),
                            onFirstPlayer: (v) =>
                                setState(() => firstPlayer = v),
                            onLevel: (v) => setState(() => level = v),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          key: const Key('start-game'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 52),
                          ),
                          onPressed: () => widget.onStart(
                            NineJudgesGameSettings(
                              mode: mode,
                              cpuLevel: level,
                              factionSelection: faction,
                              firstPlayerSelection: firstPlayer,
                            ),
                          ),
                          icon: const Icon(Icons.gavel),
                          label: const Text('ゲーム開始'),
                        ),
                        const SizedBox(height: 8),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'メニュー',
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 3.2,
                      children: [
                        _MenuTile(
                          buttonKey: const Key('open-rules'),
                          icon: Icons.menu_book_outlined,
                          label: '遊び方',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RulesGuideScreen(),
                            ),
                          ),
                        ),
                        _MenuTile(
                          buttonKey: const Key('open-tutorial'),
                          icon: Icons.school_outlined,
                          label: 'チュートリアル',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorialScreen(),
                            ),
                          ),
                        ),
                        _MenuTile(
                          buttonKey: const Key('open-downloads'),
                          icon: Icons.download_outlined,
                          label: 'ダウンロード',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DownloadCenterScreen(),
                            ),
                          ),
                        ),
                        _MenuTile(
                          buttonKey: const Key('open-play-logs'),
                          icon: Icons.analytics_outlined,
                          label: 'プレイログ',
                          onTap: widget.onOpenLogs,
                        ),
                      ],
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
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/branding/menu_hero.png',
          fit: BoxFit.cover,
          semanticLabel: '9人の審判 NINE VERDICTS - 善人を救い、悪人を裁け。',
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        '9人の審判',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFD6B25E),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 6),
      const _BetaBadge(),
    ],
  );
}

/// Small, always-visible marker that this build is the external-test cohort
/// (see game/game_config.dart#testCohort), with a tap target explaining what
/// data collection this implies. Never collects personal information.
class _BetaBadge extends StatelessWidget {
  const _BetaBadge();

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: const Key('beta-badge'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showAboutTest(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x33D6B25E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withValues(alpha: .5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 12, color: Color(0xFFD6B25E)),
            const SizedBox(width: 4),
            Text(
              '外部テストβ　ルール ${NineJudgesConfig.rulesVersion}',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFD6B25E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _showAboutTest(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テストについて'),
        content: const Text(
          'このビルドは外部テストβです。ルール1.2の遊びやすさを確認するため、'
          '対局ログと匿名のフィードバック（評価・感想）をゲーム改善の目的でのみ収集します。\n\n'
          '氏名・メールアドレス・IPアドレスなど、個人を特定できる情報の入力は求めません。'
          'フィードバックの送信は結果画面で任意に選べます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

/// Titled panel that groups related controls so the menu reads as a few tidy
/// blocks instead of one long list.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    decoration: BoxDecoration(
      color: const Color(0xE6141019),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.accent.withValues(alpha: .28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 2),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD6B25E),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class _CpuOptions extends StatelessWidget {
  const _CpuOptions({
    required this.faction,
    required this.firstPlayer,
    required this.level,
    required this.onFaction,
    required this.onFirstPlayer,
    required this.onLevel,
  });

  final FactionSelection faction;
  final FirstPlayerSelection firstPlayer;
  final CpuLevel level;
  final ValueChanged<FactionSelection> onFaction;
  final ValueChanged<FirstPlayerSelection> onFirstPlayer;
  final ValueChanged<CpuLevel> onLevel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _FieldLabel('陣営'),
      SegmentedButton<FactionSelection>(
        key: const Key('faction-selector'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: FactionSelection.savior, label: Text('救済者')),
          ButtonSegment(value: FactionSelection.executor, label: Text('執行者')),
          ButtonSegment(value: FactionSelection.random, label: Text('ランダム')),
        ],
        selected: {faction},
        onSelectionChanged: (v) => onFaction(v.first),
      ),
      const SizedBox(height: 12),
      const _FieldLabel('先攻'),
      SegmentedButton<FirstPlayerSelection>(
        key: const Key('first-player-selector'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: FirstPlayerSelection.human, label: Text('自分')),
          ButtonSegment(value: FirstPlayerSelection.cpu, label: Text('CPU')),
          ButtonSegment(
            value: FirstPlayerSelection.random,
            label: Text('ランダム'),
          ),
        ],
        selected: {firstPlayer},
        onSelectionChanged: (v) => onFirstPlayer(v.first),
      ),
      const SizedBox(height: 12),
      const _FieldLabel('思考パターン'),
      Wrap(
        key: const Key('cpu-level-selector'),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in CpuLevel.values)
            ChoiceChip(
              key: Key('cpu-level-${option.name}'),
              label: Text(option.uiLabel),
              selected: level == option,
              onSelected: (_) => onLevel(option),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '${level.strategyLabel}：${level.description}',
        key: const Key('cpu-level-description'),
        style: const TextStyle(fontSize: 12, color: Colors.white60),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: Colors.white70,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: buttonKey,
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFE7DBC0),
      side: BorderSide(color: AppTheme.accent.withValues(alpha: .4)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
    ),
    icon: Icon(icon, size: 18),
    label: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
