import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../game/application/game_controller.dart';
import '../game/domain/enums.dart';

/// 陣営選択画面。プレイヤーが善人/悪人を選ぶ。CPU は自動で反対陣営になる。
class FactionSelectScreen extends ConsumerWidget {
  const FactionSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('陣営を選択')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'あなたの陣営を選んでください',
                    style: TextStyle(fontSize: 16, color: Color(0xFFCFC7B5)),
                  ),
                  const SizedBox(height: 20),
                  _FactionCard(
                    icon: Icons.balance,
                    color: AppTheme.good,
                    title: '善人陣営',
                    description:
                        '終了時に「生存している善人」を「生存している悪人」より多くすれば勝利。\n中立を死亡させるとペナルティ。',
                    onTap: () => _start(context, ref, Faction.good),
                  ),
                  const SizedBox(height: 16),
                  _FactionCard(
                    icon: Icons.local_fire_department,
                    color: AppTheme.evil,
                    title: '悪人陣営',
                    description:
                        '終了時に「生存している悪人」が「生存している善人」以上なら勝利（引き分けも勝ち）。\n中立を生存させるとペナルティ。',
                    onTap: () => _start(context, ref, Faction.evil),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context, WidgetRef ref, Faction faction) {
    ref.read(gameControllerProvider.notifier).startGame(faction);
    context.go(AppRoutes.game);
  }
}

class _FactionCard extends StatelessWidget {
  const _FactionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.18), AppTheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Color(0xFFC9C2B2), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
