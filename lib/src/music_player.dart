import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ojay_and_mae_invitation/src/web_interop.dart';

/// Pengendali pemutar musik undangan (Play, Pause, Replay, dan progres trek).
final class InvitationMusicController({String assetPath = defaultMusicAsset, bool loop = false}) {
  this {
    _engine = WebAudioEngine(
      assetPath: assetPath,
      loop: loop,
      onPlayingChanged: (playing) => _isPlaying.value = playing,
      onProgressChanged: (value) => _progress.value = value,
    );
  }

  static const String defaultMusicAsset = 'assets/musics/music.mp3';

  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  late final WebAudioEngine _engine;

  ValueListenable<bool> get isPlayingListenable => _isPlaying;
  ValueListenable<double> get progressListenable => _progress;

  bool get isPlaying => _isPlaying.value;
  double get progress => _progress.value;

  void play() => _engine.play();

  void pause() => _engine.pause();

  void togglePlayPause() {
    if (_isPlaying.value) {
      pause();
    } else {
      play();
    }
  }

  void replay() => _engine.replay();

  void dispose() {
    _engine.dispose();
    _isPlaying.dispose();
    _progress.dispose();
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
  static const double _dockWidth = 148.0;
  static const double _pillRightOverlap = 31.0;

  late final AnimationController _spinController;
  late final AnimationController _replayPulseController;
  late final Animation<double> _replayScaleAnimation;
  final Matrix4 _spinMatrix = Matrix4.identity();

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

    widget.morphAnimation.addListener(_syncDiscSpin);
    widget.musicController.isPlayingListenable.addListener(_syncDiscSpin);
    _syncDiscSpin();
  }

