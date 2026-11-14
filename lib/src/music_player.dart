import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ojay_and_mae_invitation/src/web_interop.dart';

/// Status pemutaran musik undangan.
enum MusicPlaybackState() {
  playing,
  paused,
  completed,
}

/// Pengendali pemutar musik undangan (Play, Pause, Replay, dan progres trek).
final class InvitationMusicController({String assetPath = defaultMusicAsset, bool loop = false}) {
  this {
    _engine = WebAudioEngine(
      assetPath: assetPath,
      loop: loop,
      onPlayingChanged: (playing) {
        if (playing) {
          _playbackState.value = .playing;
        } else if (_playbackState.value != .completed) {
          _playbackState.value = .paused;
        }
      },
      onProgressChanged: (value) => _progress.value = value,
      onEnded: () => _playbackState.value = .completed,
    );
  }

  static const String defaultMusicAsset = 'assets/musics/music.mp3';

  final ValueNotifier<MusicPlaybackState> _playbackState = ValueNotifier<MusicPlaybackState>(
    .paused,
  );
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  late final WebAudioEngine _engine;

  ValueListenable<MusicPlaybackState> get playbackStateListenable => _playbackState;
  ValueListenable<double> get progressListenable => _progress;

  MusicPlaybackState get playbackState => _playbackState.value;
  bool get isPlaying => _playbackState.value == .playing;
  bool get isCompleted => _playbackState.value == .completed;
  double get progress => _progress.value;

  void play() => _engine.play();

  void pause() => _engine.pause();

  void togglePlayPause() {
    switch (_playbackState.value) {
      case .playing:
        pause();
      case .paused:
        play();
      case .completed:
        replay();
    }
  }

  void replay() => _engine.replay();

  @visibleForTesting
  void debugCompleteTrack() => _engine.debugCompleteTrack();

  void dispose() {
    _engine.dispose();
    _playbackState.dispose();
    _progress.dispose();
  }
}

final class _MorphRepaintSignal() extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Cache tekstur GPU ringan agar seluruh fase morph & putaran DVD bebas blur shader,
/// gradient berulang, dan clip oval per-frame.
final class _DvdSpriteCache() {
  static const int _shadowNineSize = 64;
  static const int _shadowCircleSize = 96;
  static const int _sheenSize = 128;
  static const int _groovesSize = 160;
  static const int _discArtSize = 256;

  static const List<(double, Color)> _primaryCones = [
    (0.00, Colors.transparent),
    (0.04, Color.fromRGBO(96, 226, 255, 0.18)),
    (0.09, Color.fromRGBO(110, 236, 255, 0.44)),
    (0.14, Color.fromRGBO(216, 248, 255, 0.60)),
    (0.17, Color.fromRGBO(255, 255, 255, 0.74)),
    (0.21, Color.fromRGBO(236, 174, 255, 0.48)),
    (0.26, Color.fromRGBO(255, 218, 150, 0.28)),
    (0.33, Colors.transparent),
    (0.48, Colors.transparent),
    (0.54, Color.fromRGBO(96, 226, 255, 0.16)),
    (0.59, Color.fromRGBO(110, 236, 255, 0.38)),
    (0.64, Color.fromRGBO(216, 248, 255, 0.54)),
    (0.67, Color.fromRGBO(255, 255, 255, 0.66)),
    (0.71, Color.fromRGBO(236, 174, 255, 0.42)),
    (0.76, Color.fromRGBO(255, 218, 150, 0.24)),
    (0.83, Colors.transparent),
    (1.00, Colors.transparent),
  ];

  static const List<(double, Color)> _secondaryCones = [
    (0.00, Colors.transparent),
    (0.10, Colors.transparent),
    (0.16, Color.fromRGBO(255, 168, 222, 0.26)),
    (0.21, Color.fromRGBO(124, 244, 255, 0.42)),
    (0.25, Color.fromRGBO(244, 252, 255, 0.40)),
    (0.29, Color.fromRGBO(255, 228, 152, 0.30)),
    (0.36, Colors.transparent),
    (0.60, Colors.transparent),
    (0.66, Color.fromRGBO(255, 168, 222, 0.24)),
    (0.71, Color.fromRGBO(124, 244, 255, 0.38)),
    (0.75, Color.fromRGBO(244, 252, 255, 0.36)),
    (0.79, Color.fromRGBO(255, 228, 152, 0.26)),
    (0.86, Colors.transparent),
    (1.00, Colors.transparent),
  ];

  ImageInfo? _bgImageInfo;
  ImageInfo? _logoImageInfo;
  ui.Image? discArtSprite;

  ui.Image? shadowNineImage;
  ui.Image? shadowCircleImage;
  ui.Image? primarySheenImage;
  ui.Image? secondarySheenImage;
  ui.Image? groovesActiveImage;
  ui.Image? groovesPausedImage;

  bool _proceduralReady = false;
  bool _discArtDirty = false;
  bool _disposed = false;

  ui.Image? get bgImage => _bgImageInfo?.image;
  ui.Image? get logoImage => _logoImageInfo?.image;

  void setBgImageInfo(ImageInfo info) {
    if (_disposed) return;
    final cloned = info.clone();
    _bgImageInfo?.dispose();
    _bgImageInfo = cloned;
    _discArtDirty = true;
  }

  void setLogoImageInfo(ImageInfo info) {
    if (_disposed) return;
    final cloned = info.clone();
    _logoImageInfo?.dispose();
    _logoImageInfo = cloned;
    _discArtDirty = true;
  }

  void ensureSpritesReady() {
    if (_disposed) return;
    if (!_proceduralReady) {
      _proceduralReady = true;
      shadowNineImage = _bakeShadowNineImage();
      shadowCircleImage = _bakeShadowCircleImage();
      primarySheenImage = _bakeSheenImage(_primaryCones);
      secondarySheenImage = _bakeSheenImage(
        _secondaryCones,
        rotation: const GradientRotation(math.pi * 0.48),
      );
      groovesActiveImage = _bakeGroovesImage(isActive: true);
      groovesPausedImage = _bakeGroovesImage(isActive: false);
    }

    if (_discArtDirty && _bgImageInfo != null) {
      _discArtDirty = false;
      discArtSprite?.dispose();
      discArtSprite = _bakeDiscArtSprite(_bgImageInfo!.image, _logoImageInfo?.image);
    }
  }

