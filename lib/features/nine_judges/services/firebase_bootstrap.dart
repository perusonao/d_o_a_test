import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

abstract final class FirebaseBootstrap {
  static bool available = false;
  static String? error;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
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
