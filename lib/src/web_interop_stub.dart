abstract final class WebInterop._() {
  static void updateSplashProgress(
    double initialPercent,
    double targetPercent, [
    double minMs = 20,
    double maxMs = 80,
  ]) {}

  static void completeSplash() {}

  static void stopActiveAudio() {}

  static void warmUpActiveAudio() {}

  static String? getStorageItem(String key) => null;

  static void setStorageItem(String key, String value) {}

  static void removeStorageItem(String key) {}

  static String? getCurrentOrigin() => null;

  static String? getCurrentHref() => null;

  static void openExternalUrl(String url) {}

  static bool downloadTextFile({
    required String filename,
    required String content,
    String mimeType = 'text/plain;charset=utf-8',
  }) => false;

  static Future<({String name, String content})?> pickTextFile({String accept = '.csv,.json'}) =>
      Future<({String name, String content})?>.value(null);
}

/// Pemutar audio non-web (stub untuk pengujian widget VM).
final class WebAudioEngine({
  required String assetPath,
  bool loop = false,
  final void Function(bool isPlaying)? onPlayingChanged,
  final void Function(double progress)? onProgressChanged,
  final void Function()? onEnded,
}) {
  bool _isPlaying = false;
  double _progress = 0.0;
  bool _hasEnded = false;
  bool _disposed = false;

  bool get isPlaying => _isPlaying;
  double get progress => _progress;

  void play() {
    if (_disposed) return;
    if (_hasEnded) {
      _hasEnded = false;
      _progress = 0.0;
      onProgressChanged?.call(0.0);
    }
    if (!_isPlaying) {
      _isPlaying = true;
      onPlayingChanged?.call(true);
    }
  }

  void pause() {
    if (_disposed) return;
    if (_isPlaying) {
      _isPlaying = false;
      onPlayingChanged?.call(false);
    }
  }

  void replay() {
    if (_disposed) return;
    _hasEnded = false;
    _progress = 0.0;
    onProgressChanged?.call(0.0);
    _isPlaying = true;
    onPlayingChanged?.call(true);
  }

  /// Hanya untuk simulasi akhir lagu pada pengujian VM.
  void debugCompleteTrack() {
    if (_disposed) return;
    _hasEnded = true;
    _progress = 1.0;
    onProgressChanged?.call(1.0);
    if (_isPlaying) {
      _isPlaying = false;
      onPlayingChanged?.call(false);
    }
    onEnded?.call();
  }

  void dispose() {
    _disposed = true;
    _isPlaying = false;
  }
}
