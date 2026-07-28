import 'package:dead_or_alive/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

abstract final class FirebaseBootstrap {
  static bool available = false;
  static String? error;

  /// Connects to the real "nine-verdicts" Firebase project via the options
  /// generated in lib/firebase_options.dart. `Firebase.initializeApp()`
  /// with no options only auto-configures on Firebase Hosting's reserved
  /// `/__/firebase/init.js` URL, which this app (deployed to GitHub Pages)
  /// never has — passing `options:` explicitly is what makes this work
  /// outside Firebase Hosting.
  ///
  /// Any failure here (unreachable project, disabled anonymous auth, no
  /// network, etc.) is swallowed: [available] stays false and the app keeps
  /// working entirely off local Hive storage — see [NineJudgesController]/
  /// LocalGameLogRepository, which never depend on Firebase.
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAuth.instance.signInAnonymously();
      available = true;
      error = null;
    } catch (exception) {
      available = false;
      error = exception.toString();
    }
  }

  static String? get uid =>
      available ? FirebaseAuth.instance.currentUser?.uid : null;
}
