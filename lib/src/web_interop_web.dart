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

@JS('localStorage.removeItem')
external void _lsRemoveItem(String key);

@JS('window.location.origin')
external String get _windowOrigin;

@JS('window.location.href')
external String get _windowHref;

@JS('window.open')
external JSAny? _windowOpen(String url, String target, String features);

@JS('URL.createObjectURL')
external String _urlCreateObjectUrl(_JSBlob blob);

@JS('URL.revokeObjectURL')
external void _urlRevokeObjectUrl(String url);

@JS('document.createElement')
external _JSElement _docCreateElement(String tagName);

@JS('document.body')
external _JSElement? get _docBody;

@JS('Blob')
extension type _JSBlob._(JSObject _) implements JSObject {
  external new(JSArray<JSString> parts, JSObject options);
}

extension type _JSElementStyle._(JSObject _) implements JSObject {
  external set display(String value);
}

extension type _JSFile._(JSObject _) implements JSObject {
  external String get name;
  external JSPromise<JSString> text();
}

extension type _JSFileList._(JSObject _) implements JSObject {
  external int get length;
  external _JSFile? item(int index);
}

extension type _JSElement._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external set type(String value);
  external set accept(String value);
  external _JSElementStyle get style;
  external _JSFileList? get files;
  external void appendChild(_JSElement child);
  external void remove();
  external void click();
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

@JS('Object')
extension type _JSBlobOptions._(JSObject _) implements JSObject {
  external factory ({String type});
}

@JS('window.isSecureContext')
external bool? get _windowIsSecureContext;

@JS('window.ContactsManager')
external JSAny? get _windowContactsManager;

@JS('navigator.contacts')
external _JSContactsManager? get _navigatorContacts;

extension type _JSContactsManager._(JSObject _) implements JSObject {
  @JS('select')
  external JSAny? get _selectMember;

  external JSPromise<JSArray<_JSContactInfo>> select(
    JSArray<JSString> properties, [
    _JSContactSelectOptions? options,
  ]);
}

@JS('Object')
extension type _JSContactSelectOptions._(JSObject _) implements JSObject {
  external factory ({bool multiple});
}

extension type _JSContactInfo._(JSObject _) implements JSObject {
  external JSArray<JSString?>? get name;
  external JSArray<JSString?>? get tel;
}

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

  /// Mulai pre-buffer audio di latar belakang setelah aset kritikal selesai.
  static void warmUpActiveAudio() {
    try {
      final active = _globalActiveAudio;
      if (active != null && active.preload != 'auto') {
        active.preload = 'auto';
      }
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

  static void removeStorageItem(String key) {
    try {
      _lsRemoveItem(key);
    } catch (_) {}
  }

  static String? getCurrentOrigin() {
    try {
      final origin = _windowOrigin.trim();
      if (origin.isEmpty || origin == 'null') return null;
      return origin;
    } catch (_) {
      return null;
    }
  }

  static String? getCurrentHref() {
    try {
      final href = _windowHref.trim();
      if (href.isEmpty || href == 'null') return null;
      return href;
    } catch (_) {
      return null;
    }
  }

  static void openExternalUrl(String url) {
    try {
      _windowOpen(url, '_blank', 'noopener,noreferrer');
    } catch (_) {}
  }

  static bool downloadTextFile({
    required String filename,
    required String content,
    String mimeType = 'text/plain;charset=utf-8',
  }) {
    try {
      final blob = _JSBlob([content.toJS].toJS, _JSBlobOptions(type: mimeType));
      final objectUrl = _urlCreateObjectUrl(blob);
      final anchor = _docCreateElement('a')
        ..href = objectUrl
        ..download = filename
        ..style.display = 'none';
      _docBody?.appendChild(anchor);
      anchor.click();
      anchor.remove();
      Future<void>.delayed(const Duration(seconds: 2), () {
        try {
          _urlRevokeObjectUrl(objectUrl);
        } catch (_) {}
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<({String name, String content})?> pickTextFile({String accept = '.csv,.json'}) {
    final completer = Completer<({String name, String content})?>();
    try {
      final input = _docCreateElement('input')
        ..type = 'file'
        ..accept = accept
        ..style.display = 'none';

      late final JSFunction onChangeJs;
      late final JSFunction onCancelJs;

      void cleanup() {
        input
          ..removeEventListener('change', onChangeJs)
          ..removeEventListener('cancel', onCancelJs)
          ..remove();
      }

      onChangeJs = ((JSAny? _) {
        final files = input.files;
        final file = (files != null && files.length > 0) ? files.item(0) : null;
        if (file == null) {
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final filename = file.name.trim();
        unawaited(
          file.text().toDart.then<void>(
            (jsText) {
              cleanup();
              if (!completer.isCompleted) {
                completer.complete((name: filename, content: jsText.toDart));
              }
            },
            onError: (Object _) {
              cleanup();
              if (!completer.isCompleted) completer.complete(null);
            },
          ),
        );
      }).toJS;

      onCancelJs = ((JSAny? _) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;

      input
        ..addEventListener('change', onChangeJs)
        ..addEventListener('cancel', onCancelJs);
      _docBody?.appendChild(input);
      input.click();
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  static bool get isContactPickerSupported {
    try {
      if (_windowIsSecureContext == false) return false;
      final contacts = _navigatorContacts;
      return _windowContactsManager != null && contacts != null && contacts._selectMember != null;
    } catch (_) {
      return false;
    }
  }

  static Future<({String status, String name, List<String> phones})> pickPhoneContact() async {
    if (!isContactPickerSupported) {
      return (status: 'unsupported', name: '', phones: const <String>[]);
    }
    try {
      final contacts = _navigatorContacts;
      if (contacts == null) {
        return (status: 'unsupported', name: '', phones: const <String>[]);
      }
      final selected = await contacts
          .select(
            ['name'.toJS, 'tel'.toJS].toJS,
            _JSContactSelectOptions(multiple: false),
          )
          .toDart;
      final items = selected.toDart;
      if (items.isEmpty) {
        return (status: 'cancelled', name: '', phones: const <String>[]);
      }
      final first = items.first;
      final rawNames = first.name?.toDart ?? const <JSString?>[];
      var pickedName = '';
      for (final raw in rawNames) {
        final candidate = raw?.toDart.trim() ?? '';
        if (candidate.isNotEmpty) {
          pickedName = candidate;
          break;
        }
      }
      final rawTels = first.tel?.toDart ?? const <JSString?>[];
      final phones = <String>[
        for (final tel in rawTels)
          if ((tel?.toDart.trim() ?? '').isNotEmpty) tel!.toDart.trim(),
      ];
      return (status: 'picked', name: pickedName, phones: phones);
    } catch (error) {
      if (error.toString().contains('AbortError')) {
        return (status: 'cancelled', name: '', phones: const <String>[]);
      }
      return (status: 'failed', name: '', phones: const <String>[]);
    }
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
