import 'package:dead_or_alive/features/nine_judges/screens/game_screen.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

class NineVerdictsApp extends StatelessWidget {
  const NineVerdictsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9人の審判 / Nine Verdicts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const NineJudgesGameScreen(),
    );
  }
}

@Deprecated('Use NineVerdictsApp. Kept to avoid breaking existing tests.')
typedef DeadOrAliveApp = NineVerdictsApp;