  @override
  void didUpdateWidget(covariant CoverMusicPlayerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.morphAnimation != widget.morphAnimation) {
      oldWidget.morphAnimation.removeListener(_syncDiscSpin);
      widget.morphAnimation.addListener(_syncDiscSpin);
    }
    if (oldWidget.musicController != widget.musicController) {
      oldWidget.musicController.isPlayingListenable.removeListener(_syncDiscSpin);
      widget.musicController.isPlayingListenable.addListener(_syncDiscSpin);
    }
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
    widget.musicController.togglePlayPause();
  }

  void _handleReplay() {
    HapticFeedback.lightImpact();
    widget.musicController.replay();
    _replayPulseController.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.morphAnimation.removeListener(_syncDiscSpin);
    widget.musicController.isPlayingListenable.removeListener(_syncDiscSpin);
    _spinController.dispose();
    _replayPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final baseMargin = size.width >= 960 ? 24.0 : 16.0;
    final dockRight = baseMargin + safePadding.right;
    final dockBottom = baseMargin + safePadding.bottom;

    if (widget.isMorphComplete) {
      return Positioned(
        right: dockRight,
        bottom: dockBottom,
        child: _DockedDvdMusicDock(
          discSize: _discSize,
          dockWidth: _dockWidth,
          pillRightOverlap: _pillRightOverlap,
          coverBgAsset: widget.coverBgAsset,
          coverLogoAsset: widget.coverLogoAsset,
          musicController: widget.musicController,
          spinAnimation: _spinController,
          spinMatrix: _spinMatrix,
          replayScaleAnimation: _replayScaleAnimation,
          onTogglePlayPause: _handleTogglePlayPause,
          onReplay: _handleReplay,
        ),
      );
    }

    final width = size.width;
    final height = size.height;
    final targetCx = width - dockRight - _discSize * 0.5;
    final targetCy = height - dockBottom - _discSize * 0.5;
    final minSide = math.min(width, height);
    final maxSide = math.max(width, height);
    final initialLogoSize = math.min(220.0, math.min(width * 0.56, height * 0.36));

    final staticCoverBg = _CoverArtworkLayer(coverBgAsset: widget.coverBgAsset);
    final staticCoverTextOverlay = _CoverTextOverlay(
      recipientName: widget.recipientName,
      titleScriptStyle: widget.titleScriptStyle,
      coupleGothicStyle: widget.coupleGothicStyle,
      guestIntroStyle: widget.guestIntroStyle,
      guestNameStyle: widget.guestNameStyle,
      onOpenInvitation: widget.onOpenInvitation,
    );

    return AnimatedBuilder(
      animation: widget.morphAnimation,
      child: staticCoverBg,
      builder: (context, coverBg) {
        final rawT = widget.morphAnimation.value.clamp(0.0, 1.0);
        final easeT = Curves.easeInOutCubic.transform(rawT);
        final squareT = Curves.easeInOutCubic.transform((rawT / 0.60).clamp(0.0, 1.0));
        final roundT = Curves.easeInOutCubic.transform(((rawT - 0.03) / 0.55).clamp(0.0, 1.0));
        final dvdDetailsT = Curves.easeOutCubic.transform(((rawT - 0.28) / 0.50).clamp(0.0, 1.0));
        final controlsReveal = Curves.easeOutCubic.transform(
          ((rawT - 0.72) / 0.28).clamp(0.0, 1.0),
        );
        final progressRingAlpha = Curves.easeOut.transform(((rawT - 0.84) / 0.16).clamp(0.0, 1.0));
        final scrimAlpha =
            (1.0 - Curves.easeOutCubic.transform((rawT / 0.52).clamp(0.0, 1.0))) * 0.88;
        final textAlpha = 1.0 - Curves.easeOutCubic.transform((rawT / 0.26).clamp(0.0, 1.0));
        final shadowAlpha = Curves.easeOutCubic.transform(((rawT - 0.10) / 0.50).clamp(0.0, 1.0));

        final baseSide = lerpDouble(minSide, _discSize, easeT)!;
        final excess = (maxSide - minSide) * (1.0 - squareT);
        final curW = width >= height ? baseSide + excess : baseSide;
        final curH = height > width ? baseSide + excess : baseSide;

        // Lintasan vertikal sedikit melengkung agar gerak morph ke pojok kanan bawah mulus.
        final posYFactor = easeT * (0.86 + 0.14 * easeT);
        final cx = lerpDouble(width * 0.5, targetCx, easeT)!;
        final cy = lerpDouble(height * 0.5, targetCy, posYFactor)!;

        final left = cx - curW * 0.5;
        final top = cy - curH * 0.5;
        final radius = math.min(curW, curH) * 0.5 * roundT;
        final logoSize = lerpDouble(initialLogoSize, 38.0, easeT)!;
        final logoYOffset = lerpDouble(-12.0, 0.0, squareT)!;

        return Stack(
          fit: .expand,
          children: [
            if (scrimAlpha > 0.005)
              IgnorePointer(
                child: ColoredBox(color: Colors.black.withValues(alpha: scrimAlpha)),
              ),

            if (controlsReveal > 0.01)
              Positioned(
                right: dockRight + _pillRightOverlap,
                bottom: dockBottom + (_discSize - 44.0) * 0.5,
                width: _dockWidth - _pillRightOverlap,
                height: 44.0,
                child: _SlidingControlPill(
                  reveal: controlsReveal,
                  musicController: widget.musicController,
                  onTogglePlayPause: _handleTogglePlayPause,
                  onReplay: _handleReplay,
                ),
              ),

            Positioned(
              left: left,
              top: top,
              width: curW,
              height: curH,
              child: RepaintBoundary(
                child: _MorphingDvdCard(
                  borderRadius: radius,
                  shadowAlpha: shadowAlpha,
                  logoSize: logoSize,
                  logoYOffset: logoYOffset,
                  dvdDetailsIntensity: dvdDetailsT,
                  progressRingAlpha: progressRingAlpha,
                  spinAnimation: _spinController,
                  spinMatrix: _spinMatrix,
                  musicController: widget.musicController,
                  isInteractive: rawT >= 0.92,
                  onTapDisc: _handleTogglePlayPause,
                  coverLogoAsset: widget.coverLogoAsset,
                  staticBgChild: coverBg,
                ),
              ),
            ),

            if (textAlpha > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: rawT > 0.0,
                  child: Opacity(
                    opacity: textAlpha,
                    child: Transform.scale(
                      scale: lerpDouble(1.0, 0.94, 1.0 - textAlpha)!,
                      child: staticCoverTextOverlay,
                    ),
                  ),
                ),
              ),
          ],
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
      filterQuality: .medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFF000000)),
    );
  }
}

