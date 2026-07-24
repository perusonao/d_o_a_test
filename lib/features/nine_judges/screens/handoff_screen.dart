import 'package:flutter/material.dart';
import 'package:dead_or_alive/features/nine_judges/models/judge_models.dart';

class HandoffScreen extends StatelessWidget {
  const HandoffScreen({
    required this.nextPlayer,
    required this.onReady,
    super.key,
  });

  final Faction nextPlayer;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final color = nextPlayer == Faction.savior
        ? const Color(0xFF478BC1)
        : const Color(0xFFB74F49);
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_off_outlined, size: 68, color: color),
                  const SizedBox(height: 24),
                  const Text(
                    '端末を次のプレイヤーに\n渡してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '次の手番：${nextPlayer.label}',
                    style: TextStyle(color: color, fontSize: 17),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('handoff-ready'),
                      onPressed: onReady,
                      style: FilledButton.styleFrom(backgroundColor: color),
                      child: const Text('準備OK'),
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
