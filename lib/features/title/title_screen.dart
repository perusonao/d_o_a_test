import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../game/application/game_controller.dart';
import '../game/domain/enums.dart';

/// タイトル画面（Ver.0.4）。プレイヤーAの陣営を選んで開始する。
class TitleScreen extends ConsumerWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Icon(Icons.balance,
                      size: 60, color: AppTheme.accent.withValues(alpha: 0.9)),
                  const SizedBox(height: 14),
                  const Text('DEAD OR ALIVE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: AppTheme.good)),
                  const SizedBox(height: 2),
                  const Text('（仮）',
                      style: TextStyle(fontSize: 15, color: AppTheme.neutral)),
                  const SizedBox(height: 8),
                  const Text('2人対戦 心理戦カードゲーム（同じ端末で交互に）',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFFB9B2A2))),
                  const SizedBox(height: 36),
                  const Text('プレイヤーAの陣営を選んで開始',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFFCFC7B5))),
                  const SizedBox(height: 12),
                  _startButton(
                    context,
                    ref,
                    icon: Icons.shield_moon,
                    color: AppTheme.alive,
                    label: 'Aが救済者で開始',
                    faction: Faction.savior,
                  ),
                  const SizedBox(height: 12),
                  _startButton(
                    context,
                    ref,
                    icon: Icons.gavel,
                    color: AppTheme.evil,
                    label: 'Aが執行者で開始',
                    faction: Faction.executioner,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '救済者：善人と中立を生かし、悪人を殺す。\n執行者：悪人を生かし、善人と中立を殺す。\n各カードの得点を最終状態で取り合い、高い方が勝ち。',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF9A9384), height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _startButton(
    BuildContext context,
    WidgetRef ref, {
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
          ref.read(gameControllerProvider.notifier).startGame(faction);
          context.go(AppRoutes.game);
        },
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
