import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:ojay_and_mae_invitation/firebase_options.dart';

abstract final class FirebaseBootstrap._() {
  static Future<bool>? _initFuture;
  static bool _isReady = false;
  static bool _isUnsupportedPlatform = false;

  static bool get isReady => _isReady;

  static Future<bool> ensureInitialized() {
    if (_isReady) return Future<bool>.value(true);
    if (_isUnsupportedPlatform) return Future<bool>.value(false);
    return _initFuture ??= _init();
  }

  static Future<bool> _init() async {
    if (Firebase.apps.isNotEmpty) {
      _initFuture = null;
      return _isReady = true;
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      return _isReady = Firebase.apps.isNotEmpty;
    } on UnsupportedError {
      _isUnsupportedPlatform = true;
      return _isReady = false;
    } catch (error) {
      if (kIsWeb && kDebugMode) {
        debugPrint('FirebaseBootstrap init failed: $error');
      }
      return _isReady = false;
    } finally {
      _initFuture = null;
    }
  }
}
