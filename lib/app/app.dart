import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// アプリのルート Widget。
class DeadOrAliveApp extends StatelessWidget {
  const DeadOrAliveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DEAD OR ALIVE（仮）',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: appRouter,
    );
  }
}
