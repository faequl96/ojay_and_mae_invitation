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

/// Cache tekstur GPU hasil pra-render agar morph & putaran DVD bebas shader/blur per frame.
final class _DvdSpriteCache() {
  static const int _shadowSize = 96;
  static const int _sheenSize = 192;
  static const int _groovesSize = 192;
  static const int _discBgSize = 384;
  static const int _discLogoSize = 192;

  ImageInfo? bgImageInfo;
  ImageInfo? logoImageInfo;
  ui.Image? discBgSprite;
  ui.Image? discLogoSprite;

  ui.Image? shadowNineImage;
  ui.Image? primarySheenImage;
  ui.Image? secondarySheenImage;
  ui.Image? groovesActiveImage;
  ui.Image? groovesPausedImage;

  bool _proceduralReady = false;
  bool _disposed = false;

  ui.Image? get bgImage => bgImageInfo?.image;
  ui.Image? get logoImage => logoImageInfo?.image;

  void setBgImageInfo(ImageInfo info) {
    if (_disposed) return;
    final cloned = info.clone();
    bgImageInfo?.dispose();
    bgImageInfo = cloned;
    discBgSprite?.dispose();
    discBgSprite = _bakeDiscBgSprite(cloned.image);
  }

  void setLogoImageInfo(ImageInfo info) {
    if (_disposed) return;
    final cloned = info.clone();
    logoImageInfo?.dispose();
    logoImageInfo = cloned;
    discLogoSprite?.dispose();
    discLogoSprite = _bakeDiscLogoSprite(cloned.image);
  }

  void ensureProceduralSprites() {
    if (_disposed || _proceduralReady) return;
    _proceduralReady = true;

    shadowNineImage = _bakeShadowNineImage();
    primarySheenImage = _bakeSheenImage(_DvdSpecularSheen._primaryCones);
    secondarySheenImage = _bakeSheenImage(
      _DvdSpecularSheen._secondaryCones,
      rotation: const GradientRotation(math.pi * 0.48),
    );
    groovesActiveImage = _bakeGroovesImage(isActive: true);
    groovesPausedImage = _bakeGroovesImage(isActive: false);
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

  ui.Image? _bakeDiscBgSprite(ui.Image src) {
    return _rasterizePicture(_discBgSize, _discBgSize, (canvas, size) {
      final srcW = src.width.toDouble();
      final srcH = src.height.toDouble();
      final scale = math.max(size.width / srcW, size.height / srcH);
      final cropW = size.width / scale;
      final cropH = size.height / scale;
      final srcRect = Rect.fromLTWH((srcW - cropW) * 0.5, (srcH - cropH) * 0.5, cropW, cropH);
      canvas.drawImageRect(src, srcRect, Offset.zero & size, Paint()..filterQuality = .medium);
    });
  }

  ui.Image? _bakeDiscLogoSprite(ui.Image src) {
    return _rasterizePicture(_discLogoSize, _discLogoSize, (canvas, size) {
      final srcW = src.width.toDouble();
      final srcH = src.height.toDouble();
      final scale = math.min(size.width / srcW, size.height / srcH);
      final dstW = srcW * scale;
      final dstH = srcH * scale;
      final dstRect = Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: dstW,
        height: dstH,
      );
      canvas.drawImageRect(
        src,
        Rect.fromLTWH(0, 0, srcW, srcH),
        dstRect,
        Paint()..filterQuality = .medium,
      );
    });
  }