class const _CoverTextOverlay({
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
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(24))),
    padding: const .symmetric(horizontal: 40, vertical: 4),
  );

  @override
  Widget build(BuildContext context) {
    final displayGuest = recipientName.isNotEmpty ? recipientName : 'Tamu Undangan';

    return SafeArea(
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
              ),
            ),
            Align(
              alignment: .bottomCenter,
              child: Padding(
                padding: const .only(bottom: 16),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _MorphingDvdCard({
  required final double borderRadius,
  required final double shadowAlpha,
  required final double logoSize,
  required final double logoYOffset,
  required final double dvdDetailsIntensity,
  required final double progressRingAlpha,
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final InvitationMusicController musicController,
  required final bool isInteractive,
  required final VoidCallback onTapDisc,
  required final String coverLogoAsset,
  required final Widget? staticBgChild,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.all(.circular(borderRadius));

    final Widget clippedDisc = ClipRRect(
      borderRadius: radius,
      clipBehavior: .antiAlias,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: .expand,
          children: [
            _SpinningDiscArt(
              spinAnimation: spinAnimation,
              spinMatrix: spinMatrix,
              logoSize: logoSize,
              logoYOffset: logoYOffset,
              coverLogoAsset: coverLogoAsset,
              bgChild: staticBgChild,
            ),
            if (dvdDetailsIntensity > 0.01) ...[
              IgnorePointer(child: _DvdSpecularSheen(intensity: dvdDetailsIntensity)),
              IgnorePointer(
                child: ValueListenableBuilder<bool>(
                  valueListenable: musicController.isPlayingListenable,
                  builder: (context, isPlaying, _) => CustomPaint(
                    painter: _DvdGroovesPainter(
                      intensity: dvdDetailsIntensity,
                      isActive: isPlaying,
                    ),
                  ),
                ),
              ),
            ],
            if (progressRingAlpha > 0.01)
              IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: musicController.progressListenable,
                  builder: (context, progress, _) => CustomPaint(
                    painter: _DvdProgressRingPainter(progress: progress, alpha: progressRingAlpha),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final Widget shadowedDisc = shadowAlpha > 0.01
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.72 * shadowAlpha),
                  blurRadius: 14 * shadowAlpha,
                  offset: Offset(0, 4 * shadowAlpha),
                ),
              ],
            ),
            child: clippedDisc,
          )
        : clippedDisc;

    if (!isInteractive) return shadowedDisc;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTapDisc, behavior: .opaque, child: shadowedDisc),
    );
  }
}

