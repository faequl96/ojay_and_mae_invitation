import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OjayMaeWeddingApp());
}

// ============================================================================
// KONSTANTA ASET & TEMA TYPOGRAPHY (SESUAI PECAHAN 1912 & UO 1912.PDF)
// ============================================================================
abstract final class InvitationAssets {
  static const String coverBg = 'assets/images/COVER-1-BG-tengkorak.png';
  static const String coverInitialFF = 'assets/images/COVER-1-inisial-FF.png';
  static const String heroBg = 'assets/images/2-BG-tengkorak.png';
  static const String skullCouple = 'assets/images/2-tengkorak-ojay-mae.png';
  static const String flowerGroom =
      'assets/images/3-Bunga-samping-tengkorak.png';
  static const String leafGroom = 'assets/images/3-Daun-Font-Ojay.png';
  static const String skullGroom = 'assets/images/3-tengkorak-ojay.png';
  static const String flowerBride =
      'assets/images/4-Bunga-samping-tengkorak-wanita.png';
  static const String leafBride = 'assets/images/4-Daun-Font-Mae.png';
  static const String skullBride = 'assets/images/4-Tengkorak-Mae.png';
  static const String flowerGift = 'assets/images/6-Bunga-Wedding-Gift.png';
}

abstract final class GothicTheme {
  static const Color bgBlack = Color(0xFF050505);
  static const Color surfaceBlack = Color(0xFF0E0E0E);
  static const Color boneWhite = Color(0xFFF2EFE9);
  static const Color silverMuted = Color(0xFFA6A29A);
  static const Color charcoalBorder = Color(0xFF2C2C2C);

  static const String fontGothicMain = 'AngelWish';
  static const String fontGothicAlt = 'AngelRhapsody';
  static const String fontScript = 'BirdsOfParadise';

  static TextStyle gothicTitle({double size = 40, Color color = boneWhite}) =>
      TextStyle(
        fontFamily: fontGothicMain,
        fontFamilyFallback: const ['serif'],
        fontSize: size,
        color: color,
        height: 1.15,
        letterSpacing: 1.4,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 16, offset: Offset(0, 4)),
        ],
      );

  static TextStyle gothicDisplay({double size = 34, Color color = boneWhite}) =>
      TextStyle(
        fontFamily: fontGothicAlt,
        fontFamilyFallback: const ['serif'],
        fontSize: size,
        fontWeight: .bold,
        color: color,
        letterSpacing: 1.8,
      );

  static TextStyle scriptSubtitle({
    double size = 26,
    Color color = boneWhite,
  }) => TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: const ['cursive', 'serif'],
    fontSize: size,
    fontStyle: .italic,
    color: color,
    height: 1.3,
  );

  static TextStyle bodySerif({
    double size = 14,
    Color color = silverMuted,
    FontWeight weight = .normal,
  }) => TextStyle(
    fontFamily: 'Georgia',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.65,
    letterSpacing: 0.4,
  );
}

class OjayMaeWeddingApp extends StatelessWidget {
  const OjayMaeWeddingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Wedding of Ojay & Mae — 19.12.2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: .dark,
        scaffoldBackgroundColor: GothicTheme.bgBlack,
        colorScheme: const ColorScheme.dark(
          primary: GothicTheme.boneWhite,
          surface: GothicTheme.surfaceBlack,
        ),
      ),
      home: const InvitationMasterScreen(),
    );
  }
}

// ============================================================================
// MASTER SCREEN: MENGATUR GATE COVER, RESPONSIVE DESKTOP & SEAMLESS SCROLL
// ============================================================================
class InvitationMasterScreen extends StatefulWidget {
  const InvitationMasterScreen({super.key});

  @override
  State<InvitationMasterScreen> createState() => _InvitationMasterScreenState();
}

