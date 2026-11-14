abstract final class WebInterop._() {
  static void updateSplashProgress(
    double initialPercent,
    double targetPercent, [
    double minMs = 20,
    double maxMs = 80,
  ]) {}

  static void completeSplash() {}

  static void stopActiveAudio() {}

  static String? getStorageItem(String key) => null;

  static void setStorageItem(String key, String value) {}
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