class const _DockedDvdMusicDock({
  required final double discSize,
  required final double dockWidth,
  required final double pillRightOverlap,
  required final String coverBgAsset,
  required final String coverLogoAsset,
  required final InvitationMusicController musicController,
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final Animation<double> replayScaleAnimation,
  required final VoidCallback onTogglePlayPause,
  required final VoidCallback onReplay,
}) extends StatelessWidget {
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
    final staticDiscVisual = Stack(
      fit: .expand,
      children: [
        _SpinningDiscArt(
          spinAnimation: spinAnimation,
          spinMatrix: spinMatrix,
          logoSize: 38.0,
          logoYOffset: 0.0,
          coverLogoAsset: coverLogoAsset,
          bgChild: _CoverArtworkLayer(coverBgAsset: coverBgAsset),
        ),
        const IgnorePointer(child: _DvdSpecularSheen(intensity: 1.0)),
      ],
    );

    final staticProgressRing = IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: musicController.progressListenable,
        builder: (context, progress, _) =>
            CustomPaint(painter: _DvdProgressRingPainter(progress: progress, alpha: 1.0)),
      ),
    );

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
            child: _SlidingControlPill(
              reveal: 1.0,
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
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: _discShadowDecoration,
                  child: ClipOval(
                    clipBehavior: .antiAlias,
                    child: ColoredBox(
                      color: Colors.black,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: musicController.isPlayingListenable,
                        child: staticDiscVisual,
                        builder: (context, isPlaying, discVisual) => Semantics(
                          button: true,
                          label: isPlaying ? 'Jeda musik' : 'Putar musik',
                          child: Tooltip(
                            message: isPlaying ? 'Jeda musik' : 'Putar musik',
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: onTogglePlayPause,
                                behavior: .opaque,
                                child: Stack(
                                  fit: .expand,
                                  children: [
                                    ?discVisual,
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _DvdGroovesPainter(
                                          intensity: 1.0,
                                          isActive: isPlaying,
                                        ),
                                      ),
                                    ),
                                    staticProgressRing,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class const _SpinningDiscArt({
  required final Animation<double> spinAnimation,
  required final Matrix4 spinMatrix,
  required final double logoSize,
  required final double logoYOffset,
  required final String coverLogoAsset,
  required final Widget? bgChild,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Widget centeredLogo = Center(
      child: SizedBox(
        width: logoSize,
        height: logoSize,
        child: Image.asset(
          coverLogoAsset,
          fit: .contain,
          filterQuality: .medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );

    final art = Stack(
      fit: .expand,
      children: [
        ?bgChild,
        if (logoYOffset == 0.0)
          centeredLogo
        else
          Transform.translate(offset: Offset(0, logoYOffset), child: centeredLogo),
      ],
    );

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

class const _DvdSpecularSheen({required final double intensity}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final highlightStrong = Color.fromRGBO(255, 255, 255, 0.16 * intensity);
    final highlightSoft = Color.fromRGBO(255, 255, 255, 0.08 * intensity);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: .circle,
        gradient: SweepGradient(
          colors: [
            Colors.transparent,
            highlightStrong,
            Colors.transparent,
            highlightSoft,
            Colors.transparent,
            highlightStrong,
            Colors.transparent,
          ],
          stops: const [0.0, 0.12, 0.28, 0.45, 0.62, 0.78, 1.0],
        ),
      ),
    );
  }
}

class const _SlidingControlPill({
  required final double reveal,
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
    final pill = DecoratedBox(
      decoration: _pillDecoration,
      child: Padding(
        padding: const .only(left: 6, right: 35),
        child: Row(
          mainAxisSize: .max,
          children: [
            _MiniPlayerButton(
              icon: Icons.replay_rounded,
              tooltip: 'Putar ulang musik',
              iconSize: 18,
              onTap: onReplay,
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<bool>(
              valueListenable: musicController.isPlayingListenable,
              builder: (context, isPlaying, _) => _MiniPlayerButton(
                icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tooltip: isPlaying ? 'Jeda musik' : 'Putar musik',
                iconSize: 20,
                onTap: onTogglePlayPause,
              ),
            ),
          ],
        ),
      ),
    );

    if (reveal >= 0.999) return pill;

    return ClipRect(
      child: Transform.translate(offset: Offset((1.0 - reveal) * 90.0, 0.0), child: pill),
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = math.min(size.width, size.height) * 0.5;
    if (radius <= 2.0) return;

    _groovePaint.color = Colors.white.withValues(alpha: 0.09 * intensity);
    canvas
      ..drawCircle(center, radius * 0.88, _groovePaint)
      ..drawCircle(center, radius * 0.78, _groovePaint)
      ..drawCircle(center, radius * 0.68, _groovePaint)
      ..drawCircle(center, radius * 0.56, _groovePaint)
      ..drawCircle(center, radius * 0.42, _groovePaint);

    // Cincin hub DVD tengah + lubang spindle.
    _hubRingPaint.color = Colors.white.withValues(alpha: 0.22 * intensity);
    canvas.drawCircle(center, math.max(4.5, radius * 0.21), _hubRingPaint);

    _groovePaint.color = Colors.white.withValues(alpha: 0.45 * intensity);
    canvas.drawCircle(center, math.max(4.5, radius * 0.21), _groovePaint);

    _spindleHolePaint.color = Colors.black.withValues(alpha: 0.92 * intensity);
    canvas.drawCircle(center, math.max(2.2, radius * 0.10), _spindleHolePaint);

    _groovePaint.color = Colors.white.withValues(alpha: 0.55 * intensity);
    canvas.drawCircle(center, math.max(2.2, radius * 0.10), _groovePaint);

    final rimAlpha = (isActive ? 0.42 : 0.22) * intensity;
    _rimPaint.color = Colors.white.withValues(alpha: rimAlpha);
    canvas.drawCircle(center, radius - 0.8, _rimPaint);
  }

  @override
  bool shouldRepaint(_DvdGroovesPainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.isActive != isActive;
}

final class _DvdProgressRingPainter({required final double progress, required final double alpha})
    extends CustomPainter {
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
    final radius = math.min(size.width, size.height) * 0.5 - 1.2;
    if (radius <= 2.0) return;
    final center = Offset(size.width * 0.5, size.height * 0.5);

    _trackPaint.color = Colors.white.withValues(alpha: 0.14 * alpha);
    canvas.drawCircle(center, radius, _trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0.002) return;

    _arcPaint.color = Colors.white.withValues(alpha: 0.88 * alpha);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi * 0.5, clamped * 2.0 * math.pi, false, _arcPaint);
  }

  @override
  bool shouldRepaint(_DvdProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.alpha != alpha;
}
