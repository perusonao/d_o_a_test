import 'dart:math';

import 'package:dead_or_alive/app/theme.dart';
import 'package:dead_or_alive/features/nine_judges/game/game_config.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';
import 'package:dead_or_alive/features/nine_judges/online/online_lobby_screen.dart';
import 'package:dead_or_alive/features/nine_judges/rules/rules_guide_screen.dart';
import 'package:dead_or_alive/features/nine_judges/screens/download_center_screen.dart';
import 'package:dead_or_alive/features/nine_judges/tutorial/tutorial_screen.dart';
import 'package:dead_or_alive/features/nine_judges/widgets/game_style.dart';
import 'package:flutter/material.dart';

/// Title screen: hero art (with the full 9-judge key visual), quick
/// settings, start button, submenu and the reserved bottom-nav icons. The
/// hero and both action buttons are sized by their own cropped artwork's
/// aspect ratio (not stretched/cropped to a fixed flex box), so nothing gets
/// clipped and buttons stay proportioned like the source mockup. On most
/// phones everything still fits without scrolling; the outer
/// `SingleChildScrollView` is a safety net for the smallest screens now that
/// the hero includes the taller judge-bust artwork.
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
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroArea(),
                  const SizedBox(height: 8),
                  _QuickSettingsArea(
                    mode: mode,
                    faction: faction,
                    firstPlayer: firstPlayer,
                    level: level,
                    onMode: (v) => setState(() => mode = v),
                    onFaction: (v) => setState(() => faction = v),
                    onFirstPlayer: (v) => setState(() => firstPlayer = v),
                    onLevel: (v) => setState(() => level = v),
                  ),
                  const SizedBox(height: 10),
                  _MainActionArea(
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
                  const SizedBox(height: 8),
                  _SubMenuArea(onOpenLogs: widget.onOpenLogs),
                  const SizedBox(height: 8),
                  const _ComingSoonRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section ①: hero art (savior VS executor + logo + the 9-judge bust row),
/// sized by the cropped artwork's own aspect ratio so nothing gets clipped —
/// unlike a fixed-height box with `BoxFit.cover`, which cropped into the
/// title text on some screens. The game title is also kept as real text
/// (accessibility/tests — the wordmark in the image itself isn't readable by
/// screen readers), folded into a slim caption strip under the artwork
/// alongside the beta badge instead of taking its own separate row.
class _HeroArea extends StatefulWidget {
  const _HeroArea();

  @override
  State<_HeroArea> createState() => _HeroAreaState();
}

class _HeroAreaState extends State<_HeroArea> with TickerProviderStateMixin {
  static const _aspectRatio = 853 / 895;

  // Section ⑦: additions-only cinematic layer over the static hero art —
  // slow ambient particles and a gently swaying balance icon, so the title
  // screen reads as a living backdrop rather than a still image. Both loop
  // continuously but paint only a handful of simple shapes, so they stay
  // cheap enough to never compete with input handling (section ⑩).
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ambient.dispose();
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: Stack(
            children: [
              Image.asset(
                'assets/branding/menu_hero.png',
                fit: BoxFit.cover,
                width: double.infinity,
                semanticLabel: '9人の審判 NINE VERDICTS - 善人を救い、悪人を裁け。',
              ),
              // 救済者側は光、執行者側は闇 — a very soft static tint split,
              // layered over the artwork without changing it.
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0x33F2E0A8),
                          Colors.transparent,
                          Color(0x40140A24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _ambient,
                    builder: (context, _) => CustomPaint(
                      painter: _HeroParticlePainter(progress: _ambient.value),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.6),
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _sway,
                    builder: (context, _) => Transform.rotate(
                      angle: (_sway.value - 0.5) * 0.12,
                      child: Icon(
                        Icons.balance,
                        size: 30,
                        color: Colors.white.withValues(alpha: 0.26),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

/// A handful of faint motes drifting slowly upward and looping — the hero's
/// ambient "light particle" layer (section ⑦). Deliberately cheap: a fixed
/// small count of plain circles, repainted from one [progress] value.
class _HeroParticlePainter extends CustomPainter {
  _HeroParticlePainter({required this.progress});
  final double progress;

  static final List<_Mote> _motes = [
    for (var i = 0; i < 14; i++) _Mote(Random(i * 104729 + 7)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final mote in _motes) {
      final t = (progress * mote.speed + mote.phase) % 1.0;
      final dx = mote.x * size.width;
      final dy = size.height * (1 - t);
      final fade = t < 0.12
          ? t / 0.12
          : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
      final opacity = fade.clamp(0.0, 1.0) * 0.45;
      canvas.drawCircle(
        Offset(dx, dy),
        mote.radius,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Mote {
  _Mote(Random random)
    : x = random.nextDouble(),
      phase = random.nextDouble(),
      speed = 0.6 + random.nextDouble() * 0.5,
      radius = 1 + random.nextDouble() * 1.6;

  final double x;
  final double phase;
  final double speed;
  final double radius;
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

/// Section ③: the single most important tap target on the screen. Both
/// buttons are the actual button artwork cropped from the official mockup
/// (border, glow, corner flourishes and label all baked in), sized by that
/// artwork's own aspect ratio rather than stretched to fill space — that's
/// what was making the "ゲーム開始" button look oversized before.
class _MainActionArea extends StatelessWidget {
  const _MainActionArea({required this.onStart, required this.onOpenOnline});
  final VoidCallback onStart;
  final VoidCallback onOpenOnline;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _MockupButton(
        buttonKey: const Key('start-game'),
        asset: 'assets/icons/menu/btn_start.png',
        aspectRatio: 795 / 125,
        semanticLabel: 'ゲーム開始',
        onTap: onStart,
        // Section ⑥: the single most important tap target gets a gentle
        // idle "heartbeat" pulse, and a gold glow + ripple + slight sink on
        // press — the artwork itself is untouched, only layered on top.
        pulse: true,
        glowColor: GameColors.gold,
      ),
      const SizedBox(height: 8),
      _MockupButton(
        buttonKey: const Key('open-online'),
        asset: 'assets/icons/menu/btn_online.png',
        aspectRatio: 795 / 80,
        semanticLabel: 'オンライン対戦 β',
        onTap: onOpenOnline,
        // Section ⑥: a persistent, soft purple glow (rather than the start
        // button's pulse) plus a small β badge marking it as still in beta.
        glowColor: GameColors.executor,
        glowBaseAlpha: 0.28,
        badge: 'β',
      ),
    ],
  );
}

/// A button whose entire visual (background, border, glow, label) is the
/// artwork cropped straight from the official mockup, wrapped in a real tap
/// target sized to match. Section ⑥ layers a few lightweight, purely
/// decorative animations on top — an optional idle pulse, a press-triggered
/// glow/sink, and an optional badge — without altering that artwork.
class _MockupButton extends StatefulWidget {
  const _MockupButton({
    required this.buttonKey,
    required this.asset,
    required this.aspectRatio,
    required this.semanticLabel,
    required this.onTap,
    this.pulse = false,
    this.glowColor,
    this.glowBaseAlpha = 0,
    this.badge,
  });

  final Key buttonKey;
  final String asset;
  final double aspectRatio;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool pulse;
  final Color? glowColor;
  final double glowBaseAlpha;
  final String? badge;

  @override
  State<_MockupButton> createState() => _MockupButtonState();
}

class _MockupButtonState extends State<_MockupButton>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  @override
  void dispose() {
    _idle.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Image.asset(widget.asset, fit: BoxFit.fill),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _press]),
      builder: (context, child) {
        final heartbeat = widget.pulse
            ? 1 + 0.025 * Curves.easeInOut.transform(_idle.value)
            : 1.0;
        final sink = 1 - 0.04 * _press.value;
        final glowColor = widget.glowColor;
        return Transform.scale(
          scale: heartbeat * sink,
          child: Container(
            decoration: glowColor == null
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(
                          alpha: widget.glowBaseAlpha + 0.4 * _press.value,
                        ),
                        blurRadius: 16 + 14 * _press.value,
                        spreadRadius: 1 + 2 * _press.value,
                      ),
                    ],
                  ),
            child: child,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: widget.buttonKey,
              borderRadius: BorderRadius.circular(30),
              onTapDown: (_) => _press.forward(),
              onTapCancel: () => _press.reverse(),
              onTap: () {
                _press.reverse();
                widget.onTap();
              },
              child: button,
            ),
          ),
          if (widget.badge != null)
            Positioned(
              top: -6,
              right: 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: GameColors.executor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: GameColors.executor.withValues(alpha: .6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    widget.badge!,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
