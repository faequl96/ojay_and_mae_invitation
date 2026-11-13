abstract final class WebInterop._() {
  static void updateSplashProgress(
    double initialPercent,
    double targetPercent, [
    double minMs = 20,
    double maxMs = 80,
  ]) {}

  static void completeSplash() {}

  static String? getStorageItem(String key) => null;

  static void setStorageItem(String key, String value) {}
}