  ui.Image? _rasterizePicture(int width, int height, void Function(Canvas canvas, Size size) draw) {
    final recorder = ui.PictureRecorder();
    final size = Size(width.toDouble(), height.toDouble());
    final canvas = Canvas(recorder, Offset.zero & size);
    draw(canvas, size);
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(width, height);
    } catch (_) {
      return null;
    } finally {
      picture.dispose();
    }
  }

  /// Gabungkan background cover + logo + circular clip anti-alias menjadi 1 sprite DVD
  /// sehingga piringan berputar tidak lagi memerlukan ClipOval ataupun multi-draw per frame.
  ui.Image? _bakeDiscArtSprite(ui.Image bg, ui.Image? logo) {
    return _rasterizePicture(_discArtSize, _discArtSize, (canvas, size) {
      final clipPath = Path()..addOval(Offset.zero & size);
      canvas.clipPath(clipPath);
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

      final bgW = bg.width.toDouble();
      final bgH = bg.height.toDouble();
      final bgScale = math.max(size.width / bgW, size.height / bgH);
      final cropW = size.width / bgScale;
      final cropH = size.height / bgScale;
      final bgSrc = Rect.fromLTWH((bgW - cropW) * 0.5, (bgH - cropH) * 0.5, cropW, cropH);
      final paint = Paint()..filterQuality = .medium;
      canvas.drawImageRect(bg, bgSrc, Offset.zero & size, paint);

      if (logo != null) {
        final logoW = logo.width.toDouble();
        final logoH = logo.height.toDouble();
        final targetLogoBox = size.width * (38.0 / 62.0);
        final logoScale = math.min(targetLogoBox / logoW, targetLogoBox / logoH);
        final dstRect = Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.5),
          width: logoW * logoScale,
          height: logoH * logoScale,
        );
        canvas.drawImageRect(logo, Rect.fromLTWH(0, 0, logoW, logoH), dstRect, paint);
      }
    });
  }

  ui.Image? _bakeShadowNineImage() {
    return _rasterizePicture(_shadowNineSize, _shadowNineSize, (canvas, size) {
      final paint = Paint()
        ..color = const Color.fromRGBO(0, 0, 0, 0.70)
        ..maskFilter = const ui.MaskFilter.blur(.normal, 5.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(16, 16, 32, 32), const Radius.circular(16)),
        paint,
      );
    });
  }

  ui.Image? _bakeShadowCircleImage() {
    return _rasterizePicture(_shadowCircleSize, _shadowCircleSize, (canvas, size) {
      final half = size.width * 0.5;
      final paint = Paint()
        ..color = const Color.fromRGBO(0, 0, 0, 0.72)
        ..maskFilter = const ui.MaskFilter.blur(.normal, 8.0);
      canvas.drawCircle(Offset(half, half), 28.0, paint);
    });
  }

  ui.Image? _bakeSheenImage(List<(double, Color)> spec, {GradientTransform? rotation}) {
    return _rasterizePicture(_sheenSize, _sheenSize, (canvas, size) {
      final rect = Offset.zero & size;
      final stops = <double>[for (final entry in spec) entry.$1];
      final colors = <Color>[for (final entry in spec) entry.$2];
      final gradient = SweepGradient(colors: colors, stops: stops, transform: rotation);
      final paint = Paint()..shader = gradient.createShader(rect);
      final half = size.width * 0.5;
      canvas.drawCircle(Offset(half, half), half, paint);
    });
  }

  ui.Image? _bakeGroovesImage({required bool isActive}) {
    return _rasterizePicture(_groovesSize, _groovesSize, (canvas, size) {
      _DvdGroovesPainter.paintGrooves(
        canvas: canvas,
        size: size,
        isActive: isActive,
        strokeScale: size.width / 62.0,
        groovePaint: Paint()
          ..style = .stroke
          ..isAntiAlias = true,
        rimPaint: Paint()
          ..style = .stroke
          ..isAntiAlias = true,
        hubRingPaint: Paint()
          ..style = .fill
          ..isAntiAlias = true,
        spindleHolePaint: Paint()
          ..style = .fill
          ..isAntiAlias = true,
      );
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bgImageInfo?.dispose();
    _bgImageInfo = null;
    _logoImageInfo?.dispose();
    _logoImageInfo = null;
    discArtSprite?.dispose();
    discArtSprite = null;
    shadowNineImage?.dispose();
    shadowNineImage = null;
    shadowCircleImage?.dispose();
    shadowCircleImage = null;
    primarySheenImage?.dispose();
    primarySheenImage = null;
    secondarySheenImage?.dispose();
    secondarySheenImage = null;
    groovesActiveImage?.dispose();
    groovesActiveImage = null;
    groovesPausedImage?.dispose();
    groovesPausedImage = null;
  }
}

/// Overlay cover pembuka yang melakukan morph mulus menjadi pemutar DVD
/// berputar di sudut kanan bawah untuk play, jeda, dan replay musik.
class const CoverMusicPlayerOverlay({
  super.key,
  required final String recipientName,
  required final String coverBgAsset,
  required final String coverLogoAsset,
  required final InvitationMusicController musicController,
  required final Animation<double> morphAnimation,
  required final bool isMorphComplete,
  required final VoidCallback onOpenInvitation,
  required final TextStyle titleScriptStyle,
  required final TextStyle coupleGothicStyle,
  required final TextStyle guestIntroStyle,
  required final TextStyle guestNameStyle,
}) extends StatefulWidget {
  @override
  State<CoverMusicPlayerOverlay> createState() => _CoverMusicPlayerOverlayState();
}

class _CoverMusicPlayerOverlayState()
    extends State<CoverMusicPlayerOverlay>
    with TickerProviderStateMixin {
  static const double _discSize = 62.0;
  static const double _dockWidth = 110.0;
  static const double _pillRightOverlap = 31.0;

  late final AnimationController _spinController;
  late final AnimationController _replayPulseController;
  late final Animation<double> _replayScaleAnimation;
  late CurvedAnimation _textFadeCurve;
  late Animation<double> _textFadeAnimation;
  late CurvedAnimation _pillSlideCurve;
  late Animation<Offset> _pillSlideAnimation;

  final Matrix4 _morphMatrix = Matrix4.identity();
  final Matrix4 _spinMatrix = Matrix4.identity();
  final Matrix4 _sheenMatrix = Matrix4.identity();
  final Matrix4 _secondarySheenMatrix = Matrix4.identity();

  final _MorphRepaintSignal _morphRepaintSignal = _MorphRepaintSignal();
  final _DvdSpriteCache _spriteCache = _DvdSpriteCache();
  late Listenable _morphPainterRepaint;
  late Listenable _progressRingRepaint;

  final ValueNotifier<bool> _showCoverText = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isMorphActive = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showMorphPainter = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _dockPaintVisible = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _dockInteractive = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _pillPaintVisible = ValueNotifier<bool>(true);

  ImageStream? _bgStream;
  ImageStreamListener? _bgListener;
  ImageStream? _logoStream;
  ImageStreamListener? _logoListener;
  String? _resolvedBgAsset;
  String? _resolvedLogoAsset;
  double? _resolvedDpr;
  bool _spriteBakeScheduled = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 7));
    _replayPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _replayScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_replayPulseController);

    _initMorphIntervals();
    _rebuildListenableMerges();

    widget.morphAnimation.addListener(_onMorphTick);
    widget.musicController.playbackStateListenable.addListener(_syncDiscSpin);
    _onMorphTick();
    _scheduleSpriteBake();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveCoverAssets();
  }

  @override
  void didUpdateWidget(covariant CoverMusicPlayerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    var repaintDirty = false;
    if (oldWidget.morphAnimation != widget.morphAnimation) {
      oldWidget.morphAnimation.removeListener(_onMorphTick);
      widget.morphAnimation.addListener(_onMorphTick);
      _disposeMorphIntervals();
      _initMorphIntervals();
      repaintDirty = true;
    }
    if (oldWidget.musicController != widget.musicController) {
      oldWidget.musicController.playbackStateListenable.removeListener(_syncDiscSpin);
      widget.musicController.playbackStateListenable.addListener(_syncDiscSpin);
      repaintDirty = true;
    }
    if (repaintDirty) {
      _rebuildListenableMerges();
    }
    if (oldWidget.coverBgAsset != widget.coverBgAsset ||
        oldWidget.coverLogoAsset != widget.coverLogoAsset) {
      _resolveCoverAssets();
    }
    _onMorphTick();
  }

  void _initMorphIntervals() {
    _textFadeCurve = CurvedAnimation(
      parent: widget.morphAnimation,
      curve: const Interval(0.0, 0.26, curve: Curves.easeOutCubic),
    );
    _textFadeAnimation = ReverseAnimation(_textFadeCurve);

    _pillSlideCurve = CurvedAnimation(
      parent: widget.morphAnimation,
      curve: const Interval(0.72, 1.0, curve: Curves.easeOutCubic),
    );
    _pillSlideAnimation = Tween<Offset>(
      begin: const Offset(0.75, 0.0),
      end: Offset.zero,
    ).animate(_pillSlideCurve);
  }

  void _disposeMorphIntervals() {
    _textFadeCurve.dispose();
    _pillSlideCurve.dispose();
  }

  void _rebuildListenableMerges() {
    _morphPainterRepaint = Listenable.merge([widget.morphAnimation, _morphRepaintSignal]);
    _progressRingRepaint = Listenable.merge([
      widget.morphAnimation,
      widget.musicController.progressListenable,
    ]);
  }

  void _scheduleSpriteBake() {
    if (_spriteBakeScheduled) return;
    _spriteBakeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spriteBakeScheduled = false;
      if (!mounted) return;
      _spriteCache.ensureSpritesReady();
      _morphRepaintSignal.notify();
      // Bind baked GPU sprites ke dock pre-warmed yang tersembunyi di balik cover.
      setState(() {});
    });
  }

  void _resolveCoverAssets() {
    final config = createLocalImageConfiguration(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (_resolvedBgAsset != widget.coverBgAsset || _resolvedDpr != dpr) {
      _resolvedBgAsset = widget.coverBgAsset;
      _detachBgStream();
      final stream = AssetImage(widget.coverBgAsset).resolve(config);
      final listener = ImageStreamListener(_onBgImage, onError: _onAssetError);
      _bgStream = stream;
      _bgListener = listener;
      stream.addListener(listener);
    }

    if (_resolvedLogoAsset != widget.coverLogoAsset || _resolvedDpr != dpr) {
      _resolvedLogoAsset = widget.coverLogoAsset;
      _detachLogoStream();
      final stream = AssetImage(widget.coverLogoAsset).resolve(config);
      final listener = ImageStreamListener(_onLogoImage, onError: _onAssetError);
      _logoStream = stream;
      _logoListener = listener;
      stream.addListener(listener);
    }

    _resolvedDpr = dpr;
  }

  void _onBgImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) return;
    final hadImage = _spriteCache.bgImage != null;
    _spriteCache.setBgImageInfo(info);
    if (!synchronousCall) {
      _scheduleSpriteBake();
      if (!hadImage) setState(() {});
    }
  }

  void _onLogoImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) return;
    _spriteCache.setLogoImageInfo(info);
    if (!synchronousCall) {
      _scheduleSpriteBake();
    }
  }

  void _onAssetError(Object error, StackTrace? stackTrace) {}

  void _detachBgStream() {
    final stream = _bgStream;
    final listener = _bgListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _bgStream = null;
    _bgListener = null;
  }

  void _detachLogoStream() {
    final stream = _logoStream;
    final listener = _logoListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _logoStream = null;
    _logoListener = null;
  }

  void _onMorphTick() {
    final rawT = widget.morphAnimation.value;
    if (rawT > 0.0 || widget.isMorphComplete) {
      _spriteCache.ensureSpritesReady();
    }
    final completed = widget.isMorphComplete;
    final isCoverIdle = !completed && rawT <= 0.0;
    final dockReady = completed || rawT >= 0.60;
    final pillReady = completed || rawT >= 0.72;

    _showCoverText.value = !completed && rawT < 0.26;
    _isMorphActive.value = !completed && rawT > 0.0;
    _showMorphPainter.value = !completed && rawT < 0.60;
    // Saat cover belum dibuka (rawT == 0), dock digambar di belakang cover hitam opaque
    // untuk warm-up GPU (shader, tekstur, font ikon) tanpa pernah tampil ke pengguna.
    _dockPaintVisible.value = isCoverIdle || dockReady;
    _dockInteractive.value = dockReady;
    _pillPaintVisible.value = isCoverIdle || pillReady;
    _syncDiscSpin();
  }

  void _syncDiscSpin() {
    final shouldSpin =
        widget.musicController.isPlaying &&
        (widget.isMorphComplete || widget.morphAnimation.value >= 0.60);

    if (shouldSpin) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
    } else if (_spinController.isAnimating) {
      _spinController.stop(canceled: false);
    }
  }

  void _handleTogglePlayPause() {
    HapticFeedback.selectionClick();
    if (widget.musicController.isCompleted) {
      _handleReplay();
      return;
    }
    widget.musicController.togglePlayPause();
  }

  void _handleReplay() {
    HapticFeedback.lightImpact();
    widget.musicController.replay();
    _replayPulseController.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.morphAnimation.removeListener(_onMorphTick);
    widget.musicController.playbackStateListenable.removeListener(_syncDiscSpin);
    _detachBgStream();
    _detachLogoStream();
    _disposeMorphIntervals();
    _spinController.dispose();
    _replayPulseController.dispose();
    _showCoverText.dispose();
    _isMorphActive.dispose();
    _showMorphPainter.dispose();
    _dockPaintVisible.dispose();
    _dockInteractive.dispose();
    _pillPaintVisible.dispose();
    _morphRepaintSignal.dispose();
    _spriteCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final baseMargin = size.width >= 960 ? 24.0 : 16.0;
    final dockRight = baseMargin + safePadding.right;
    final dockBottom = baseMargin + safePadding.bottom;

    final Widget persistentDock = Positioned(
      right: dockRight,
      bottom: dockBottom,
      width: _dockWidth,
      height: _discSize,
      child: ValueListenableBuilder<bool>(
        valueListenable: _dockInteractive,
        child: _DockedDvdMusicDock(
          discSize: _discSize,
          dockWidth: _dockWidth,
          pillRightOverlap: _pillRightOverlap,
          viewportSize: size,
          dockRight: dockRight,
          dockBottom: dockBottom,
          coverBgAsset: widget.coverBgAsset,
          coverLogoAsset: widget.coverLogoAsset,
          spriteCache: _spriteCache,
          musicController: widget.musicController,
          morphAnimation: widget.morphAnimation,
          morphMatrix: _morphMatrix,
          spinAnimation: _spinController,
          spinMatrix: _spinMatrix,
          sheenMatrix: _sheenMatrix,
          secondarySheenMatrix: _secondarySheenMatrix,
          replayScaleAnimation: _replayScaleAnimation,
          progressRingRepaint: _progressRingRepaint,
          showSlidingPill: _pillPaintVisible,
          pillSlideAnimation: _pillSlideAnimation,
          onTogglePlayPause: _handleTogglePlayPause,
          onReplay: _handleReplay,
        ),
        builder: (context, interactive, dockChild) => IgnorePointer(
          ignoring: !interactive,
          child: ExcludeSemantics(
            excluding: !interactive,
            child: ValueListenableBuilder<bool>(
              valueListenable: _dockPaintVisible,
              child: dockChild,
              builder: (context, visible, innerChild) =>
                  Opacity(opacity: visible ? 1.0 : 0.0, child: innerChild),
            ),
          ),
        ),
      ),
    );

    return Stack(
      fit: .expand,
      children: [
        persistentDock,
        ValueListenableBuilder<bool>(
          valueListenable: _showMorphPainter,
          builder: (context, showPainter, _) {
            if (!showPainter) return const SizedBox.shrink();
            return Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _spriteCache.bgImage == null
                      ? _CoverFallbackLayer(coverBgAsset: widget.coverBgAsset)
                      : CustomPaint(
                          painter: _CoverMorphPainter(
                            repaint: _morphPainterRepaint,
                            morphAnimation: widget.morphAnimation,
                            musicController: widget.musicController,
                            spriteCache: _spriteCache,
                            dockRight: dockRight,
                            dockBottom: dockBottom,
                            discSize: _discSize,
                          ),
                          isComplex: true,
                          willChange: true,
                        ),
                ),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _showCoverText,
          builder: (context, showText, _) {
            if (!showText) return const SizedBox.shrink();
            return Positioned.fill(
              child: _CoverTextFadeLayer(
                textFadeAnimation: _textFadeAnimation,
                isMorphActive: _isMorphActive,
                recipientName: widget.recipientName,
                titleScriptStyle: widget.titleScriptStyle,
                coupleGothicStyle: widget.coupleGothicStyle,
                guestIntroStyle: widget.guestIntroStyle,
                guestNameStyle: widget.guestNameStyle,
                onOpenInvitation: widget.onOpenInvitation,
              ),
            );
          },
        ),
      ],
    );
  }
}

