import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../game/application/game_controller.dart';
import '../game/domain/enums.dart';

/// 役割選択画面（Ver.0.3）。プレイヤーが救済者/執行者を選ぶ。
class FactionSelectScreen extends ConsumerWidget {
  const FactionSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('役割を選択')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('あなたの役割を選んでください',
                      style:
                          TextStyle(fontSize: 16, color: Color(0xFFCFC7B5))),
                  const SizedBox(height: 20),
                  _RoleCard(
                    icon: Icons.shield_moon,
                    color: AppTheme.alive,
                    title: '救済者',
                    description:
                        '中央9枚のうち「善人」を生存させて終えることが目的。\n'
                        '善人の生存＝2点、悪人・中立の死亡＝1点。',
                    onTap: () => _start(context, ref, Role.savior),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.gavel,
                    color: AppTheme.evil,
                    title: '執行者',
                    description:
                        '「善人」を死亡させて終えることが目的。\n'
                        '善人の死亡＝2点、悪人・中立の生存＝1点。',
                    onTap: () => _start(context, ref, Role.executioner),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '開始時、あなたと CPU はそれぞれ異なる3枚の正体だけを知っています。'
                    '相手の行動から、伏せられた正体を推理しましょう。',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF9A9384), height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _start(BuildContext context, WidgetRef ref, Role role) {
    ref.read(gameControllerProvider.notifier).startGame(role);
    context.go(AppRoutes.game);
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
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
            colors: [color.withValues(alpha: 0.16), AppTheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(width: 12),
                Text(title,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
            const SizedBox(height: 10),
            Text(description,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFC9C2B2), height: 1.4)),
          ],
        ),
      ),
    );
  }
}