class _InvitationMasterScreenState extends State<InvitationMasterScreen>
    with TickerProviderStateMixin {
  bool _isInvitationOpened = false;
  late final AnimationController _gateController;
  late final AnimationController _ambientController;
  final ScrollController _scrollController = ScrollController();

  // GlobalKeys untuk navigasi cepat di mode Desktop
  final _heroKey = GlobalKey();
  final _coupleKey = GlobalKey();
  final _eventKey = GlobalKey();
  final _giftKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _gateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _gateController.dispose();
    _ambientController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openInvitation() {
    HapticFeedback.mediumImpact();
    _gateController.forward().then((_) {
      if (mounted) setState(() => _isInvitationOpened = true);
    });
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 960;

    return Scaffold(
      backgroundColor: GothicTheme.bgBlack,
      body: Stack(
        fit: .expand,
        children: [
          // 1. LAYER UTAMA: ADAPTIVE DESKTOP (SPLIT SCREEN) ATAU MOBILE
          if (isDesktop)
            Row(
              children: [
                // PANEL KIRI DESKTOP: Sticky Gothic Artwork & Quick Navigation
                Expanded(
                  flex: 5,
                  child: _DesktopShowcaseSidebar(
                    ambientAnimation: _ambientController,
                    onSelectSection: (index) {
                      final keys = [_heroKey, _coupleKey, _eventKey, _giftKey];
                      _scrollToSection(keys[index]);
                    },
                  ),
                ),
                Container(width: 1, color: GothicTheme.charcoalBorder),
                // PANEL KANAN DESKTOP: Seamless Continuous Invitation Stream
                Expanded(
                  flex: 6,
                  child: _buildContinuousInvitationStream(isDesktop: true),
                ),
              ],
            )
          else
            _buildContinuousInvitationStream(isDesktop: false),

          // 2. LAYER PARTIKEL ABU GOTIK (MENYATUKAN SELURUH LAYAR)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) => CustomPaint(
                painter: GothicAshParticlePainter(
                  progress: _ambientController.value,
                ),
                size: .infinite,
              ),
            ),
          ),

          // 3. LAYER GATE COVER (HALAMAN 1 PDF - BUKA UNDANGAN)
          if (!_isInvitationOpened)
            AnimatedBuilder(
              animation: _gateController,
              builder: (context, child) {
                final curveVal = Curves.easeInOutExpo.transform(
                  _gateController.value,
                );
                return Transform.translate(
                  offset: Offset(0, -size.height * curveVal),
                  child: Opacity(
                    opacity: (1.0 - curveVal).clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: _CoverGateOverlay(
                onOpenPressed: _openInvitation,
                ambientAnimation: _ambientController,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContinuousInvitationStream({required bool isDesktop}) {
    return Stack(
      children: [
        // Garis Vertikal Tipis Menerus (Spine) agar seluruh section terasa menyatu
        Positioned.fill(
          child: Center(
            child: Container(
              width: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: .topCenter,
                  end: .bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.07),
                    Colors.white.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 760 : 540),
              child: Column(
                children: [
                  // SECTION 1: HERO (Halaman 2 PDF)
                  KeyedSubtree(
                    key: _heroKey,
                    child: const _SeamlessHeroSection(),
                  ),

                  // TRANSISI ORNAMEN PENYAMBUNG
                  const _SeamlessVineConnector(),

                  // SECTION 2: MEMPELAI PRIA & WANITA (Halaman 3 & 4 PDF)
                  KeyedSubtree(
                    key: _coupleKey,
                    child: _SeamlessCoupleSection(isDesktop: isDesktop),
                  ),

                  const _SeamlessVineConnector(flipVertical: true),

                  // SECTION 3: COUNTDOWN & ACARA PERNIKAHAN (Halaman 5 PDF)
                  KeyedSubtree(
                    key: _eventKey,
                    child: _SeamlessEventSection(isDesktop: isDesktop),
                  ),

                  const _SeamlessVineConnector(),

                  // SECTION 4: WEDDING GIFT / AMPLOP DIGITAL (Halaman 6 PDF)
                  KeyedSubtree(
                    key: _giftKey,
                    child: _SeamlessWeddingGiftSection(isDesktop: isDesktop),
                  ),

                  // SECTION PENUTUP
                  const _SeamlessFooterSection(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PANEL SAMPING DESKTOP (STICKY SHOWCASE)
// ============================================================================
class _DesktopShowcaseSidebar extends StatelessWidget {
  final Animation<double> ambientAnimation;
  final ValueChanged<int> onSelectSection;

  const _DesktopShowcaseSidebar({
    required this.ambientAnimation,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        // Background Tengkorak dengan efek Slow Zoom (Ken Burns)
        AnimatedBuilder(
          animation: ambientAnimation,
          builder: (context, child) {
            final scale =
                1.05 + 0.06 * math.sin(ambientAnimation.value * 2 * math.pi);
            return Transform.scale(scale: scale, child: child);
          },
          child: const Opacity(
            opacity: 0.28,
            child: InvitationAssetImage(
              assetPath: InvitationAssets.coverBg,
              fit: .cover,
            ),
          ),
        ),
        // Vignette Gelap
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.9,
              colors: [
                Colors.transparent,
                GothicTheme.bgBlack.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
        // Konten Sticky
        Padding(
          padding: const .all(48),
          child: Column(
            mainAxisAlignment: .spaceBetween,
            crossAxisAlignment: .start,
            children: [
              // Monogram FF Kecil & Tanggal di Pojok Atas
              Row(
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: InvitationAssetImage(
                      assetPath: InvitationAssets.coverInitialFF,
                      fit: .contain,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '19 . 12 . 2026',
                    style: GothicTheme.bodySerif(
                      size: 13,
                      color: GothicTheme.boneWhite,
                      weight: .bold,
                    ).copyWith(letterSpacing: 4),
                  ),
                ],
              ),

              // Ilustrasi Tengkorak Tengah & Kutipan
              Center(
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    AnimatedGothicOrnament(
                      floatAmplitude: 8,
                      swayDegrees: 1.5,
                      duration: const Duration(seconds: 5),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: const InvitationAssetImage(
                          assetPath: InvitationAssets.skullCouple,
                          fit: .contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Fauzi & Fitri',
                      style: GothicTheme.gothicTitle(size: 46),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"Till death do us part"',
                      style: GothicTheme.scriptSubtitle(
                        size: 24,
                        color: GothicTheme.silverMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Navigasi Cepat Antar-Section untuk Desktop
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _DesktopNavPill(
                    label: 'Pembuka',
                    onTap: () => onSelectSection(0),
                  ),
                  _DesktopNavPill(
                    label: 'Mempelai',
                    onTap: () => onSelectSection(1),
                  ),
                  _DesktopNavPill(
                    label: 'Acara & Lokasi',
                    onTap: () => onSelectSection(2),
                  ),
                  _DesktopNavPill(
                    label: 'Wedding Gift',
                    onTap: () => onSelectSection(3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopNavPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DesktopNavPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: .circular(30),
      child: Container(
        padding: const .symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: .circular(30),
          border: .all(color: Colors.white24, width: 0.8),
        ),
        child: Text(
          label,
          style: GothicTheme.bodySerif(size: 12, color: GothicTheme.boneWhite),
        ),
      ),
    );
  }
}

// ============================================================================
// COVER GATE OVERLAY (HALAMAN 1 PDF)
// ============================================================================
class _CoverGateOverlay extends StatelessWidget {
  final VoidCallback onOpenPressed;
  final Animation<double> ambientAnimation;

  const _CoverGateOverlay({
    required this.onOpenPressed,
    required this.ambientAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GothicTheme.bgBlack,
      child: Stack(
        fit: .expand,
        children: [
          // Background Tengkorak Halaman 1
          const Opacity(
            opacity: 0.35,
            child: InvitationAssetImage(
              assetPath: InvitationAssets.coverBg,
              fit: .cover,
            ),
          ),
          // Gradasi Vignette
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                colors: [
                  GothicTheme.bgBlack.withValues(alpha: 0.7),
                  GothicTheme.bgBlack.withValues(alpha: 0.3),
                  GothicTheme.bgBlack.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const .symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisAlignment: .center,
                children: [
                  const Spacer(),
                  // Inisial Monogram FF dengan Animasi Bernapas & Mengambang
                  AnimatedGothicOrnament(
                    floatAmplitude: 7,
                    scaleAmplitude: 0.04,
                    swayDegrees: 1.2,
                    duration: const Duration(seconds: 4),
                    child: const SizedBox(
                      width: 190,
                      height: 190,
                      child: InvitationAssetImage(
                        assetPath: InvitationAssets.coverInitialFF,
                        fit: .contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Pernikahan Kami',
                    style: GothicTheme.scriptSubtitle(size: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fauzi & Fitri',
                    textAlign: .center,
                    style: GothicTheme.gothicTitle(size: 46),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ojay & Mae',
                    textAlign: .center,
                    style: GothicTheme.gothicDisplay(
                      size: 24,
                      color: GothicTheme.silverMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Kepada Yth',
                    style: GothicTheme.bodySerif(
                      size: 13,
                      color: GothicTheme.silverMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tamu Undangan',
                    style: GothicTheme.bodySerif(
                      size: 18,
                      color: GothicTheme.boneWhite,
                      weight: .bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tombol Buka Undangan dengan Efek Pulse
                  _AnimatedOpenButton(onPressed: onOpenPressed),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedOpenButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AnimatedOpenButton({required this.onPressed});

  @override
  State<_AnimatedOpenButton> createState() => _AnimatedOpenButtonState();
}

class _AnimatedOpenButtonState extends State<_AnimatedOpenButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 4.0 + (_pulseController.value * 10.0);
        return Container(
          decoration: BoxDecoration(
            borderRadius: .circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(
                  alpha: 0.12 + (_pulseController.value * 0.15),
                ),
                blurRadius: glow,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ElevatedButton.icon(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: GothicTheme.boneWhite,
          foregroundColor: GothicTheme.bgBlack,
          padding: const .symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: .circular(32)),
          elevation: 0,
        ),
        icon: const Icon(Icons.mail_lock_outlined, size: 18),
        label: const Text(
          'Buka Undangan',
          style: TextStyle(fontWeight: .bold, fontSize: 14, letterSpacing: 1.1),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 1: SEAMLESS HERO (HALAMAN 2 PDF - TILL DEATH DO US PART)
// ============================================================================
class _SeamlessHeroSection extends StatelessWidget {
  const _SeamlessHeroSection();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: .center,
      children: [
        // Background 2-BG-tengkorak.png dengan ShaderMask agar menyatu tanpa garis potong
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: .topCenter,
              end: .bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.18, 0.82, 1.0],
            ).createShader(rect),
            blendMode: .dstIn,
            child: const Opacity(
              opacity: 0.30,
              child: InvitationAssetImage(
                assetPath: InvitationAssets.heroBg,
                fit: .cover,
              ),
            ),
          ),
        ),
        Padding(
          padding: const .fromLTRB(24, 72, 24, 48),
          child: Column(
            children: [
              Text(
                'Pernikahan Kami',
                style: GothicTheme.scriptSubtitle(size: 30),
              ),
              const SizedBox(height: 12),
              // Nama Ojay & Mae dengan Daun Beranimasi
              Row(
                mainAxisAlignment: .center,
                children: [
                  AnimatedGothicOrnament(
                    swayDegrees: 6,
                    floatAmplitude: 3,
                    alignment: .centerRight,
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: InvitationAssetImage(
                        assetPath: InvitationAssets.leafGroom,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const .symmetric(horizontal: 12),
                    child: Text(
                      'Ojay & Mae',
                      style: GothicTheme.gothicTitle(size: 46),
                    ),
                  ),
                  AnimatedGothicOrnament(
                    swayDegrees: -6,
                    floatAmplitude: 3,
                    alignment: .centerLeft,
                    child: Transform.flip(
                      flipX: true,
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: InvitationAssetImage(
                          assetPath: InvitationAssets.leafBride,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Ilustrasi Utama 2-tengkorak-ojay-mae.png dengan Animasi Mengambang
              AnimatedGothicOrnament(
                floatAmplitude: 9,
                swayDegrees: 1.8,
                scaleAmplitude: 0.02,
                duration: const Duration(seconds: 5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 330),
                  child: const InvitationAssetImage(
                    assetPath: InvitationAssets.skullCouple,
                    fit: .contain,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Till death do us part',
                style: GothicTheme.scriptSubtitle(
                  size: 32,
                  color: GothicTheme.boneWhite,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const .symmetric(horizontal: 22, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                child: Text(
                  'Sabtu, 19 Desember 2026',
                  style: GothicTheme.bodySerif(
                    size: 16,
                    color: GothicTheme.boneWhite,
                    weight: .bold,
                  ).copyWith(letterSpacing: 2.0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SECTION 2: PROFIL MEMPELAI (HALAMAN 3 & 4 PDF DIGABUNG SECARA SEAMLESS)
// ============================================================================
class _SeamlessCoupleSection extends StatelessWidget {
  final bool isDesktop;
  const _SeamlessCoupleSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    const groomCard = _CoupleProfileCard(
      nickname: 'Ojay',
      fullName: 'Achmad Fauzi',
      parentInfo:
          'Putra Bungsu dari Bpk Moch Noer (alm)\ndan Ibu Rochilah (almh)',
      skullAsset: InvitationAssets.skullGroom,
      flowerAsset: InvitationAssets.flowerGroom,
      leafAsset: InvitationAssets.leafGroom,
      isFlowerLeft: true,
    );

    const brideCard = _CoupleProfileCard(
      nickname: 'Mae',
      fullName: 'Fitri Anggraini',
      parentInfo: 'Putri Bungsu dari Bpk Aryanto\ndan Ibu Nami',
      skullAsset: InvitationAssets.skullBride,
      flowerAsset: InvitationAssets.flowerBride,
      leafAsset: InvitationAssets.leafBride,
      isFlowerLeft: false,
    );

    return Padding(
      padding: const .symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Text(
            'We Are Getting Married',
            textAlign: .center,
            style: GothicTheme.scriptSubtitle(size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            "Assalamu'alaikum Warahmatullaahi Wabarakaatuh",
            textAlign: .center,
            style: GothicTheme.scriptSubtitle(
              size: 20,
              color: GothicTheme.boneWhite,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'Maha Suci Allah yang telah menciptakan makhluk-Nya berpasang-pasangan. '
              'Ya Allah semoga ridho-Mu tercurah mengiringi pernikahan kami.',
              textAlign: .center,
              style: GothicTheme.bodySerif(size: 14),
            ),
          ),
          const SizedBox(height: 44),

          // Pada layar Desktop lebar, tampilkan Ojay & Mae berdampingan;
          // pada Mobile, tampilkan mengalir secara vertikal.
          if (isDesktop)
            Row(
              crossAxisAlignment: .start,
              children: [
                const Expanded(child: groomCard),
                Padding(
                  padding: const .symmetric(horizontal: 12, vertical: 140),
                  child: AnimatedGothicOrnament(
                    scaleAmplitude: 0.08,
                    swayDegrees: 4,
                    child: Text('&', style: GothicTheme.gothicTitle(size: 64)),
                  ),
                ),
                const Expanded(child: brideCard),
              ],
            )
          else ...[
            groomCard,
            Padding(
              padding: const .symmetric(vertical: 28),
              child: AnimatedGothicOrnament(
                scaleAmplitude: 0.08,
                swayDegrees: 4,
                child: Text('&', style: GothicTheme.gothicTitle(size: 72)),
              ),
            ),
            brideCard,
          ],
        ],
      ),
    );
  }
}

class _CoupleProfileCard extends StatelessWidget {
  final String nickname;
  final String fullName;
  final String parentInfo;
  final String skullAsset;
  final String flowerAsset;
  final String leafAsset;
  final bool isFlowerLeft;

  const _CoupleProfileCard({
    required this.nickname,
    required this.fullName,
    required this.parentInfo,
    required this.skullAsset,
    required this.flowerAsset,
    required this.leafAsset,
    required this.isFlowerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Arch Frame dengan Tengkorak & Ornamen Bunga Beranimasi
        SizedBox(
          width: 260,
          height: 330,
          child: Stack(
            clipBehavior: .none,
            alignment: .center,
            children: [
              // Bingkai Kubah (Arch Pill Outline) sesuai PDF Halaman 3 & 4
              Container(
                width: 220,
                height: 300,
                decoration: BoxDecoration(
                  color: GothicTheme.surfaceBlack,
                  borderRadius: const .vertical(
                    top: Radius.circular(120),
                    bottom: Radius.circular(28),
                  ),
                  border: .all(color: GothicTheme.boneWhite, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.05),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const .vertical(
                    top: Radius.circular(118),
                    bottom: Radius.circular(26),
                  ),
                  child: Padding(
                    padding: const .only(top: 16),
                    child: AnimatedGothicOrnament(
                      floatAmplitude: 5,
                      swayDegrees: 1.0,
                      duration: const Duration(seconds: 4),
                      child: InvitationAssetImage(
                        assetPath: skullAsset,
                        fit: .contain,
                      ),
                    ),
                  ),
                ),
              ),

              // Ornamen Bunga Mawar di Sudut Arch (3-Bunga / 4-Bunga) dengan Animasi Goyangan Angin
              Positioned(
                bottom: -16,
                left: isFlowerLeft ? -22 : null,
                right: !isFlowerLeft ? -22 : null,
                child: AnimatedGothicOrnament(
                  swayDegrees: isFlowerLeft ? 4.5 : -4.5,
                  floatAmplitude: 4,
                  scaleAmplitude: 0.03,
                  alignment: isFlowerLeft ? .bottomLeft : .bottomRight,
                  duration: const Duration(milliseconds: 3800),
                  child: SizedBox(
                    width: 145,
                    height: 175,
                    child: InvitationAssetImage(
                      assetPath: flowerAsset,
                      fit: .contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Nama Panggilan (Ojay / Mae) Diapit Daun Beranimasi (3-Daun / 4-Daun)
        Row(
          mainAxisAlignment: .center,
          children: [
            AnimatedGothicOrnament(
              swayDegrees: 8,
              alignment: .centerRight,
              child: SizedBox(
                width: 36,
                height: 28,
                child: InvitationAssetImage(assetPath: leafAsset),
              ),
            ),
            Padding(
              padding: const .symmetric(horizontal: 10),
              child: Text(nickname, style: GothicTheme.gothicDisplay(size: 28)),
            ),
            AnimatedGothicOrnament(
              swayDegrees: -8,
              alignment: .centerLeft,
              child: Transform.flip(
                flipX: true,
                child: SizedBox(
                  width: 36,
                  height: 28,
                  child: InvitationAssetImage(assetPath: leafAsset),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Nama Lengkap
        Text(
          fullName,
          textAlign: .center,
          style: GothicTheme.gothicTitle(size: 36),
        ),
        const SizedBox(height: 10),

        // Silsilah Orang Tua
        Text(
          parentInfo,
          textAlign: .center,
          style: GothicTheme.bodySerif(size: 13.5),
        ),
      ],
    );
  }
}

// ============================================================================
// SECTION 3: ACARA PERNIKAHAN & LIVE COUNTDOWN (HALAMAN 5 PDF)
// ============================================================================
class _SeamlessEventSection extends StatefulWidget {
  final bool isDesktop;
  const _SeamlessEventSection({required this.isDesktop});

  @override
  State<_SeamlessEventSection> createState() => _SeamlessEventSectionState();
}

class _SeamlessEventSectionState extends State<_SeamlessEventSection> {
  static final DateTime _weddingDate = DateTime(2026, 12, 19, 9, 0);
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_updateRemaining);
    });
  }

  void _updateRemaining() {
    final diff = _weddingDate.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _showMapsPlaceholder(
    BuildContext context,
    String title,
    String address,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GothicTheme.boneWhite,
        content: Text(
          'Membuka Google Maps: $title ($address)',
          style: const TextStyle(color: GothicTheme.bgBlack, fontWeight: .bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Padding(
      padding: const .symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Text(
            'Acara Pernikahan',
            textAlign: .center,
            style: GothicTheme.gothicTitle(size: 42),
          ),
          const SizedBox(height: 24),

          // 4 Kotak Putih Countdown sesuai Halaman 5 PDF
          Row(
            mainAxisAlignment: .center,
            children: [
              _CountdownBox(value: '$days', label: 'Hari'),
              const SizedBox(width: 12),
              _CountdownBox(
                value: hours.toString().padLeft(2, '0'),
                label: 'Jam',
              ),
              const SizedBox(width: 12),
              _CountdownBox(
                value: minutes.toString().padLeft(2, '0'),
                label: 'Menit',
              ),
              const SizedBox(width: 12),
              _CountdownBox(
                value: seconds.toString().padLeft(2, '0'),
                label: 'Detik',
              ),
            ],
          ),
          const SizedBox(height: 28),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'Merupakan suatu kehormatan dan kebahagiaan bagi kami apabila '
              'Bapak/Ibu/Saudara/i berkenan hadir untuk memberikan doa restu '
              'kepada Kami.\nyang akan diselenggarakan pada :',
              textAlign: .center,
              style: GothicTheme.bodySerif(size: 14),
            ),
          ),
          const SizedBox(height: 36),

          // Detail Akad Nikah & Acara Tasyakuran
          _EventDetailCard(
            title: 'Akad Nikah',
            dateText: 'SABTU, 19 DESEMBER 2026',
            timeText: '09:00 WIB sd Selesai',
            venueName: 'KUA BENDA',
            address: 'Jl. Adi Sucipto No.18, RT.001/RW.009,\nBelendung, Kec. Benda, Kota Tangerang, Banten 15123',
            onMapsTap: () => _showMapsPlaceholder(
              context,
              'KUA Benda',
              'Jl. Adi Sucipto No.18, Kota Tangerang',
            ),
          ),
          const SizedBox(height: 28),
          _EventDetailCard(
            title: 'Acara Tasyakuran',
            dateText: 'SABTU, 19 DESEMBER 2026',
            timeText: 'Setelah Akad Nikah s/d Selesai',
            venueName: 'Kediaman Mempelai Wanita',
            address: 'Jl. Halim Perdana Kusuma, Kp. Jurumudi Pajang RT.02/RW.01\nKec. Benda Kel. Pajang, Kota Tangerang, Banten',
            onMapsTap: () => _showMapsPlaceholder(
              context,
              'Kediaman Mempelai Wanita',
              'Jl. Halim Perdana Kusuma, Pajang, Benda',
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownBox extends StatelessWidget {
  final String value;
  final String label;

  const _CountdownBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 76,
      decoration: BoxDecoration(
        color: GothicTheme.boneWhite,
        borderRadius: .circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 24,
              fontWeight: .bold,
              color: GothicTheme.bgBlack,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: .w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailCard extends StatelessWidget {
  final String title;
  final String dateText;
  final String timeText;
  final String venueName;
  final String address;
  final VoidCallback onMapsTap;

  const _EventDetailCard({
    required this.title,
    required this.dateText,
    required this.timeText,
    required this.venueName,
    required this.address,
    required this.onMapsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: .infinity,
      padding: const .symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: GothicTheme.surfaceBlack.withValues(alpha: 0.85),
        borderRadius: .circular(24),
        border: .all(color: GothicTheme.charcoalBorder, width: 1.2),
      ),
      child: Column(
        children: [
          Text(title, style: GothicTheme.gothicTitle(size: 36)),
          const SizedBox(height: 16),
          Text(
            dateText,
            textAlign: .center,
            style: GothicTheme.bodySerif(
              size: 16,
              color: GothicTheme.boneWhite,
              weight: .bold,
            ).copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            timeText,
            style: GothicTheme.bodySerif(
              size: 14,
              color: GothicTheme.boneWhite,
            ),
          ),
          const SizedBox(height: 18),
          const Icon(
            Icons.location_on_outlined,
            color: GothicTheme.boneWhite,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            venueName,
            textAlign: .center,
            style: GothicTheme.bodySerif(
              size: 16,
              color: GothicTheme.boneWhite,
              weight: .bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            address,
            textAlign: .center,
            style: GothicTheme.bodySerif(size: 13),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: onMapsTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: GothicTheme.boneWhite,
              foregroundColor: GothicTheme.bgBlack,
              padding: const .symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: .circular(24)),
            ),
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text(
              'Google Maps',
              style: TextStyle(fontWeight: .bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION 4: WEDDING GIFT / AMPLOP DIGITAL (HALAMAN 6 PDF)
// ============================================================================
class _SeamlessWeddingGiftSection extends StatelessWidget {
  final bool isDesktop;
  const _SeamlessWeddingGiftSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    const fauziCard = _BankGiftCard(
      accountHolder: 'ACHMAD FAUZI',
      accountNumber: '6040564266',
      bankName: 'BCA',
      ornamentAlignRight: true,
    );

    const fitriCard = _BankGiftCard(
      accountHolder: 'FITRI ANGGRAINI',
      accountNumber: '5390800152',
      bankName: 'BCA',
      ornamentAlignRight: false,
    );

    return Padding(
      padding: const .symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Text(
            'Wedding Gift',
            textAlign: .center,
            style: GothicTheme.gothicTitle(size: 42),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'Doa Restu Anda merupakan karunia yang sangat berarti bagi kami.\n'
              'Namun jika memberi adalah ungkapan tanda kasih Anda,\n'
              'Anda dapat memberi kado secara cashless.',
              textAlign: .center,
              style: GothicTheme.bodySerif(size: 14),
            ),
          ),
          const SizedBox(height: 36),

          if (isDesktop)
            const Row(
              children: [
                Expanded(child: fauziCard),
                SizedBox(width: 20),
                Expanded(child: fitriCard),
              ],
            )
          else ...[
            fauziCard,
            const SizedBox(height: 24),
            fitriCard,
          ],
        ],
      ),
    );
  }
}

class _BankGiftCard extends StatelessWidget {
  final String accountHolder;
  final String accountNumber;
  final String bankName;
  final bool ornamentAlignRight;

  const _BankGiftCard({
    required this.accountHolder,
    required this.accountNumber,
    required this.bankName,
    required this.ornamentAlignRight,
  });

  void _copyAccountNumber(BuildContext context) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GothicTheme.boneWhite,
        behavior: .floating,
        content: Text(
          'Nomor rekening $accountHolder ($accountNumber) berhasil disalin!',
          style: const TextStyle(color: GothicTheme.bgBlack, fontWeight: .bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: .none,
      children: [
        // Ornamen Bunga 6-Bunga-Wedding-Gift.png yang berayun lembut di belakang kartu
        Positioned(
          top: -24,
          right: ornamentAlignRight ? -18 : null,
          left: !ornamentAlignRight ? -18 : null,
          child: AnimatedGothicOrnament(
            swayDegrees: ornamentAlignRight ? 5 : -5,
            floatAmplitude: 5,
            duration: const Duration(seconds: 4),
            child: Opacity(
              opacity: 0.55,
              child: SizedBox(
                width: 120,
                height: 120,
                child: InvitationAssetImage(
                  assetPath: InvitationAssets.flowerGift,
                  fit: .contain,
                ),
              ),
            ),
          ),
        ),
        // Kartu ATM Bergaya Monokrom Elegan
        Container(
          width: .infinity,
          padding: const .all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: .topLeft,
              end: .bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF0B0B0B)],
            ),
            borderRadius: .circular(20),
            border: .all(color: Colors.white30, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  // Chip Kartu Simulasi
                  Container(
                    width: 40,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: .circular(6),
                      border: .all(color: Colors.white54, width: 0.8),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: .end,
                    children: [
                      Text(
                        bankName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: .w900,
                          fontStyle: .italic,
                          letterSpacing: 1.5,
                          color: GothicTheme.boneWhite,
                        ),
                      ),
                      const Text(
                        'GRUP BCA',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.2,
                          color: GothicTheme.silverMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                accountHolder,
                style: GothicTheme.bodySerif(
                  size: 14,
                  color: GothicTheme.boneWhite,
                  weight: .bold,
                ).copyWith(letterSpacing: 1.6),
              ),
              const SizedBox(height: 6),
              Text(
                accountNumber,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 23,
                  fontWeight: .bold,
                  letterSpacing: 2.5,
                  color: GothicTheme.boneWhite,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: .centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _copyAccountNumber(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GothicTheme.boneWhite,
                    side: const BorderSide(color: GothicTheme.boneWhite),
                    shape: RoundedRectangleBorder(borderRadius: .circular(20)),
                    padding: const .symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text(
                    'Salin Norek',
                    style: TextStyle(fontSize: 12, fontWeight: .bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SECTION PENUTUP & PENGHUBUNG ANTAR-SECTION (SEAMLESS VINE CONNECTOR)
// ============================================================================
class _SeamlessVineConnector extends StatelessWidget {
  final bool flipVertical;
  const _SeamlessVineConnector({this.flipVertical = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 1,
            height: 36,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          AnimatedGothicOrnament(
            swayDegrees: flipVertical ? -4 : 4,
            scaleAmplitude: 0.04,
            child: Transform.flip(
              flipY: flipVertical,
              child: Opacity(
                opacity: 0.45,
                child: Row(
                  mainAxisAlignment: .center,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 22,
                      child: InvitationAssetImage(
                        assetPath: InvitationAssets.leafGroom,
                      ),
                    ),
                    Container(
                      margin: const .symmetric(horizontal: 8),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: GothicTheme.boneWhite,
                        shape: .circle,
                      ),
                    ),
                    Transform.flip(
                      flipX: true,
                      child: const SizedBox(
                        width: 28,
                        height: 22,
                        child: InvitationAssetImage(
                          assetPath: InvitationAssets.leafBride,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ],
      ),
    );
  }
}

class _SeamlessFooterSection extends StatelessWidget {
  const _SeamlessFooterSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(24, 24, 24, 80),
      child: Column(
        children: [
          AnimatedGothicOrnament(
            floatAmplitude: 5,
            scaleAmplitude: 0.03,
            child: const SizedBox(
              width: 84,
              height: 84,
              child: InvitationAssetImage(
                assetPath: InvitationAssets.coverInitialFF,
                fit: .contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ojay & Mae', style: GothicTheme.gothicTitle(size: 32)),
          const SizedBox(height: 6),
          Text(
            'Till death do us part • 19.12.2026',
            style: GothicTheme.bodySerif(size: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// KOMPONEN ANIMASI ORNAMEN ORGANIK (SWAY, FLOAT & BREATHING)
// ============================================================================
class AnimatedGothicOrnament extends StatefulWidget {
  final Widget child;
  final double swayDegrees;
  final double floatAmplitude;
  final double scaleAmplitude;
  final Duration duration;
  final Alignment alignment;

  const AnimatedGothicOrnament({
    super.key,
    required this.child,
    this.swayDegrees = 0.0,
    this.floatAmplitude = 0.0,
    this.scaleAmplitude = 0.0,
    this.duration = const Duration(milliseconds: 3600),
    this.alignment = .center,
  });

  @override
  State<AnimatedGothicOrnament> createState() => _AnimatedGothicOrnamentState();
}

class _AnimatedGothicOrnamentState extends State<AnimatedGothicOrnament>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_controller.value);
        final centered = (t - 0.5) * 2.0; // Rentang -1.0 s/d 1.0
        final angleRad = (widget.swayDegrees * math.pi / 180.0) * centered;
        final dy = widget.floatAmplitude * centered;
        final scale = 1.0 + (widget.scaleAmplitude * t);

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: angleRad,
            alignment: widget.alignment,
            child: Transform.scale(
              scale: scale,
              alignment: widget.alignment,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// PAINTER PARTIKEL ABU GOTIK (MENGIKAT VISUAL ANTAR-SECTION)
// ============================================================================
class GothicAshParticlePainter extends CustomPainter {
  final double progress;
  GothicAshParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = .fill;
    const particleCount = 28;

    for (var i = 0; i < particleCount; i++) {
      final seed = i * 37.0;
      final baseX = (seed * 73.1) % size.width;
      final speedMultiplier = 0.4 + ((i % 5) * 0.15);
      final yProgress = (progress * speedMultiplier + (seed / 100.0)) % 1.0;
      final y = size.height * (1.0 - yProgress);
      final driftX = baseX + math.sin(yProgress * 2 * math.pi + i) * 18.0;
      final radius = 1.0 + (i % 3) * 0.8;
      final alpha = (math.sin(yProgress * math.pi) * 0.22).clamp(0.0, 0.25);

      paint.color = GothicTheme.boneWhite.withValues(alpha: alpha);
      canvas.drawCircle(Offset(driftX, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GothicAshParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ============================================================================
// SAFE ASSET IMAGE LOADER (MENAMPILKAN FALLBACK VEKTOR JIKA ASET BELUM SIAP)
// ============================================================================
class InvitationAssetImage extends StatelessWidget {
  final String assetPath;
  final BoxFit fit;

  const InvitationAssetImage({
    super.key,
    required this.assetPath,
    this.fit = .contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback visual bertema Gothic jika file .png belum disalin ke folder assets
        final isSkull = assetPath.contains('tengkorak');
        final isFlower =
            assetPath.contains('Bunga') || assetPath.contains('Daun');
        return Container(
          alignment: .center,
          padding: const .all(8),
          child: Icon(
            isSkull
                ? Icons.auto_awesome_mosaic_outlined
                : (isFlower ? Icons.local_florist_outlined : Icons.shield_moon),
            color: GothicTheme.boneWhite.withValues(alpha: 0.35),
            size: 42,
          ),
        );
      },
    );
  }
}