final class _CoverMorphPainter({
  required Listenable repaint,
  required final Animation<double> morphAnimation,
  required final InvitationMusicController musicController,
  required final _DvdSpriteCache spriteCache,
  required final double dockRight,
  required final double dockBottom,
  required final double discSize,
}) extends CustomPainter {
  this : super(repaint: repaint);

  static const Rect _shadowNineCenter = Rect.fromLTWH(30, 30, 4, 4);
  static const double _shadowNinePad = 16.0;

  final Paint _scrimPaint = Paint()..style = .fill;
  final Paint _shadowPaint = Paint()..filterQuality = .low;
  final Paint _blackPaint = Paint()
    ..color = Colors.black
    ..style = .fill;
  // FilterQuality.medium mengaktifkan hardware GPU mipmap agar downscale 1080x1920 mulus.
  final Paint _imagePaint = Paint()..filterQuality = .medium;
  final Paint _fadeSpritePaint = Paint()..filterQuality = .low;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0.0 || height <= 0.0) return;

    final rawT = morphAnimation.value.clamp(0.0, 1.0);
    final easeT = Curves.easeInOutCubic.transform(rawT);
    final squareT = Curves.easeInOutCubic.transform((rawT / 0.60).clamp(0.0, 1.0));
    final roundT = Curves.easeInOutCubic.transform(((rawT - 0.03) / 0.55).clamp(0.0, 1.0));
    final dvdDetailsT = Curves.easeOutCubic.transform(((rawT - 0.28) / 0.32).clamp(0.0, 1.0));
    final scrimAlpha = (1.0 - Curves.easeOutCubic.transform((rawT / 0.52).clamp(0.0, 1.0))) * 0.88;
    final shadowAlpha = rawT <= 0.16
        ? 0.0
        : Curves.easeOutCubic.transform(((rawT - 0.16) / 0.44).clamp(0.0, 1.0));

    if (rawT > 0.0 && scrimAlpha > 0.005) {
      _scrimPaint.color = Colors.black.withValues(alpha: scrimAlpha);
      canvas.drawRect(Offset.zero & size, _scrimPaint);
    }

    final targetCx = width - dockRight - discSize * 0.5;
    final targetCy = height - dockBottom - discSize * 0.5;
    final minSide = math.min(width, height);
    final maxSide = math.max(width, height);
    final initialLogoSize = math.min(220.0, math.min(width * 0.56, height * 0.36));

    final baseSide = ui.lerpDouble(minSide, discSize, easeT)!;
    final excess = (maxSide - minSide) * (1.0 - squareT);
    final curW = width >= height ? baseSide + excess : baseSide;
    final curH = height > width ? baseSide + excess : baseSide;

    final posYFactor = easeT * (0.86 + 0.14 * easeT);
    final cx = ui.lerpDouble(width * 0.5, targetCx, easeT)!;
    final cy = ui.lerpDouble(height * 0.5, targetCy, posYFactor)!;
    final cardRect = Rect.fromCenter(center: Offset(cx, cy), width: curW, height: curH);
    final radius = math.min(curW, curH) * 0.5 * roundT;
    final logoSize = ui.lerpDouble(initialLogoSize, baseSide * (38.0 / discSize), squareT)!;
    final logoYOffset = ui.lerpDouble(-12.0, 0.0, squareT)!;

    if (shadowAlpha > 0.01) {
      final shadowImg = spriteCache.shadowNineImage;
      if (shadowImg != null) {
        _shadowPaint.color = Colors.white.withValues(alpha: shadowAlpha);
        final shadowRect = cardRect.inflate(_shadowNinePad).shift(Offset(0.0, 4.0 * shadowAlpha));
        canvas.drawImageNine(shadowImg, _shadowNineCenter, shadowRect, _shadowPaint);
      }
    }

    canvas.save();
    if (radius > 0.5) {
      canvas.clipRRect(RRect.fromRectAndRadius(cardRect, Radius.circular(radius)));
    } else if (rawT > 0.0) {
      canvas.clipRect(cardRect);
    }

    canvas.drawRect(cardRect, _blackPaint);
    final bgImg = spriteCache.bgImage;
    if (bgImg != null) {
      final srcW = bgImg.width.toDouble();
      final srcH = bgImg.height.toDouble();
      final scale = math.max(curW / srcW, curH / srcH);
      final cropW = curW / scale;
      final cropH = curH / scale;
      final srcRect = Rect.fromLTWH((srcW - cropW) * 0.5, (srcH - cropH) * 0.5, cropW, cropH);
      canvas.drawImageRect(bgImg, srcRect, cardRect, _imagePaint);
    }

    final logoImg = spriteCache.logoImage;
    if (logoImg != null) {
      final srcW = logoImg.width.toDouble();
      final srcH = logoImg.height.toDouble();
      final scale = math.min(logoSize / srcW, logoSize / srcH);
      final dstRect = Rect.fromCenter(
        center: Offset(cx, cy + logoYOffset),
        width: srcW * scale,
        height: srcH * scale,
      );
      canvas.drawImageRect(logoImg, Rect.fromLTWH(0, 0, srcW, srcH), dstRect, _imagePaint);
    }

    if (dvdDetailsT > 0.01) {
      final discDiameter = math.min(curW, curH);
      final discSquare = Rect.fromCenter(
        center: Offset(cx, cy),
        width: discDiameter,
        height: discDiameter,
      );
      _fadeSpritePaint.color = Colors.white.withValues(alpha: dvdDetailsT);

      final primarySheen = spriteCache.primarySheenImage;
      if (primarySheen != null) {
        canvas.drawImageRect(
          primarySheen,
          Rect.fromLTWH(0, 0, primarySheen.width.toDouble(), primarySheen.height.toDouble()),
          discSquare,
          _fadeSpritePaint,
        );
      }

      final secondarySheen = spriteCache.secondarySheenImage;
      if (secondarySheen != null) {
        canvas.drawImageRect(
          secondarySheen,
          Rect.fromLTWH(0, 0, secondarySheen.width.toDouble(), secondarySheen.height.toDouble()),
          discSquare,
          _fadeSpritePaint,
        );
      }

      final groovesImg = musicController.isPlaying
          ? spriteCache.groovesActiveImage
          : spriteCache.groovesPausedImage;
      if (groovesImg != null) {
        canvas.drawImageRect(
          groovesImg,
          Rect.fromLTWH(0, 0, groovesImg.width.toDouble(), groovesImg.height.toDouble()),
          discSquare,
          _fadeSpritePaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverMorphPainter oldDelegate) =>
      oldDelegate.morphAnimation != morphAnimation ||
      oldDelegate.musicController != musicController ||
      oldDelegate.spriteCache != spriteCache ||
      oldDelegate.dockRight != dockRight ||
      oldDelegate.dockBottom != dockBottom ||
      oldDelegate.discSize != discSize;
}

/// Overlay teks cover berbasis dua RepaintBoundary statis ringkas + FadeTransition.
/// Tanpa rebuild teks per frame dan tanpa Transform.scale agar atlas glif TTF tidak di-raster ulang.
class const _CoverTextFadeLayer({
  required final Animation<double> textFadeAnimation,
  required final ValueListenable<bool> isMorphActive,
  required final String recipientName,
  required final TextStyle titleScriptStyle,
  required final TextStyle coupleGothicStyle,
  required final TextStyle guestIntroStyle,
  required final TextStyle guestNameStyle,
  required final VoidCallback onOpenInvitation,
}) extends StatelessWidget {
  static final ButtonStyle _openButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(24))),
    padding: const .symmetric(horizontal: 40, vertical: 4),
  );

  @override
  Widget build(BuildContext context) {
    final displayGuest = recipientName.isNotEmpty ? recipientName : 'Tamu Undangan';

    final Widget headerBlock = RepaintBoundary(
      child: Column(
        mainAxisSize: .min,
        children: [
          Text('Pernikahan Kami', style: titleScriptStyle),
          Text('Fauzi & Fitri', style: coupleGothicStyle),
          const Text(
            'Ojay & Mae',
            textAlign: .center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: .w300,
              color: Colors.white,
              height: .6,
              letterSpacing: 5,
              fontStyle: .italic,
            ),
          ),
        ],
      ),
    );

    final Widget footerBlock = RepaintBoundary(
      child: Column(
        mainAxisSize: .min,
        children: [
          Text('Kepada Yth', style: guestIntroStyle),
          Text(displayGuest, textAlign: .center, style: guestNameStyle),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onOpenInvitation,
            style: _openButtonStyle,
            child: const Text(
              'Buka Undangan',
              style: TextStyle(fontSize: 18, fontWeight: .bold, letterSpacing: .5),
            ),
          ),
        ],
      ),
    );

    final Widget content = SafeArea(
      child: Padding(
        padding: const .symmetric(horizontal: 24, vertical: 36),
        child: Stack(
          fit: .expand,
          children: [
            Align(
              alignment: .topCenter,
              child: Padding(
                padding: const .only(top: 24),
                child: FadeTransition(opacity: textFadeAnimation, child: headerBlock),
              ),
            ),
            Align(
              alignment: .bottomCenter,
              child: Padding(
                padding: const .only(bottom: 16),
                child: FadeTransition(opacity: textFadeAnimation, child: footerBlock),
              ),
            ),
          ],
        ),
      ),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: isMorphActive,
      child: content,
      builder: (context, morphActive, child) => IgnorePointer(
        ignoring: morphActive,
        child: morphActive ? child! : Listener(behavior: .opaque, child: child),
      ),
    );
  }
}

