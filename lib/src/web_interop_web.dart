import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

@JS('updateSplashProgress')
external JSPromise<JSAny?>? _jsUpdateSplashProgress(
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

@JS('__ojayMaeActiveAudio')
external _JSAudio? get _globalActiveAudio;

@JS('__ojayMaeActiveAudio')
external set _globalActiveAudio(_JSAudio? audio);

@JS('Audio')
extension type _JSAudio._(JSObject _) implements JSObject {
  external new([String src]);
  external String src;
  external String preload;
  external bool loop;
  external bool muted;
  external double currentTime;
  external double get duration;
  external bool get paused;
  external bool get ended;
  external int get readyState;
  external JSPromise<JSAny?>? play();
  external void pause();
  external void load();
  external void removeAttribute(String qualifiedName);
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

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

  /// Menghentikan pemutar audio lama yang masih tersisa di JS (mis. saat Hot Restart).
  static void stopActiveAudio() {
    try {
      final active = _globalActiveAudio;
      if (active != null) {
        active
          ..pause()
          ..muted = true
          ..removeAttribute('src')
          ..load();
        _globalActiveAudio = null;
      }
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

/// Pemutar audio HTML5 yang kompatibel dengan Skwasm (`--wasm`) & content-hash assets.
final class WebAudioEngine({
  required String assetPath,
  bool loop = false,
  final void Function(bool isPlaying)? onPlayingChanged,
  final void Function(double progress)? onProgressChanged,
  final void Function()? onEnded,
}) {
  this {
    // Pastikan tidak ada elemen <audio> yatim dari sesi sebelum Hot Restart.
    WebInterop.stopActiveAudio();

    final resolvedUrl = ui_web.assetManager.getAssetUrl(assetPath);
    final audio = _JSAudio(resolvedUrl)
      ..preload = 'metadata'
      ..loop = loop;
    _audio = audio;
    _globalActiveAudio = audio;

    _onPlayJs = ((JSAny? _) {
      if (!_disposed) _setPlaying(true);
    }).toJS;
    _onPauseJs = ((JSAny? _) {
      if (_disposed || audio.ended) return;
      _setPlaying(false);
    }).toJS;
    _onEndedJs = ((JSAny? _) {
      if (_disposed) return;
      _isPlaying = false;
      _setProgress(1.0);
      onEnded?.call();
    }).toJS;
    _onTimeUpdateJs = ((JSAny? _) {
      if (_disposed) return;
      final duration = audio.duration;
      final current = audio.currentTime;
      if (duration.isFinite && duration > 0.0 && current.isFinite) {
        _setProgress((current / duration).clamp(0.0, 1.0));
      }
    }).toJS;
    _onErrorJs = ((JSAny? _) {
      if (!_disposed) _setPlaying(false);
    }).toJS;

    audio
      ..addEventListener('play', _onPlayJs)
      ..addEventListener('pause', _onPauseJs)
      ..addEventListener('ended', _onEndedJs)
      ..addEventListener('timeupdate', _onTimeUpdateJs)
      ..addEventListener('error', _onErrorJs);
  }

  late final _JSAudio _audio;
  late final JSFunction _onPlayJs;
  late final JSFunction _onPauseJs;
  late final JSFunction _onEndedJs;
  late final JSFunction _onTimeUpdateJs;
  late final JSFunction _onErrorJs;

  bool _isPlaying = false;
  double _progress = 0.0;
  bool _disposed = false;

  bool get isPlaying => _isPlaying;
  double get progress => _progress;

  void _setPlaying(bool next) {
    if (_isPlaying == next) return;
    _isPlaying = next;
    onPlayingChanged?.call(next);
  }

  void _setProgress(double next) {
    if ((_progress - next).abs() < 0.002 && next != 0.0 && next != 1.0) return;
    _progress = next;
    onProgressChanged?.call(next);
  }

  void play() {
    if (_disposed) return;
    try {
      if (_audio.ended) {
        _audio.currentTime = 0.0;
        _setProgress(0.0);
      }
      final promise = _audio.play();
      if (promise != null) {
        unawaited(
          promise.toDart.then<void>(
            (_) {
              if (_disposed) return;
              if (_audio.ended) {
                _isPlaying = false;
                onEnded?.call();
              } else {
                _setPlaying(!_audio.paused);
              }
            },
            onError: (Object _) {
              if (!_disposed) _setPlaying(false);
            },
          ),
        );
      }
    } catch (_) {
      _setPlaying(false);
    }
  }

  void pause() {
    if (_disposed) return;
    try {
      _audio.pause();
    } catch (_) {}
    _setPlaying(false);
  }

  void replay() {
    if (_disposed) return;
    try {
      if (_audio.readyState > 0) {
        _audio.currentTime = 0.0;
      }
    } catch (_) {}
    _setProgress(0.0);
    play();
  }

  /// Hanya untuk simulasi akhir lagu pada pengujian VM (stub).
  void debugCompleteTrack() {}

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      _audio
        ..pause()
        ..muted = true
        ..removeEventListener('play', _onPlayJs)
        ..removeEventListener('pause', _onPauseJs)
        ..removeEventListener('ended', _onEndedJs)
        ..removeEventListener('timeupdate', _onTimeUpdateJs)
        ..removeEventListener('error', _onErrorJs)
        ..removeAttribute('src')
        ..load();
      if (_globalActiveAudio == _audio) {
        _globalActiveAudio = null;
      }
    } catch (_) {}
    _isPlaying = false;
  }
}
