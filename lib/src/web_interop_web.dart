import 'dart:js_interop';

@JS('updateSplashProgress')
external JSPromise? _jsUpdateSplashProgress(
  double initialPercent,
  double targetPercent,
  double minMs,
  double maxMs,
);

@JS('completeSplash')
external void _jsCompleteSplash();

@JS('localStorage.getItem')
external String? _lsGetItem(String key);

@JS('localStorage.setItem')
external void _lsSetItem(String key, String value);

abstract final class WebInterop._() {
  static void updateSplashProgress(
    double initialPercent,
    double targetPercent, [
    double minMs = 20,
    double maxMs = 80,
  ]) {
    try {
      _jsUpdateSplashProgress(initialPercent, targetPercent, minMs, maxMs);
    } catch (_) {}
  }

  static void completeSplash() {
    try {
      _jsCompleteSplash();
    } catch (_) {}
  }

  static String? getStorageItem(String key) {
    try {
      return _lsGetItem(key);
    } catch (_) {
      return null;
    }
  }

  static void setStorageItem(String key, String value) {
    try {
      _lsSetItem(key, value);
    } catch (_) {}
  }
}
