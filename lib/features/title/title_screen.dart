import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../game/application/game_controller.dart';
import '../game/domain/enums.dart';

/// タイトル画面（Ver.0.4）。対戦モードとプレイヤーAの陣営を選んで開始する。
class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key});

  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen> {
  bool _vsCpu = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.balance,
                    size: 56,
                    color: AppTheme.accent.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'NINE VERDICTS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: AppTheme.good,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '9人の審判',
                    style: TextStyle(fontSize: 15, color: AppTheme.neutral),
                  ),
                  const SizedBox(height: 24),

                  // モード選択。
                  _modeToggle(),
                  const SizedBox(height: 20),

                  Text(
                    _vsCpu ? 'あなた（プレイヤーA）の陣営を選んで開始' : 'プレイヤーAの陣営を選んで開始',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFCFC7B5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _startButton(
                    icon: Icons.shield_moon,
                    color: AppTheme.alive,
                    label: 'Aが救済者で開始',
                    faction: Faction.savior,
                  ),
                  const SizedBox(height: 12),
                  _startButton(
                    icon: Icons.gavel,
                    color: AppTheme.evil,
                    label: 'Aが執行者で開始',
                    faction: Faction.executioner,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '救済者：善人と中立を生かし、悪人を殺す。\n執行者：悪人を生かし、善人と中立を殺す。\n各カードの得点を最終状態で取り合い、高い方が勝ち。',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A9384),
                      height: 1.6,
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

  Widget _modeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [_modeChip('CPU対戦', true), _modeChip('2人対戦', false)],
      ),
    );
  }

  Widget _modeChip(String label, bool cpu) {
    final active = _vsCpu == cpu;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vsCpu = cpu),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active ? AppTheme.accent : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.black : const Color(0xFFB9B2A2),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _startButton({
    required IconData icon,
    required Color color,
    required String label,
    required Faction faction,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: () {
          ref
              .read(gameControllerProvider.notifier)
              .startGame(faction, vsCpu: _vsCpu);
          context.go(AppRoutes.game);
        },
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
