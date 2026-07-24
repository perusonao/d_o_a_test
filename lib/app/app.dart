import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

class DeadOrAliveApp extends StatelessWidget {
  const DeadOrAliveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9人の審判',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const NineJudgesGameScreen(),
    );
  }
}