  ui.Image? _bakeShadowNineImage() {
    return _rasterizePicture(_shadowSize, _shadowSize, (canvas, size) {
      final paint = Paint()
        ..color = const Color.fromRGBO(0, 0, 0, 0.72)
        ..maskFilter = const ui.MaskFilter.blur(.normal, 6.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(20, 20, 56, 56), const Radius.circular(28)),
        paint,
      );
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
        intensity: 1.0,
        isActive: isActive,
        strokeScale: size.width / 62.0,
        groovePaint: Paint()
          ..style = .stroke
          ..isAntiAlias = true,
        rimPaint: Paint()
          ..style = .stroke
          ..isAntiAlias = true,
        specularArcPaint: Paint()
          ..style = .stroke
          ..strokeCap = .round
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
    bgImageInfo?.dispose();
    bgImageInfo = null;
    logoImageInfo?.dispose();
    logoImageInfo = null;
    discBgSprite?.dispose();
    discBgSprite = null;
    discLogoSprite?.dispose();
    discLogoSprite = null;
    shadowNineImage?.dispose();
    shadowNineImage = null;
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
  late CurvedAnimation _buttonFadeCurve;
  late Animation<double> _buttonFadeAnimation;

  final Matrix4 _spinMatrix = Matrix4.identity();
  final Matrix4 _sheenMatrix = Matrix4.identity();
  final Matrix4 _secondarySheenMatrix = Matrix4.identity();
  final Matrix4 _morphEndMatrix = Matrix4.identity();

  final _MorphRepaintSignal _morphRepaintSignal = _MorphRepaintSignal();
  final _DvdSpriteCache _spriteCache = _DvdSpriteCache();
  late Listenable _morphPainterRepaint;
  late Listenable _progressRingRepaint;

  final ValueNotifier<bool> _showCoverText = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isMorphActive = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showSlidingPill = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _useWidgetDiscPhase = ValueNotifier<bool>(false);

  ImageStream? _bgStream;
  ImageStreamListener? _bgListener;
  ImageStream? _logoStream;
  ImageStreamListener? _logoListener;
  String? _resolvedBgAsset;
  String? _resolvedLogoAsset;
  double? _resolvedDpr;

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

    _initButtonFadeAnimation();
    _rebuildMorphPainterRepaint();

    widget.morphAnimation.addListener(_onMorphTick);
    widget.musicController.playbackStateListenable.addListener(_syncDiscSpin);
    _onMorphTick();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _spriteCache.ensureProceduralSprites();
        _morphRepaintSignal.notify();
      }
    });
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
      _buttonFadeCurve.dispose();
      _initButtonFadeAnimation();
      repaintDirty = true;
    }
    if (oldWidget.musicController != widget.musicController) {
      oldWidget.musicController.playbackStateListenable.removeListener(_syncDiscSpin);
      widget.musicController.playbackStateListenable.addListener(_syncDiscSpin);
      repaintDirty = true;
    }
    if (repaintDirty) {
      _rebuildMorphPainterRepaint();
    }
    if (oldWidget.coverBgAsset != widget.coverBgAsset ||
        oldWidget.coverLogoAsset != widget.coverLogoAsset) {
      _resolveCoverAssets();
    }
    _onMorphTick();
  }

  void _initButtonFadeAnimation() {
    _buttonFadeCurve = CurvedAnimation(
      parent: widget.morphAnimation,
      curve: const Interval(0.0, 0.26, curve: Curves.easeOutCubic),
    );
    _buttonFadeAnimation = ReverseAnimation(_buttonFadeCurve);
  }

  void _rebuildMorphPainterRepaint() {
    _morphPainterRepaint = Listenable.merge([
      widget.morphAnimation,
      _spinController,
      widget.musicController.progressListenable,
      widget.musicController.playbackStateListenable,
      _morphRepaintSignal,
    ]);
    _progressRingRepaint = Listenable.merge([
      widget.morphAnimation,
      widget.musicController.progressListenable,
    ]);
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
      _morphRepaintSignal.notify();
      if (!hadImage || widget.isMorphComplete) {
        setState(() {});
      }
    }
  }

  void _onLogoImage(ImageInfo info, bool synchronousCall) {
    if (!mounted) return;
    final hadImage = _spriteCache.logoImage != null;
    _spriteCache.setLogoImageInfo(info);
    if (!synchronousCall) {
      _morphRepaintSignal.notify();
      if (!hadImage || widget.isMorphComplete) {
        setState(() {});
      }
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
    if (rawT > 0.0) {
      _spriteCache.ensureProceduralSprites();
    }
    _showCoverText.value = rawT < 0.26;
    _isMorphActive.value = rawT > 0.0;
    _showSlidingPill.value = rawT >= 0.72;
    _useWidgetDiscPhase.value = rawT >= 0.84;
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
    _buttonFadeCurve.dispose();
    _spinController.dispose();
    _replayPulseController.dispose();
    _showCoverText.dispose();
    _isMorphActive.dispose();
    _showSlidingPill.dispose();
    _useWidgetDiscPhase.dispose();
    _morphRepaintSignal.dispose();
    _spriteCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final baseMargin = size.width >= 960 ? 24.0 : 16.0;
    final dockRight = baseMargin + safePadding.right;
    final dockBottom = baseMargin + safePadding.bottom;

    if (widget.isMorphComplete) {
      _spriteCache.ensureProceduralSprites();
      return Positioned(
        right: dockRight,
        bottom: dockBottom,
        child: _DockedDvdMusicDock(
          discSize: _discSize,
          dockWidth: _dockWidth,
          pillRightOverlap: _pillRightOverlap,
          coverBgAsset: widget.coverBgAsset,
          coverLogoAsset: widget.coverLogoAsset,
          spriteCache: _spriteCache,
          musicController: widget.musicController,
          spinAnimation: _spinController,
          spinMatrix: _spinMatrix,
          sheenMatrix: _sheenMatrix,
          secondarySheenMatrix: _secondarySheenMatrix,
          replayScaleAnimation: _replayScaleAnimation,
          onTogglePlayPause: _handleTogglePlayPause,
          onReplay: _handleReplay,
        ),
      );
    }

    return Stack(
      fit: .expand,
      children: [
        if (_spriteCache.bgImage == null)
          Positioned.fill(
            child: IgnorePointer(child: _CoverArtworkLayer(coverBgAsset: widget.coverBgAsset)),
          ),

        ValueListenableBuilder<bool>(
          valueListenable: _useWidgetDiscPhase,
          builder: (context, useWidgetDisc, _) {
            if (useWidgetDisc) return const SizedBox.shrink();
            return Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _CoverMorphPainter(
                      repaint: _morphPainterRepaint,
                      morphAnimation: widget.morphAnimation,
                      spinAnimation: _spinController,
                      musicController: widget.musicController,
                      spriteCache: _spriteCache,
                      dockRight: dockRight,
                      dockBottom: dockBottom,
                      discSize: _discSize,
                      devicePixelRatio: dpr,
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
          valueListenable: _showSlidingPill,
          builder: (context, showPill, _) {
            if (!showPill) return const SizedBox.shrink();
            return Positioned(
              right: dockRight + _pillRightOverlap,
              bottom: dockBottom + (_discSize - 44.0) * 0.5,
              width: _dockWidth - _pillRightOverlap,
              height: 44.0,
              child: _SlidingPillReveal(
                morphAnimation: widget.morphAnimation,
                child: RepaintBoundary(
                  child: _SlidingControlPillBody(
                    musicController: widget.musicController,
                    onTogglePlayPause: _handleTogglePlayPause,
                    onReplay: _handleReplay,
                  ),
                ),
              ),
            );
          },
        ),

        ValueListenableBuilder<bool>(
          valueListenable: _useWidgetDiscPhase,
          builder: (context, useWidgetDisc, _) {
            if (!useWidgetDisc) return const SizedBox.shrink();
            return Positioned(
              right: dockRight,
              bottom: dockBottom,
              width: _discSize,
              height: _discSize,
              child: _MorphEndDiscOverlay(
                morphAnimation: widget.morphAnimation,
                morphEndMatrix: _morphEndMatrix,
                progressRingRepaint: _progressRingRepaint,
                viewportSize: size,
                dockRight: dockRight,
                dockBottom: dockBottom,
                discSize: _discSize,
                coverBgAsset: widget.coverBgAsset,
                coverLogoAsset: widget.coverLogoAsset,
                spriteCache: _spriteCache,
                musicController: widget.musicController,
                spinAnimation: _spinController,
                spinMatrix: _spinMatrix,
                sheenMatrix: _sheenMatrix,
                secondarySheenMatrix: _secondarySheenMatrix,
                onTapDisc: _handleTogglePlayPause,
              ),
            );
          },
        ),

        ValueListenableBuilder<bool>(
          valueListenable: _showCoverText,
          builder: (context, showText, _) {
            if (!showText) return const SizedBox.shrink();
            return Positioned.fill(
              child: RepaintBoundary(
                child: _CoverTextFadeLayer(
                  morphAnimation: widget.morphAnimation,
                  isMorphActive: _isMorphActive,
                  buttonFadeAnimation: _buttonFadeAnimation,
                  recipientName: widget.recipientName,
                  titleScriptStyle: widget.titleScriptStyle,
                  coupleGothicStyle: widget.coupleGothicStyle,
                  guestIntroStyle: widget.guestIntroStyle,
                  guestNameStyle: widget.guestNameStyle,
                  onOpenInvitation: widget.onOpenInvitation,
                ),
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
  required final Animation<double> spinAnimation,
  required final InvitationMusicController musicController,
  required final _DvdSpriteCache spriteCache,
  required final double dockRight,
  required final double dockBottom,
  required final double discSize,
  required final double devicePixelRatio,
}) extends CustomPainter {
  this : super(repaint: repaint);

  static const Rect _shadowNineCenter = Rect.fromLTWH(46, 46, 4, 4);
  static const double _shadowNinePad = 20.0;

  final Paint _scrimPaint = Paint()..style = .fill;
  final Paint _shadowPaint = Paint()..filterQuality = .low;
  final Paint _blackPaint = Paint()
    ..color = Colors.black
    ..style = .fill;
  final Paint _imagePaint = Paint()..filterQuality = .low;
  final Paint _fadeSpritePaint = Paint()..filterQuality = .low;
  final Paint _ringTrackPaint = Paint()
    ..style = .stroke
    ..strokeWidth = 2.0
    ..isAntiAlias = true;
  final Paint _ringArcPaint = Paint()
    ..style = .stroke
    ..strokeWidth = 2.0
    ..strokeCap = .round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0.0 || height <= 0.0) return;

    final rawT = morphAnimation.value.clamp(0.0, 1.0);
    final easeT = Curves.easeInOutCubic.transform(rawT);
    final squareT = Curves.easeInOutCubic.transform((rawT / 0.60).clamp(0.0, 1.0));
    final roundT = Curves.easeInOutCubic.transform(((rawT - 0.03) / 0.55).clamp(0.0, 1.0));
    final dvdDetailsT = Curves.easeOutCubic.transform(((rawT - 0.28) / 0.50).clamp(0.0, 1.0));
    final progressRingAlpha = Curves.easeOut.transform(((rawT - 0.84) / 0.16).clamp(0.0, 1.0));
    final scrimAlpha = (1.0 - Curves.easeOutCubic.transform((rawT / 0.52).clamp(0.0, 1.0))) * 0.88;
    final shadowAlpha = Curves.easeOutCubic.transform(((rawT - 0.10) / 0.50).clamp(0.0, 1.0));

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
    final logoSize = ui.lerpDouble(initialLogoSize, 38.0, easeT)!;
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

    final spinValue = spinAnimation.value;
    final spinAngle = spinValue * 2.0 * math.pi;
    final hasSpin = spinAngle != 0.0;
    if (hasSpin) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(spinAngle);
      canvas.translate(-cx, -cy);
    }

    final discBgSprite = spriteCache.discBgSprite;
    final discLogoSprite = spriteCache.discLogoSprite;
    final useDiscSprites =
        squareT >= 0.999 &&
        curW * devicePixelRatio <= 540.0 &&
        discBgSprite != null &&
        discLogoSprite != null;

    final bgImg = useDiscSprites ? discBgSprite : spriteCache.bgImage;
    if (bgImg != null) {
      final srcW = bgImg.width.toDouble();
      final srcH = bgImg.height.toDouble();
      final scale = math.max(curW / srcW, curH / srcH);
      final cropW = curW / scale;
      final cropH = curH / scale;
      final srcRect = Rect.fromLTWH((srcW - cropW) * 0.5, (srcH - cropH) * 0.5, cropW, cropH);
      canvas.drawImageRect(bgImg, srcRect, cardRect, _imagePaint);
    }

    final logoImg = useDiscSprites ? discLogoSprite : spriteCache.logoImage;
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

    if (hasSpin) {
      canvas.restore();
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
        final sheenSrc = Rect.fromLTWH(
          0,
          0,
          primarySheen.width.toDouble(),
          primarySheen.height.toDouble(),
        );
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(spinValue * 4.0 * math.pi);
        canvas.translate(-cx, -cy);
        canvas.drawImageRect(primarySheen, sheenSrc, discSquare, _fadeSpritePaint);
        canvas.restore();
      }

      final secondarySheen = spriteCache.secondarySheenImage;
      if (secondarySheen != null) {
        final sheenSrc = Rect.fromLTWH(
          0,
          0,
          secondarySheen.width.toDouble(),
          secondarySheen.height.toDouble(),
        );
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(spinValue * -2.0 * math.pi);
        canvas.translate(-cx, -cy);
        canvas.drawImageRect(secondarySheen, sheenSrc, discSquare, _fadeSpritePaint);
        canvas.restore();
      }

      final groovesImg = musicController.isPlaying
          ? spriteCache.groovesActiveImage
          : spriteCache.groovesPausedImage;
      if (groovesImg != null) {
        final groovesSrc = Rect.fromLTWH(
          0,
          0,
          groovesImg.width.toDouble(),
          groovesImg.height.toDouble(),
        );
        canvas.drawImageRect(groovesImg, groovesSrc, discSquare, _fadeSpritePaint);
      }
    }

    if (progressRingAlpha > 0.01) {
      final ringRadius = math.min(curW, curH) * 0.5 - 1.2;
      if (ringRadius > 2.0) {
        final center = Offset(cx, cy);
        _ringTrackPaint.color = Colors.white.withValues(alpha: 0.14 * progressRingAlpha);
        canvas.drawCircle(center, ringRadius, _ringTrackPaint);

        final clamped = musicController.progress.clamp(0.0, 1.0);
        if (clamped > 0.002) {
          _ringArcPaint.color = Colors.white.withValues(alpha: 0.88 * progressRingAlpha);
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: ringRadius),
            -math.pi * 0.5,
            clamped * 2.0 * math.pi,
            false,
            _ringArcPaint,
          );
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverMorphPainter oldDelegate) =>
      oldDelegate.morphAnimation != morphAnimation ||
      oldDelegate.spinAnimation != spinAnimation ||
      oldDelegate.musicController != musicController ||
      oldDelegate.spriteCache != spriteCache ||
      oldDelegate.dockRight != dockRight ||
      oldDelegate.dockBottom != dockBottom ||
      oldDelegate.discSize != discSize ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}

class const _CoverTextFadeLayer({
  required final Animation<double> morphAnimation,
  required final ValueListenable<bool> isMorphActive,
  required final Animation<double> buttonFadeAnimation,
  required final String recipientName,
  required final TextStyle titleScriptStyle,
  required final TextStyle coupleGothicStyle,
  required final TextStyle guestIntroStyle,
  required final TextStyle guestNameStyle,
  required final VoidCallback onOpenInvitation,
}) extends StatelessWidget {
  static const _openButtonShape = RoundedRectangleBorder(borderRadius: .all(.circular(24)));
  static const _openButtonPadding = EdgeInsets.symmetric(horizontal: 40, vertical: 4);
  static const _openButtonLabel = Text(
    'Buka Undangan',
    style: TextStyle(fontSize: 18, fontWeight: .bold, letterSpacing: .5),
  );

  static ButtonStyle _buildOpenButtonStyle(double alpha) => ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withValues(alpha: alpha),
    foregroundColor: Colors.black.withValues(alpha: alpha),
    elevation: 0,
    shape: _openButtonShape,
    padding: _openButtonPadding,
  );

  static final ButtonStyle _openButtonStyle = _buildOpenButtonStyle(1.0);

  @override
  Widget build(BuildContext context) {
    final displayGuest = recipientName.isNotEmpty ? recipientName : 'Tamu Undangan';

    final Widget staticButton = FadeTransition(
      opacity: buttonFadeAnimation,
      child: ElevatedButton(
        onPressed: onOpenInvitation,
        style: _openButtonStyle,
        child: _openButtonLabel,
      ),
    );

    final Widget fadingOverlay = AnimatedBuilder(
      animation: morphAnimation,
      child: staticButton,
      builder: (context, buttonChild) {
        final rawT = morphAnimation.value.clamp(0.0, 1.0);
        final fadeT = rawT <= 0.0
            ? 0.0
            : Curves.easeOutCubic.transform((rawT / 0.26).clamp(0.0, 1.0));
        final textAlpha = (1.0 - fadeT).clamp(0.0, 1.0);
        if (textAlpha <= 0.01) return const SizedBox.shrink();

        final textColor = Colors.white.withValues(alpha: textAlpha);
        final scale = ui.lerpDouble(1.0, 0.94, fadeT)!;
        final Widget effectiveButton = rawT <= 0.0
            ? buttonChild!
            : ElevatedButton(
                onPressed: onOpenInvitation,
                style: _buildOpenButtonStyle(
                  (textAlpha * buttonFadeAnimation.value).clamp(0.0, 1.0),
                ),
                child: _openButtonLabel,
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
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        Text(
                          'Pernikahan Kami',
                          style: textAlpha >= 0.999
                              ? titleScriptStyle
                              : titleScriptStyle.copyWith(color: textColor),
                        ),
                        Text(
                          'Fauzi & Fitri',
                          style: textAlpha >= 0.999
                              ? coupleGothicStyle
                              : coupleGothicStyle.copyWith(color: textColor),
                        ),
                        Text(
                          'Ojay & Mae',
                          textAlign: .center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: .w300,
                            color: textColor,
                            height: .6,
                            letterSpacing: 5,
                            fontStyle: .italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: .bottomCenter,
                  child: Padding(
                    padding: const .only(bottom: 16),
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        Text(
                          'Kepada Yth',
                          style: textAlpha >= 0.999
                              ? guestIntroStyle
                              : guestIntroStyle.copyWith(color: textColor),
                        ),
                        Text(
                          displayGuest,
                          textAlign: .center,
                          style: textAlpha >= 0.999
                              ? guestNameStyle
                              : guestNameStyle.copyWith(color: textColor),
                        ),
                        const SizedBox(height: 18),
                        effectiveButton,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (scale >= 0.999) return content;
        return Transform.scale(scale: scale, child: content);
      },
    );

    return ValueListenableBuilder<bool>(
      valueListenable: isMorphActive,
      child: fadingOverlay,
      builder: (context, morphActive, child) => IgnorePointer(
        ignoring: morphActive,
        child: morphActive ? child! : Listener(behavior: .opaque, child: child),
      ),
    );
  }
}

class const _SlidingPillReveal({
  required final Animation<double> morphAnimation,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: morphAnimation,
      child: child,
      builder: (context, staticPill) {
        final rawT = morphAnimation.value.clamp(0.0, 1.0);
        final reveal = Curves.easeOutCubic.transform(((rawT - 0.72) / 0.28).clamp(0.0, 1.0));
        if (reveal >= 0.999) return staticPill!;
        return ClipRect(
          child: Transform.translate(offset: Offset((1.0 - reveal) * 56.0, 0.0), child: staticPill),
        );
      },
    );
  }
}

class const _CoverArtworkLayer({required final String coverBgAsset}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      coverBgAsset,
      fit: .cover,
      filterQuality: .low,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFF000000)),
    );
  }
}

class const _MorphEndDiscOverlay({
  required final Animation<double> morphAnimation,
  required final Matrix4 morphEndMatrix,
  required final Listenable progressRingRepaint,
  required final Size viewportSize,
  required final double dockRight,
  required final double dockBottom,
  required final double discSize,
  required final String coverBgAsset,
  required final String coverLogoAsset,
  required final _DvdSpriteCache spriteCache,
  required final InvitationMusicController musicController,
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final Matrix4 sheenMatrix,
  required final Matrix4 secondarySheenMatrix,
  required final VoidCallback onTapDisc,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final discWidget = _DvdDiscFrame(
      coverBgAsset: coverBgAsset,
      coverLogoAsset: coverLogoAsset,
      spriteCache: spriteCache,
      musicController: musicController,
      spinAnimation: spinAnimation,
      spinMatrix: spinMatrix,
      sheenMatrix: sheenMatrix,
      secondarySheenMatrix: secondarySheenMatrix,
      onTapDisc: onTapDisc,
      includeAccessibility: false,
      morphAnimation: morphAnimation,
      progressRingRepaint: progressRingRepaint,
    );

    final width = viewportSize.width;
    final height = viewportSize.height;
    final minSide = math.min(width, height);
    final targetCx = width - dockRight - discSize * 0.5;
    final targetCy = height - dockBottom - discSize * 0.5;

    return AnimatedBuilder(
      animation: morphAnimation,
      child: discWidget,
      builder: (context, child) {
        final rawT = morphAnimation.value.clamp(0.0, 1.0);
        final easeT = Curves.easeInOutCubic.transform(rawT);
        final curSide = ui.lerpDouble(minSide, discSize, easeT)!;
        final posYFactor = easeT * (0.86 + 0.14 * easeT);
        final cx = ui.lerpDouble(width * 0.5, targetCx, easeT)!;
        final cy = ui.lerpDouble(height * 0.5, targetCy, posYFactor)!;
        final scale = curSide / discSize;

        morphEndMatrix
          ..setIdentity()
          ..translateByDouble(cx - targetCx, cy - targetCy, 0.0, 1.0)
          ..scaleByDouble(scale, scale, 1.0, 1.0);

        return Transform(alignment: .center, transform: morphEndMatrix, child: child);
      },
    );
  }
}

class const _DockedDvdMusicDock({
  required final double discSize,
  required final double dockWidth,
  required final double pillRightOverlap,
  required final String coverBgAsset,
  required final String coverLogoAsset,
  required final _DvdSpriteCache spriteCache,
  required final InvitationMusicController musicController,
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final Matrix4 sheenMatrix,
  required final Matrix4 secondarySheenMatrix,
  required final Animation<double> replayScaleAnimation,
  required final VoidCallback onTogglePlayPause,
  required final VoidCallback onReplay,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            child: _SlidingControlPillBody(
              musicController: musicController,
              onTogglePlayPause: onTogglePlayPause,
              onReplay: onReplay,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: discSize,
            height: discSize,
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
                onTapDisc: onTogglePlayPause,
                includeAccessibility: true,
              ),
            ),
          ),
        ],
      ),
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
  required final VoidCallback onTapDisc,
  required final bool includeAccessibility,
  final Animation<double>? morphAnimation,
  final Listenable? progressRingRepaint,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bgSprite = spriteCache.discBgSprite;
    final logoSprite = spriteCache.discLogoSprite;
    final primarySheen = spriteCache.primarySheenImage;
    final secondarySheen = spriteCache.secondarySheenImage;
    final groovesActive = spriteCache.groovesActiveImage;
    final groovesPaused = spriteCache.groovesPausedImage;

    final staticDiscVisual = Stack(
      fit: .expand,
      children: [
        _SpinningDiscArt(
          spinAnimation: spinAnimation,
          spinMatrix: spinMatrix,
          logoSize: 38.0,
          coverLogoAsset: coverLogoAsset,
          logoSprite: logoSprite,
          bgChild: bgSprite != null
              ? RawImage(image: bgSprite, fit: .cover, filterQuality: .low)
              : _CoverArtworkLayer(coverBgAsset: coverBgAsset),
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

    final staticProgressRing = IgnorePointer(
      child: CustomPaint(
        painter: _DvdProgressRingPainter(
          repaint: progressRingRepaint ?? musicController.progressListenable,
          progressListenable: musicController.progressListenable,
          morphAnimation: morphAnimation,
        ),
      ),
    );

    return _ShadowedDiscFrame(
      child: RepaintBoundary(
        child: ClipOval(
          clipBehavior: .antiAlias,
          child: ColoredBox(
            color: Colors.black,
            child: ValueListenableBuilder<MusicPlaybackState>(
              valueListenable: musicController.playbackStateListenable,
              child: staticDiscVisual,
              builder: (context, playbackState, discVisual) {
                final groovesImg = playbackState == .playing ? groovesActive : groovesPaused;
                final Widget interactiveDisc = MouseRegion(
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
                                  painter: _DvdGroovesPainter(
                                    intensity: 1.0,
                                    isActive: playbackState == .playing,
                                  ),
                                ),
                        ),
                        staticProgressRing,
                      ],
                    ),
                  ),
                );

                if (!includeAccessibility) return interactiveDisc;

                final String actionLabel = switch (playbackState) {
                  .playing => 'Jeda musik',
                  .paused => 'Putar musik',
                  .completed => 'Putar ulang musik',
                };
                return Semantics(
                  button: true,
                  label: actionLabel,
                  child: Tooltip(message: actionLabel, child: interactiveDisc),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class const _ShadowedDiscFrame({required final Widget child}) extends StatelessWidget {
  static final BoxDecoration _discShadowDecoration = BoxDecoration(
    shape: .circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.72),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(decoration: _discShadowDecoration, child: child);
  }
}

class const _SpinningDiscArt({
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final double logoSize,
  required final String coverLogoAsset,
  required final ui.Image? logoSprite,
  required final Widget? bgChild,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Widget centeredLogo = Center(
      child: SizedBox(
        width: logoSize,
        height: logoSize,
        child: logoSprite != null
            ? RawImage(image: logoSprite, fit: .contain, filterQuality: .low)
            : Image.asset(
                coverLogoAsset,
                fit: .contain,
                filterQuality: .low,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
      ),
    );

    final art = Stack(fit: .expand, children: [?bgChild, centeredLogo]);

    return AnimatedBuilder(
      animation: spinAnimation,
      child: art,
      builder: (context, child) {
        final angle = spinAnimation.value * 2.0 * math.pi;
        spinMatrix
          ..setIdentity()
          ..rotateZ(angle);
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

  static final Widget _fullPrimaryDisc = _buildFallbackDiffractionDisc(_primaryCones);
  static final Widget _fullSecondaryDisc = _buildFallbackDiffractionDisc(
    _secondaryCones,
    rotation: const GradientRotation(math.pi * 0.48),
  );

  static Widget _buildFallbackDiffractionDisc(
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
        : _fullPrimaryDisc;
    final Widget secondaryDisc = secondarySheenImage != null
        ? DecoratedBox(
            decoration: const BoxDecoration(),
            child: RawImage(image: secondarySheenImage, fit: .fill, filterQuality: .low),
          )
        : _fullSecondaryDisc;

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
  required final InvitationMusicController musicController,
  required final VoidCallback onTogglePlayPause,
  required final VoidCallback onReplay,
}) extends StatelessWidget {
  static final BoxDecoration _pillDecoration = BoxDecoration(
    color: const Color(0xEB111111),
    borderRadius: const .all(.circular(22)),
    border: Border.fromBorderSide(BorderSide(color: Colors.white.withValues(alpha: 0.24))),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.65),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
  }
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

final class _DvdGroovesPainter({required final double intensity, final bool isActive = true})
    extends CustomPainter {
  static const List<double> _grooveFractions = [0.92, 0.85, 0.78, 0.71, 0.63, 0.54, 0.45, 0.36];

  final Paint _groovePaint = Paint()
    ..style = .stroke
    ..strokeWidth = 0.65
    ..isAntiAlias = true;

  final Paint _rimPaint = Paint()
    ..style = .stroke
    ..strokeWidth = 1.15
    ..isAntiAlias = true;

  final Paint _specularArcPaint = Paint()
    ..style = .stroke
    ..strokeWidth = 1.5
    ..strokeCap = .round
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
    required double intensity,
    required bool isActive,
    required double strokeScale,
    required Paint groovePaint,
    required Paint rimPaint,
    required Paint specularArcPaint,
    required Paint hubRingPaint,
    required Paint spindleHolePaint,
  }) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = math.min(size.width, size.height) * 0.5;
    if (radius <= 2.0) return;

    groovePaint
      ..strokeWidth = 0.65 * strokeScale
      ..color = Colors.white.withValues(alpha: 0.15 * intensity);
    for (final fraction in _grooveFractions) {
      canvas.drawCircle(center, radius * fraction, groovePaint);
    }

    // Cincin pembatas gelap + hub polikarbonat transparan + lubang spindle.
    groovePaint.color = Colors.black.withValues(alpha: 0.45 * intensity);
    canvas.drawCircle(center, math.max(6.2 * strokeScale, radius * 0.31), groovePaint);

    hubRingPaint.color = Colors.white.withValues(alpha: 0.16 * intensity);
    canvas.drawCircle(center, math.max(5.5 * strokeScale, radius * 0.27), hubRingPaint);

    groovePaint.color = Colors.white.withValues(alpha: 0.42 * intensity);
    canvas.drawCircle(center, math.max(5.5 * strokeScale, radius * 0.27), groovePaint);

    hubRingPaint.color = Colors.white.withValues(alpha: 0.30 * intensity);
    canvas.drawCircle(center, math.max(4.0 * strokeScale, radius * 0.185), hubRingPaint);

    groovePaint.color = Colors.white.withValues(alpha: 0.62 * intensity);
    canvas.drawCircle(center, math.max(4.0 * strokeScale, radius * 0.185), groovePaint);

    spindleHolePaint.color = Colors.black.withValues(alpha: 0.94 * intensity);
    canvas.drawCircle(center, math.max(2.2 * strokeScale, radius * 0.095), spindleHolePaint);

    groovePaint.color = Colors.white.withValues(alpha: 0.68 * intensity);
    canvas.drawCircle(center, math.max(2.2 * strokeScale, radius * 0.095), groovePaint);

    final rimAlpha = (isActive ? 0.44 : 0.22) * intensity;
    rimPaint
      ..strokeWidth = 1.15 * strokeScale
      ..color = Colors.white.withValues(alpha: rimAlpha);
    canvas.drawCircle(center, radius - 0.8 * strokeScale, rimPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintGrooves(
      canvas: canvas,
      size: size,
      intensity: intensity,
      isActive: isActive,
      strokeScale: 1.0,
      groovePaint: _groovePaint,
      rimPaint: _rimPaint,
      specularArcPaint: _specularArcPaint,
      hubRingPaint: _hubRingPaint,
      spindleHolePaint: _spindleHolePaint,
    );
  }

  @override
  bool shouldRepaint(_DvdGroovesPainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.isActive != isActive;
}

final class _DvdProgressRingPainter({
  required Listenable repaint,
  required final ValueListenable<double> progressListenable,
  final Animation<double>? morphAnimation,
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
    final morph = morphAnimation;
    final alpha = morph == null
        ? 1.0
        : Curves.easeOut.transform(((morph.value.clamp(0.0, 1.0) - 0.84) / 0.16).clamp(0.0, 1.0));
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