class const _CoverFallbackLayer({required final String coverBgAsset}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Image.asset(
        coverBgAsset,
        fit: .cover,
        filterQuality: .medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFF000000)),
      ),
    );
  }
}

/// Dock pemutar DVD persisten yang aktif dari t >= 0.60 dan tetap bertahan tanpa teardown
/// setelah morph selesai di t = 1.00.
class const _DockedDvdMusicDock({
  required final double discSize,
  required final double dockWidth,
  required final double pillRightOverlap,
  required final Size viewportSize,
  required final double dockRight,
  required final double dockBottom,
  required final String coverBgAsset,
  required final String coverLogoAsset,
  required final _DvdSpriteCache spriteCache,
  required final InvitationMusicController musicController,
  required final Animation<double> morphAnimation,
  required final Matrix4 morphMatrix,
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final Matrix4 sheenMatrix,
  required final Matrix4 secondarySheenMatrix,
  required final Animation<double> replayScaleAnimation,
  required final Listenable progressRingRepaint,
  required final ValueListenable<bool> showSlidingPill,
  required final Animation<Offset> pillSlideAnimation,
  required final VoidCallback onTogglePlayPause,
  required final VoidCallback onReplay,
}) extends StatelessWidget {
  static const _PillShadowClipper _pillClipper = _PillShadowClipper();
  @override
  Widget build(BuildContext context) {
    final Widget discNode = RepaintBoundary(
      child: ScaleTransition(
        scale: replayScaleAnimation,
        child: _DvdDiscFrame(
          coverBgAsset: coverBgAsset,
          coverLogoAsset: coverLogoAsset,
          spriteCache: spriteCache,
          musicController: musicController,
          spinAnimation: spinAnimation,
          spinMatrix: spinMatrix,
          sheenMatrix: sheenMatrix,
          secondarySheenMatrix: secondarySheenMatrix,
          morphAnimation: morphAnimation,
          progressRingRepaint: progressRingRepaint,
          onTapDisc: onTogglePlayPause,
        ),
      ),
    );

    final Widget staticPill = RepaintBoundary(
      child: _SlidingControlPillBody(
        shadowNineImage: spriteCache.shadowNineImage,
        musicController: musicController,
        onTogglePlayPause: onTogglePlayPause,
        onReplay: onReplay,
      ),
    );

    final Widget slidingPill = SlideTransition(position: pillSlideAnimation, child: staticPill);

    return SizedBox(
      width: dockWidth,
      height: discSize,
      child: Stack(
        clipBehavior: .none,
        children: [
          Positioned(
            left: 0,
            right: pillRightOverlap,
            top: (discSize - 44.0) * 0.5,
            height: 44.0,
            child: ValueListenableBuilder<bool>(
              valueListenable: showSlidingPill,
              child: ClipRect(clipper: _pillClipper, child: slidingPill),
              builder: (context, showPill, child) =>
                  Opacity(opacity: showPill ? 1.0 : 0.0, child: child),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: discSize,
            height: discSize,
            child: _MorphLandingTransform(
              morphAnimation: morphAnimation,
              morphMatrix: morphMatrix,
              viewportSize: viewportSize,
              dockRight: dockRight,
              dockBottom: dockBottom,
              discSize: discSize,
              child: discNode,
            ),
          ),
        ],
      ),
    );
  }
}

/// Menggerakkan disc secara murni di GPU (translate + uniform scale) selama fase akhir 0.60..1.00.
class const _MorphLandingTransform({
  required final Animation<double> morphAnimation,
  required final Matrix4 morphMatrix,
  required final Size viewportSize,
  required final double dockRight,
  required final double dockBottom,
  required final double discSize,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = viewportSize.width;
    final height = viewportSize.height;
    final minSide = math.min(width, height);
    final targetCx = width - dockRight - discSize * 0.5;
    final targetCy = height - dockBottom - discSize * 0.5;

    return AnimatedBuilder(
      animation: morphAnimation,
      child: child,
      builder: (context, innerChild) {
        final rawT = morphAnimation.value.clamp(0.0, 1.0);
        if (rawT <= 0.0 || rawT >= 0.9999) {
          morphMatrix.setIdentity();
        } else {
          final easeT = Curves.easeInOutCubic.transform(rawT);
          final curSide = ui.lerpDouble(minSide, discSize, easeT)!;
          final posYFactor = easeT * (0.86 + 0.14 * easeT);
          final cx = ui.lerpDouble(width * 0.5, targetCx, easeT)!;
          final cy = ui.lerpDouble(height * 0.5, targetCy, posYFactor)!;
          final scale = curSide / discSize;
          morphMatrix
            ..setIdentity()
            ..translateByDouble(cx - targetCx, cy - targetCy, 0.0, 1.0)
            ..scaleByDouble(scale, scale, 1.0, 1.0);
        }
        return Transform(alignment: .center, transform: morphMatrix, child: innerChild);
      },
    );
  }
}

class const _DvdDiscFrame({
  required final String coverBgAsset,
  required final String coverLogoAsset,
  required final _DvdSpriteCache spriteCache,
  required final InvitationMusicController musicController,
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final Matrix4 sheenMatrix,
  required final Matrix4 secondarySheenMatrix,
  required final Animation<double> morphAnimation,
  required final Listenable progressRingRepaint,
  required final VoidCallback onTapDisc,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final discArtSprite = spriteCache.discArtSprite;
    final shadowCircle = spriteCache.shadowCircleImage;
    final primarySheen = spriteCache.primarySheenImage;
    final secondarySheen = spriteCache.secondarySheenImage;
    final groovesActive = spriteCache.groovesActiveImage;
    final groovesPaused = spriteCache.groovesPausedImage;

    final Widget spinningVisual = Stack(
      fit: .expand,
      children: [
        _SpinningDiscArt(
          spinAnimation: spinAnimation,
          spinMatrix: spinMatrix,
          discArtSprite: discArtSprite,
          coverBgAsset: coverBgAsset,
          coverLogoAsset: coverLogoAsset,
        ),
        IgnorePointer(
          child: _DvdSpecularSheen(
            spinAnimation: spinAnimation,
            sheenMatrix: sheenMatrix,
            secondarySheenMatrix: secondarySheenMatrix,
            primarySheenImage: primarySheen,
            secondarySheenImage: secondarySheen,
          ),
        ),
      ],
    );

    final Widget progressRing = IgnorePointer(
      child: CustomPaint(
        painter: _DvdProgressRingPainter(
          repaint: progressRingRepaint,
          progressListenable: musicController.progressListenable,
          morphAnimation: morphAnimation,
        ),
      ),
    );

    return Stack(
      clipBehavior: .none,
      fit: .expand,
      children: [
        if (shadowCircle != null)
          Positioned(
            left: -22,
            top: -18,
            right: -22,
            bottom: -26,
            child: IgnorePointer(
              child: RawImage(image: shadowCircle, fit: .fill, filterQuality: .low),
            ),
          ),
        ValueListenableBuilder<MusicPlaybackState>(
          valueListenable: musicController.playbackStateListenable,
          child: spinningVisual,
          builder: (context, playbackState, discVisual) {
            final groovesImg = playbackState == .playing ? groovesActive : groovesPaused;
            final String actionLabel = switch (playbackState) {
              .playing => 'Jeda musik',
              .paused => 'Putar musik',
              .completed => 'Putar ulang musik',
            };
            return Semantics(
              button: true,
              label: actionLabel,
              child: Tooltip(
                message: actionLabel,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onTapDisc,
                    behavior: .opaque,
                    child: Stack(
                      fit: .expand,
                      children: [
                        ?discVisual,
                        IgnorePointer(
                          child: groovesImg != null
                              ? RawImage(image: groovesImg, fit: .fill, filterQuality: .low)
                              : CustomPaint(
                                  painter: _DvdGroovesPainter(isActive: playbackState == .playing),
                                ),
                        ),
                        progressRing,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class const _SpinningDiscArt({
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final ui.Image? discArtSprite,
  required final String coverBgAsset,
  required final String coverLogoAsset,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Widget art = discArtSprite != null
        ? Stack(
            fit: .expand,
            children: [RawImage(image: discArtSprite, fit: .fill, filterQuality: .low)],
          )
        : ClipOval(
            clipBehavior: .antiAlias,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: .expand,
                children: [
                  _CoverFallbackLayer(coverBgAsset: coverBgAsset),
                  Center(
                    child: SizedBox(
                      width: 38.0,
                      height: 38.0,
                      child: Image.asset(
                        coverLogoAsset,
                        fit: .contain,
                        filterQuality: .low,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    return AnimatedBuilder(
      animation: spinAnimation,
      child: art,
      builder: (context, child) {
        spinMatrix
          ..setIdentity()
          ..rotateZ(spinAnimation.value * 2.0 * math.pi);
        return Transform(alignment: .center, transform: spinMatrix, child: child);
      },
    );
  }
}

class const _DvdSpecularSheen({
  required final Animation<double> spinAnimation,
  required final Matrix4 sheenMatrix,
  required final Matrix4 secondarySheenMatrix,
  required final ui.Image? primarySheenImage,
  required final ui.Image? secondarySheenImage,
}) extends StatelessWidget {
  static Widget _buildFallbackCones(
    List<(double, Color)> spec, {
    GradientTransform? rotation,
  }) {
    final stops = <double>[for (final entry in spec) entry.$1];
    final colors = <Color>[for (final entry in spec) entry.$2];
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: .circle,
        gradient: SweepGradient(colors: colors, stops: stops, transform: rotation),
      ),
    );
  }

  static final Widget _fallbackPrimary = _buildFallbackCones(_DvdSpriteCache._primaryCones);
  static final Widget _fallbackSecondary = _buildFallbackCones(
    _DvdSpriteCache._secondaryCones,
    rotation: const GradientRotation(math.pi * 0.48),
  );

  Widget _buildRotatedLayer({
    required Widget discChild,
    required Matrix4 matrix,
    required double radiansPerCycle,
  }) {
    return AnimatedBuilder(
      animation: spinAnimation,
      child: discChild,
      builder: (context, child) {
        matrix
          ..setIdentity()
          ..rotateZ(spinAnimation.value * radiansPerCycle);
        return Transform(alignment: .center, transform: matrix, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget primaryDisc = primarySheenImage != null
        ? DecoratedBox(
            decoration: const BoxDecoration(),
            child: RawImage(image: primarySheenImage, fit: .fill, filterQuality: .low),
          )
        : _fallbackPrimary;
    final Widget secondaryDisc = secondarySheenImage != null
        ? DecoratedBox(
            decoration: const BoxDecoration(),
            child: RawImage(image: secondarySheenImage, fit: .fill, filterQuality: .low),
          )
        : _fallbackSecondary;

    return Stack(
      fit: .expand,
      children: [
        _buildRotatedLayer(
          discChild: primaryDisc,
          matrix: sheenMatrix,
          radiansPerCycle: 4.0 * math.pi,
        ),
        _buildRotatedLayer(
          discChild: secondaryDisc,
          matrix: secondarySheenMatrix,
          radiansPerCycle: -2.0 * math.pi,
        ),
      ],
    );
  }
}

class const _SlidingControlPillBody({
  required final ui.Image? shadowNineImage,
  required final InvitationMusicController musicController,
  required final VoidCallback onTogglePlayPause,
  required final VoidCallback onReplay,
}) extends StatelessWidget {
  static final BoxDecoration _pillDecoration = BoxDecoration(
    color: const Color(0xEB111111),
    borderRadius: const .all(.circular(22)),
    border: Border.fromBorderSide(BorderSide(color: Colors.white.withValues(alpha: 0.24))),
  );

  @override
  Widget build(BuildContext context) {
    final Widget pillSurface = DecoratedBox(
      decoration: _pillDecoration,
      child: Padding(
        padding: const .only(left: 8, right: 35),
        child: ValueListenableBuilder<MusicPlaybackState>(
          valueListenable: musicController.playbackStateListenable,
          builder: (context, playbackState, _) {
            final ({IconData icon, String tooltip, double size, VoidCallback onTap}) action =
                switch (playbackState) {
                  .playing => (
                    icon: Icons.pause_rounded,
                    tooltip: 'Jeda musik',
                    size: 20.0,
                    onTap: onTogglePlayPause,
                  ),
                  .paused => (
                    icon: Icons.play_arrow_rounded,
                    tooltip: 'Putar musik',
                    size: 20.0,
                    onTap: onTogglePlayPause,
                  ),
                  .completed => (
                    icon: Icons.replay_rounded,
                    tooltip: 'Putar ulang musik',
                    size: 18.0,
                    onTap: onReplay,
                  ),
                };

            return _MiniPlayerButton(
              icon: action.icon,
              tooltip: action.tooltip,
              iconSize: action.size,
              onTap: action.onTap,
            );
          },
        ),
      ),
    );

    if (shadowNineImage == null) return pillSurface;

    return CustomPaint(
      painter: _NinePatchShadowPainter(shadowNineImage: shadowNineImage!),
      child: pillSurface,
    );
  }
}

final class const _PillShadowClipper() extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTRB(-20.0, -20.0, size.width, size.height + 24.0);

  @override
  bool shouldReclip(_PillShadowClipper oldClipper) => false;
}

final class _NinePatchShadowPainter({required final ui.Image shadowNineImage}) extends CustomPainter {
  static const Rect _centerSlice = Rect.fromLTWH(30, 30, 4, 4);
  static final Paint _paint = Paint()..filterQuality = .low;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowRect = (Offset.zero & size).inflate(14.0).shift(const Offset(0.0, 4.0));
    canvas.drawImageNine(shadowNineImage, _centerSlice, shadowRect, _paint);
  }

  @override
  bool shouldRepaint(_NinePatchShadowPainter oldDelegate) =>
      oldDelegate.shadowNineImage != shadowNineImage;
}

class const _MiniPlayerButton({
  required final IconData icon,
  required final String tooltip,
  required final double iconSize,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  static const BorderRadius _radius = .all(.circular(18));

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: _radius,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Icon(
                  icon,
                  key: ValueKey<int>(icon.codePoint),
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _DvdGroovesPainter({final bool isActive = true}) extends CustomPainter {
  static const List<double> _grooveFractions = [0.92, 0.85, 0.78, 0.71, 0.63, 0.54, 0.45, 0.36];

  final Paint _groovePaint = Paint()
    ..style = .stroke
    ..strokeWidth = 0.65
    ..isAntiAlias = true;

  final Paint _rimPaint = Paint()
    ..style = .stroke
    ..strokeWidth = 1.15
    ..isAntiAlias = true;

  final Paint _hubRingPaint = Paint()
    ..style = .fill
    ..isAntiAlias = true;

  final Paint _spindleHolePaint = Paint()
    ..style = .fill
    ..isAntiAlias = true;

  static void paintGrooves({
    required Canvas canvas,
    required Size size,
    required bool isActive,
    required double strokeScale,
    required Paint groovePaint,
    required Paint rimPaint,
    required Paint hubRingPaint,
    required Paint spindleHolePaint,
  }) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = math.min(size.width, size.height) * 0.5;
    if (radius <= 2.0) return;

    groovePaint
      ..strokeWidth = 0.65 * strokeScale
      ..color = Colors.white.withValues(alpha: 0.15);
    for (final fraction in _grooveFractions) {
      canvas.drawCircle(center, radius * fraction, groovePaint);
    }

    groovePaint.color = Colors.black.withValues(alpha: 0.45);
    canvas.drawCircle(center, math.max(6.2 * strokeScale, radius * 0.31), groovePaint);

    hubRingPaint.color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(center, math.max(5.5 * strokeScale, radius * 0.27), hubRingPaint);

    groovePaint.color = Colors.white.withValues(alpha: 0.42);
    canvas.drawCircle(center, math.max(5.5 * strokeScale, radius * 0.27), groovePaint);

    hubRingPaint.color = Colors.white.withValues(alpha: 0.30);
    canvas.drawCircle(center, math.max(4.0 * strokeScale, radius * 0.185), hubRingPaint);

    groovePaint.color = Colors.white.withValues(alpha: 0.62);
    canvas.drawCircle(center, math.max(4.0 * strokeScale, radius * 0.185), groovePaint);

    spindleHolePaint.color = Colors.black.withValues(alpha: 0.94);
    canvas.drawCircle(center, math.max(2.2 * strokeScale, radius * 0.095), spindleHolePaint);

    groovePaint.color = Colors.white.withValues(alpha: 0.68);
    canvas.drawCircle(center, math.max(2.2 * strokeScale, radius * 0.095), groovePaint);

    rimPaint
      ..strokeWidth = 1.15 * strokeScale
      ..color = Colors.white.withValues(alpha: isActive ? 0.44 : 0.22);
    canvas.drawCircle(center, radius - 0.8 * strokeScale, rimPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintGrooves(
      canvas: canvas,
      size: size,
      isActive: isActive,
      strokeScale: 1.0,
      groovePaint: _groovePaint,
      rimPaint: _rimPaint,
      hubRingPaint: _hubRingPaint,
      spindleHolePaint: _spindleHolePaint,
    );
  }

  @override
  bool shouldRepaint(_DvdGroovesPainter oldDelegate) => oldDelegate.isActive != isActive;
}

final class _DvdProgressRingPainter({
  required Listenable repaint,
  required final ValueListenable<double> progressListenable,
  required final Animation<double> morphAnimation,
}) extends CustomPainter {
  this : super(repaint: repaint);

  final Paint _trackPaint = Paint()
    ..style = .stroke
    ..strokeWidth = 2.0
    ..isAntiAlias = true;

  final Paint _arcPaint = Paint()
    ..style = .stroke
    ..strokeWidth = 2.0
    ..strokeCap = .round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = Curves.easeOut.transform(
      ((morphAnimation.value.clamp(0.0, 1.0) - 0.84) / 0.16).clamp(0.0, 1.0),
    );
    if (alpha <= 0.01) return;

    final radius = math.min(size.width, size.height) * 0.5 - 1.2;
    if (radius <= 2.0) return;
    final center = Offset(size.width * 0.5, size.height * 0.5);

    _trackPaint.color = Colors.white.withValues(alpha: 0.14 * alpha);
    canvas.drawCircle(center, radius, _trackPaint);

    final clamped = progressListenable.value.clamp(0.0, 1.0);
    if (clamped <= 0.002) return;

    _arcPaint.color = Colors.white.withValues(alpha: 0.88 * alpha);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi * 0.5, clamped * 2.0 * math.pi, false, _arcPaint);
  }

  @override
  bool shouldRepaint(_DvdProgressRingPainter oldDelegate) =>
      oldDelegate.progressListenable != progressListenable ||
      oldDelegate.morphAnimation != morphAnimation;
}
