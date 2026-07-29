import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/online/online_lobby_screen.dart';
import 'package:dead_or_alive/features/nine_judges/rules/rules_guide_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/download_center_screen.dart';
import 'package:dead_or_alive/features/nine_judges/tutorial/tutorial_screen.dart';
import 'package:flutter/material.dart';

/// One-screen "title screen": hero art, quick settings, start button, submenu
/// and the reserved bottom-nav icons all fit within the viewport with no
/// scrolling, so a first-time player sees the whole game — world, setup,
/// start — within the first screen. Section heights below are relative
/// (`Expanded` flex) rather than fixed pixels so this holds on any device,
/// from iPhone SE up.
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 27, child: _HeroArea()),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 25,
                    child: _QuickSettingsArea(
                      mode: mode,
                      faction: faction,
                      firstPlayer: firstPlayer,
                      level: level,
                      onMode: (v) => setState(() => mode = v),
                      onFaction: (v) => setState(() => faction = v),
                      onFirstPlayer: (v) => setState(() => firstPlayer = v),
                      onLevel: (v) => setState(() => level = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 15,
                    child: _MainActionArea(
                      onStart: () => widget.onStart(
                        NineJudgesGameSettings(
                          mode: mode,
                          cpuLevel: level,
                          factionSelection: faction,
                          firstPlayerSelection: firstPlayer,
                        ),
                      ),
                      onOpenOnline: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OnlineLobbyScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 15,
                    child: _SubMenuArea(onOpenLogs: widget.onOpenLogs),
                  ),
                  const SizedBox(height: 8),
                  const Expanded(flex: 10, child: _ComingSoonRow()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section ①: hero art (savior VS executor + logo) filling ~25-30% of the
/// screen, with the game title (kept as real text for accessibility/tests —
/// the wordmark in the image itself is not readable by screen readers) and
/// the beta badge folded into a slim caption strip under the artwork instead
/// of taking their own separate rows.
class _HeroArea extends StatelessWidget {
  const _HeroArea();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/branding/menu_hero.png',
            fit: BoxFit.cover,
            width: double.infinity,
            semanticLabel: '9人の審判 NINE VERDICTS',
          ),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          const Text(
            '9人の審判',
            style: TextStyle(
              color: Color(0xFFD6B25E),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          const _BetaBadge(),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x33D6B25E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withValues(alpha: .5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 11, color: Color(0xFFD6B25E)),
            const SizedBox(width: 4),
            Text(
              '外部テストβ　ルール ${NineJudgesConfig.rulesVersion}',
              style: const TextStyle(
                fontSize: 9,
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

/// Section ②: game mode / faction / first-player / CPU level, laid out as
/// slim single-line rows (label to the left, control to the right) instead
/// of the old label-above-control blocks, to fit a tight height budget.
class _QuickSettingsArea extends StatelessWidget {
  const _QuickSettingsArea({
    required this.mode,
    required this.faction,
    required this.firstPlayer,
    required this.level,
    required this.onMode,
    required this.onFaction,
    required this.onFirstPlayer,
    required this.onLevel,
  });

  final GameMode mode;
  final FactionSelection faction;
  final FirstPlayerSelection firstPlayer;
  final CpuLevel level;
  final ValueChanged<GameMode> onMode;
  final ValueChanged<FactionSelection> onFaction;
  final ValueChanged<FirstPlayerSelection> onFirstPlayer;
  final ValueChanged<CpuLevel> onLevel;

  @override
  Widget build(BuildContext context) => _CompactCard(
    child: SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<GameMode>(
            key: const Key('game-mode-selector'),
            style: _compactSegmentStyle,
            segments: const [
              ButtonSegment(
                value: GameMode.cpu,
                icon: _MenuIcon('icon_cpu'),
                label: Text('CPU対戦'),
              ),
              ButtonSegment(
                value: GameMode.hotseat,
                icon: _MenuIcon('icon_hotseat'),
                label: Text('2人対戦'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (value) => onMode(value.first),
          ),
          if (mode == GameMode.cpu) ...[
            const SizedBox(height: 8),
            _CompactRow(
              label: '陣営',
              icon: 'icon_faction',
              child: SegmentedButton<FactionSelection>(
                key: const Key('faction-selector'),
                style: _compactSegmentStyle,
                showSelectedIcon: false,
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
                    icon: _MenuIcon('icon_shuffle'),
                    label: Text('ランダム'),
                  ),
                ],
                selected: {faction},
                onSelectionChanged: (v) => onFaction(v.first),
              ),
            ),
            const SizedBox(height: 6),
            _CompactRow(
              label: '先攻',
              icon: 'icon_firstplayer',
              child: SegmentedButton<FirstPlayerSelection>(
                key: const Key('first-player-selector'),
                style: _compactSegmentStyle,
                showSelectedIcon: false,
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
                    icon: _MenuIcon('icon_shuffle'),
                    label: Text('ランダム'),
                  ),
                ],
                selected: {firstPlayer},
                onSelectionChanged: (v) => onFirstPlayer(v.first),
              ),
            ),
            const SizedBox(height: 6),
            _CompactRow(
              label: 'AI思考',
              icon: 'icon_ai',
              child: _CpuLevelDropdown(
                level: level,
                onChanged: onLevel,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Small line-art icon cropped from the official key-visual menu mockup,
/// with its dark background keyed out to alpha so it composites cleanly
/// against this screen's own dark panels.
class _MenuIcon extends StatelessWidget {
  const _MenuIcon(this.name, {this.size = 15});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/menu/$name.png',
    width: size,
    height: size,
  );
}

final ButtonStyle _compactSegmentStyle = SegmentedButton.styleFrom(
  visualDensity: VisualDensity.compact,
  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
  padding: const EdgeInsets.symmetric(horizontal: 6),
  minimumSize: const Size(0, 32),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Label-left, control-right single line, so each setting costs one row
/// instead of two.
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.label, required this.icon, required this.child});
  final String label;
  final String icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 52,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuIcon(icon, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(child: child),
    ],
  );
}

/// Compact single-line CPU level picker (mockup shows this as a pill with
/// the current value + chevron, not five wrapped chips).
class _CpuLevelDropdown extends StatelessWidget {
  const _CpuLevelDropdown({required this.level, required this.onChanged});
  final CpuLevel level;
  final ValueChanged<CpuLevel> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('cpu-level-selector'),
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF0E0C14),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.accent.withValues(alpha: .3)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<CpuLevel>(
        key: const Key('cpu-level-dropdown'),
        value: level,
        isDense: true,
        isExpanded: true,
        icon: const Icon(Icons.expand_more, size: 16, color: Colors.white70),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE7DBC0),
        ),
        dropdownColor: const Color(0xFF141019),
        items: [
          for (final option in CpuLevel.values)
            DropdownMenuItem(
              key: Key('cpu-level-${option.name}'),
              value: option,
              child: Text(
                '${option.strategyLabel}（${option.uiLabel}）',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    ),
  );
}

/// Section ③: the single most important tap target on the screen. The
/// corner flourishes are cropped from the official mockup's "ゲーム開始"
/// button; the gold gradient/border approximates the same ornate frame
/// while staying a real, resizable Material button underneath.
class _MainActionArea extends StatelessWidget {
  const _MainActionArea({required this.onStart, required this.onOpenOnline});
  final VoidCallback onStart;
  final VoidCallback onOpenOnline;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Expanded(
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B5324), Color(0xFF3A2C10)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: .8),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: .35),
                  blurRadius: 14,
                ),
              ],
            ),
            child: InkWell(
              key: const Key('start-game'),
              borderRadius: BorderRadius.circular(30),
              onTap: onStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _MenuIcon('ornament_left', size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'ゲーム開始',
                      style: TextStyle(
                        color: Color(0xFFF3E6C4),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _MenuIcon('ornament_right', size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 36,
        child: OutlinedButton.icon(
          key: const Key('open-online'),
          onPressed: onOpenOnline,
          style: OutlinedButton.styleFrom(
            textStyle: const TextStyle(fontSize: 12),
            padding: EdgeInsets.zero,
            foregroundColor: const Color(0xFFC79EF0),
            side: const BorderSide(color: Color(0xFFC79EF0)),
          ),
          icon: const Icon(Icons.public, size: 16),
          label: const Text('オンライン対戦 β'),
        ),
      ),
    ],
  );
}

/// Section ④: 遊び方/チュートリアル/ダウンロード/プレイログ as a single row of
/// compact icon tiles instead of a 2×2 grid, to halve the vertical footprint.
class _SubMenuArea extends StatelessWidget {
  const _SubMenuArea({required this.onOpenLogs});
  final VoidCallback? onOpenLogs;

  @override
  Widget build(BuildContext context) => _CompactCard(
    child: Row(
      children: [
        Expanded(
          child: _MenuIconTile(
            buttonKey: const Key('open-rules'),
            iconAsset: 'icon_howto',
            label: '遊び方',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const RulesGuideScreen()),
            ),
          ),
        ),
        Expanded(
          child: _MenuIconTile(
            buttonKey: const Key('open-tutorial'),
            iconAsset: 'icon_tutorial',
            label: 'チュートリアル',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const TutorialScreen()),
            ),
          ),
        ),
        Expanded(
          child: _MenuIconTile(
            buttonKey: const Key('open-play-logs'),
            iconAsset: 'icon_playlog',
            label: 'プレイログ',
            onTap: onOpenLogs,
          ),
        ),
        Expanded(
          child: _MenuIconTile(
            buttonKey: const Key('open-downloads'),
            iconAsset: 'icon_download',
            label: 'ダウンロード',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const DownloadCenterScreen(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MenuIconTile extends StatelessWidget {
  const _MenuIconTile({
    required this.buttonKey,
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final Key buttonKey;
  final String iconAsset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: buttonKey,
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuIcon(iconAsset, size: 19),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE7DBC0),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Section ⑤: 履歴/ランキング/実績/クレジット — reserved for future features,
/// per the official menu key visual. Each opens a short "準備中" notice for
/// now so the icon row is real and tappable without implying data that
/// doesn't exist yet.
class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow();

  static const _items = [
    (key: 'history', iconAsset: 'icon_history', label: '履歴'),
    (key: 'ranking', iconAsset: 'icon_ranking', label: 'ランキング'),
    (key: 'achievements', iconAsset: 'icon_achievements', label: '実績'),
    (key: 'credits', iconAsset: 'icon_credits', label: 'クレジット'),
  ];

  void _showComingSoon(BuildContext context, String label) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: const Text('この機能は準備中です。今後のアップデートで追加予定です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (final item in _items)
        InkWell(
          key: Key('coming-soon-${item.key}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showComingSoon(context, item.label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuIcon(item.iconAsset, size: 17),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.accent.withValues(alpha: .7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

/// Slim bordered container replacing the old titled `_SectionCard` — no
/// section heading, ~40% less padding, so more of the screen goes to
/// controls rather than chrome.
class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xE6141019),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.accent.withValues(alpha: .28)),
    ),
    child: child,
  );
}
