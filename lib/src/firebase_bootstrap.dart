import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

abstract final class FirebaseBootstrap._() {
  static Future<bool>? _initFuture;
  static bool _isReady = false;

  static bool get isReady => _isReady;

  static Future<bool> ensureInitialized() => _initFuture ??= _init();

  static Future<bool> _init() async {
    if (Firebase.apps.isNotEmpty) {
      return _isReady = true;
    }
    try {
      await Firebase.initializeApp();
      return _isReady = Firebase.apps.isNotEmpty;
    } catch (_) {
      return _isReady = false;
    }
  }
}
