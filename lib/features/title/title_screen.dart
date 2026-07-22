import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';

/// タイトル画面。
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

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
                  Icon(Icons.balance,
                      size: 64, color: AppTheme.accent.withValues(alpha: 0.9)),
                  const SizedBox(height: 16),
                  const Text(
                    'DEAD OR ALIVE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: AppTheme.good,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('（仮）',
                      style: TextStyle(fontSize: 16, color: AppTheme.neutral)),
                  const SizedBox(height: 8),
                  const Text(
                    '2人用 心理戦カードゲーム',
                    style: TextStyle(fontSize: 14, color: Color(0xFFB9B2A2)),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.factionSelect),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('ゲーム開始'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.rules),
                      icon: const Icon(Icons.menu_book),
                      label: const Text('ルール'),
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
