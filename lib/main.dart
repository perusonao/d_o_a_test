import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/nine_judges/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(FirebaseBootstrap.initialize());
  runApp(const ProviderScope(child: NineVerdictsApp()));
}
