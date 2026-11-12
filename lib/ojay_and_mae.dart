import 'dart:async';

// import 'package:material_ui/material_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// KONSTANTA ASET & KONFIGURASI TIPOGRAFI SESUAI MOCKUP
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
  static const Color bgBlack = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFD8D8D8);

  static const String fontGothic = 'AngelWish';
  static const String fontGothicAlt = 'AngelRhapsody';
  static const String fontScript = 'BirdsOfParadise';

  // Font Gothic tegak untuk "Pernikahan Kami", "Sabtu, 19 Desember 2026", "Ojay", "Mae"
  static TextStyle gothic({double size = 32, Color color = white}) => TextStyle(
    fontFamily: fontGothic,
    fontFamilyFallback: const [fontGothicAlt, 'serif'],
    fontSize: size,
    color: color,
    height: 1.15,
    letterSpacing: 0.8,
  );

  // Font Script sambung untuk "We Are Getting Married", "Achmad Fauzi", "Acara Pernikahan", dll.
  static TextStyle script({double size = 30, Color color = white}) => TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: const ['cursive', 'serif'],
    fontSize: size,
    color: color,
    height: 1.25,
  );

  // Font Sans-Serif bersih untuk isi teks, tanggal akad, dan alamat
  static TextStyle sans({
    double size = 12,
    Color color = white,
    FontWeight weight = .normal,
    double height = 1.45,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: 0.2,
  );
}

class OjayMaeWeddingApp extends StatelessWidget {
  const OjayMaeWeddingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Undangan Pernikahan Ojay & Mae',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: .dark,
        scaffoldBackgroundColor: GothicTheme.bgBlack,
      ),
      home: const InvitationScreen(),
    );
  }
}

// ============================================================================
// LAYAR UTAMA: GATE COVER + CONTINUOUS SCROLL (MOBILE & DESKTOP)
// ============================================================================
class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _coverGateController;
  bool _isOpened = false;

  final _heroKey = GlobalKey();
  final _coupleKey = GlobalKey();
  final _eventKey = GlobalKey();
  final _giftKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _coverGateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _coverGateController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _openInvitation() {
    HapticFeedback.mediumImpact();
    _coverGateController.forward().then((_) {
      if (mounted) setState(() => _isOpened = true);
    });
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isDesktop = screenSize.width >= 960;

    return Scaffold(
      backgroundColor: GothicTheme.bgBlack,
      body: Stack(
        fit: .expand,
        children: [
          // TAMPILAN UTAMA (DESKTOP SPLIT-VIEW ATAU MOBILE CENTERED)
          if (isDesktop)
            Row(
              children: [
                // Panel Kiri Desktop (Tetap/Sticky)
                Expanded(
                  flex: 5,
                  child: _DesktopLeftShowcase(
                    onNavigate: (index) {
                      final keys = [_heroKey, _coupleKey, _eventKey, _giftKey];
                      _scrollToSection(keys[index]);
                    },
                  ),
                ),
                Container(width: 1, color: Colors.white12),
                // Panel Kanan Desktop (Kanvas Undangan dengan proporsi akurat 480px)
                Expanded(flex: 6, child: _buildScrollableInvitation()),
              ],
            )
          else
            _buildScrollableInvitation(),

          // COVER PEMBUKA (HALAMAN 1 PDF)
          if (!_isOpened)
            AnimatedBuilder(
              animation: _coverGateController,
              builder: (context, child) {
                final t = Curves.easeInOutCubic.transform(
                  _coverGateController.value,
                );
                return Transform.translate(
                  offset: Offset(0, -screenSize.height * t),
                  child: Opacity(
                    opacity: (1.0 - t).clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: _CoverSection(onOpen: _openInvitation),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollableInvitation() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        child: Center(
          // Lebar dikunci maksimal 460px agar rasio kapsul, bunga, dan teks
          // 100% identik dengan mockup baik di HP maupun di monitor Desktop
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                KeyedSubtree(
                  key: _heroKey,
                  child: _HeroSection(scrollController: _scrollController),
                ),
                KeyedSubtree(
                  key: _coupleKey,
                  child: _CoupleSection(scrollController: _scrollController),
                ),
                KeyedSubtree(
                  key: _eventKey,
                  child: _EventSection(scrollController: _scrollController),
                ),
                KeyedSubtree(
                  key: _giftKey,
                  child: _WeddingGiftSection(
                    scrollController: _scrollController,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PANEL KIRI KHUSUS DESKTOP
// ============================================================================
class _DesktopLeftShowcase extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _DesktopLeftShowcase({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        const Opacity(
          opacity: 0.45,
          child: InvitationAssetImage(
            assetPath: InvitationAssets.coverBg,
            fit: .cover,
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: 0.95,
              colors: [Colors.transparent, GothicTheme.bgBlack],
            ),
          ),
        ),
        Padding(
          padding: const .all(44),
          child: Column(
            mainAxisAlignment: .spaceBetween,
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: InvitationAssetImage(
                      assetPath: InvitationAssets.coverInitialFF,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '19 DESEMBER 2026',
                    style: GothicTheme.sans(
                      size: 12,
                      weight: .bold,
                    ).copyWith(letterSpacing: 3),
                  ),
                ],
              ),
              Center(
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    Text(
                      'Pernikahan Kami',
                      style: GothicTheme.gothic(size: 24),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: const InvitationAssetImage(
                        assetPath: InvitationAssets.skullCouple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Fauzi & Fitri', style: GothicTheme.script(size: 36)),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _NavChip(label: 'Pembuka', onTap: () => onNavigate(0)),
                  _NavChip(label: 'Mempelai', onTap: () => onNavigate(1)),
                  _NavChip(label: 'Acara', onTap: () => onNavigate(2)),
                  _NavChip(label: 'Wedding Gift', onTap: () => onNavigate(3)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: .circular(20),
      child: Container(
        padding: const .symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: .all(color: Colors.white30),
          borderRadius: .circular(20),
        ),
        child: Text(label, style: GothicTheme.sans(size: 12)),
      ),
    );
  }
}

// ============================================================================
// COVER PEMBUKA (HALAMAN 1 PDF)
// ============================================================================
class _CoverSection extends StatelessWidget {
  final VoidCallback onOpen;
  const _CoverSection({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GothicTheme.bgBlack,
      child: Stack(
        fit: .expand,
        children: [
          const Opacity(
            opacity: 0.5,
            child: InvitationAssetImage(
              assetPath: InvitationAssets.coverBg,
              fit: .cover,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                colors: [
                  GothicTheme.bgBlack.withValues(alpha: 0.5),
                  GothicTheme.bgBlack.withValues(alpha: 0.2),
                  GothicTheme.bgBlack.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const .symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text('Pernikahan Kami', style: GothicTheme.gothic(size: 24)),
                  const SizedBox(height: 6),
                  Text('Fauzi & Fitri', style: GothicTheme.script(size: 32)),
                  const Spacer(),
                  const SizedBox(
                    width: 170,
                    height: 170,
                    child: InvitationAssetImage(
                      assetPath: InvitationAssets.coverInitialFF,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ojay &\nMae',
                    textAlign: .center,
                    style: GothicTheme.gothic(size: 40),
                  ),
                  const Spacer(),
                  Text('Kepada Yth', style: GothicTheme.sans(size: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'Tamu Undangan',
                    style: GothicTheme.sans(size: 15, weight: .bold),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GothicTheme.white,
                      foregroundColor: GothicTheme.bgBlack,
                      shape: RoundedRectangleBorder(
                        borderRadius: .circular(24),
                      ),
                      padding: const .symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      'Buka Undangan',
                      style: GothicTheme.sans(
                        size: 13,
                        color: GothicTheme.bgBlack,
                        weight: .bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION 1: HERO (HALAMAN 2 MOCKUP - TANPA DUPLIKASI TEKS)
// ============================================================================
class _HeroSection extends StatelessWidget {
  final ScrollController scrollController;
  const _HeroSection({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      width: .infinity,
      height: size.height,
      child: Stack(
        alignment: .center,
        children: [
          // Background 2-BG-tengkorak.png penuh dengan transisi halus di tepi bawah
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.78, 1.0],
              ).createShader(rect),
              blendMode: .dstIn,
              child: InvitationAssetImage(
                assetPath: InvitationAssets.heroBg,
                fit: .cover,
              ),
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: .center,
              children: [
                const SizedBox(height: 24),
                ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    'Pernikahan Kami',
                    textAlign: .center,
                    style: GothicTheme.gothic(size: 36),
                  ),
                ),
                const SizedBox(height: 42),
                ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 250),
                  initialScale: 0.82,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 340,
                      maxHeight: 420,
                    ),
                    child: const InvitationAssetImage(
                      assetPath: InvitationAssets.skullCouple,
                      fit: .contain,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    'Sabtu, 19 Desember 2026',
                    textAlign: .center,
                    style: GothicTheme.gothic(size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION 2: PROFIL MEMPELAI (HALAMAN 3 & 4 MOCKUP)
// ============================================================================
class _CoupleSection extends StatelessWidget {
  final ScrollController scrollController;
  const _CoupleSection({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // Judul & Salam Pembuka
          ScrollReveal(
            scrollController: scrollController,
            child: Column(
              children: [
                Text(
                  'We Are Getting Married',
                  textAlign: .center,
                  style: GothicTheme.script(size: 28),
                ),
                const SizedBox(height: 28),
                Text(
                  "Assalamu'alaikum Warahmatullaahi Wabarakaatuh",
                  textAlign: .center,
                  style: GothicTheme.sans(size: 13, weight: .bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Maha Suci Allah\n'
                  'yang telah menciptakan makhluk-Nya berpasang-pasangan.\n'
                  'Ya Allah semoga ridho-Mu tercurah mengiringi\n'
                  'pernikahan kami',
                  textAlign: .center,
                  style: GothicTheme.sans(
                    size: 12,
                    color: GothicTheme.textGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // PROFIL MEMPELAI PRIA (OJAY)
          _BrideGroomBlock(
            scrollController: scrollController,
            nickname: 'Ojay',
            fullName: 'Achmad Fauzi',
            parentInfo:
                'Putra Bungsu dari Bpk Moch Noer (alm) dan Ibu Rochilah (almh)',
            skullAsset: InvitationAssets.skullGroom,
            flowerAsset: InvitationAssets.flowerGroom,
            leafAsset: InvitationAssets.leafGroom,
            isFlowerOnLeft: true,
          ),

          const SizedBox(height: 28),

          ScrollReveal(
            scrollController: scrollController,
            initialScale: 0.6,
            child: Text(
              '&',
              textAlign: .center,
              style: GothicTheme.gothic(size: 160),
            ),
          ),

          const SizedBox(height: 14),

          // PROFIL MEMPELAI WANITA (MAE)
          _BrideGroomBlock(
            scrollController: scrollController,
            nickname: 'Mae',
            fullName: 'Fitri Anggraini',
            parentInfo: 'Putri Bungsu dari Bpk Aryanto dan Ibu Nami',
            skullAsset: InvitationAssets.skullBride,
            flowerAsset: InvitationAssets.flowerBride,
            leafAsset: InvitationAssets.leafBride,
            isFlowerOnLeft: false,
          ),
        ],
      ),
    );
  }
}

class _BrideGroomBlock extends StatelessWidget {
  final ScrollController scrollController;
  final String nickname;
  final String fullName;
  final String parentInfo;
  final String skullAsset;
  final String flowerAsset;
  final String leafAsset;
  final bool isFlowerOnLeft;

  const _BrideGroomBlock({
    required this.scrollController,
    required this.nickname,
    required this.fullName,
    required this.parentInfo,
    required this.skullAsset,
    required this.flowerAsset,
    required this.leafAsset,
    required this.isFlowerOnLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 300,
          height: 360,
          child: Stack(
            alignment: .center,
            clipBehavior: .none,
            children: [
              ScrollReveal(
                scrollController: scrollController,
                initialScale: 0.88,
                child: InvitationAssetImage(
                  assetPath: skullAsset,
                  fit: .contain,
                ),
              ),
              Positioned(
                bottom: -14,
                left: isFlowerOnLeft ? -8 : null,
                right: !isFlowerOnLeft ? -8 : null,
                child: ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 220),
                  initialScale: 0.55,
                  slideOffset: Offset(isFlowerOnLeft ? -24 : 24, 20),
                  child: SizedBox(
                    width: 210,
                    height: 240,
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
        const SizedBox(height: 18),
        ScrollReveal(
          scrollController: scrollController,
          delay: const Duration(milliseconds: 150),
          initialScale: 0.8,
          child: SizedBox(
            width: 200,
            height: 60,
            child: Stack(
              alignment: .center,
              children: [
                Positioned.fill(
                  child: InvitationAssetImage(
                    assetPath: leafAsset,
                    fit: .contain,
                  ),
                ),
                Padding(
                  padding: const .only(bottom: 4),
                  child: Text(
                    nickname,
                    textAlign: .center,
                    style: GothicTheme.gothic(size: 52),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        ScrollReveal(
          scrollController: scrollController,
          delay: const Duration(milliseconds: 250),
          child: Text(
            fullName,
            textAlign: .center,
            style: GothicTheme.script(size: 28),
          ),
        ),
        const SizedBox(height: 6),
        ScrollReveal(
          scrollController: scrollController,
          delay: const Duration(milliseconds: 320),
          child: Text(
            parentInfo,
            textAlign: .center,
            style: GothicTheme.sans(
              size: 11,
              color: GothicTheme.textGrey,
              weight: .bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SECTION 3: ACARA PERNIKAHAN
// ============================================================================
class _EventSection extends StatefulWidget {
  final ScrollController scrollController;
  const _EventSection({required this.scrollController});

  @override
  State<_EventSection> createState() => _EventSectionState();
}

class _EventSectionState extends State<_EventSection> {
  static final _targetDate = DateTime(2026, 12, 19, 9, 0);
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_calculateRemaining);
    });
  }

  void _calculateRemaining() {
    final diff = _targetDate.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer.cancel();

    super.dispose();
  }

  void _openMaps(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GothicTheme.white,
        content: Text(
          'Membuka lokasi: $label',
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
      padding: const .symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          // Judul "Acara Pernikahan" menggunakan font Script sesuai mockup
          ScrollReveal(
            scrollController: widget.scrollController,
            child: Text(
              'Acara Pernikahan',
              textAlign: .center,
              style: GothicTheme.script(size: 32),
            ),
          ),
          const SizedBox(height: 22),

          // 4 Kotak Putih Countdown
          ScrollReveal(
            scrollController: widget.scrollController,
            delay: const Duration(milliseconds: 150),
            initialScale: 0.9,
            child: Row(
              mainAxisAlignment: .center,
              children: [
                _WhiteCountdownBox(value: '$days', label: 'Hari'),
                const SizedBox(width: 12),
                _WhiteCountdownBox(
                  value: hours.toString().padLeft(2, '0'),
                  label: 'Jam',
                ),
                const SizedBox(width: 12),
                _WhiteCountdownBox(
                  value: minutes.toString().padLeft(2, '0'),
                  label: 'Menit',
                ),
                const SizedBox(width: 12),
                _WhiteCountdownBox(
                  value: seconds.toString().padLeft(2, '0'),
                  label: 'Detik',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          ScrollReveal(
            scrollController: widget.scrollController,
            delay: const Duration(milliseconds: 220),
            child: Text(
              'Merupakan suatu kehormatan dan kebahagiaan bagi kami apabila\n'
              'Bapak/Ibu/Saudara/i berkenan hadir untuk memberikan doa restu\n'
              'kepada Kami.\n'
              'yang akan diselenggarakan pada :',
              textAlign: .center,
              style: GothicTheme.sans(
                size: 11,
                color: GothicTheme.textGrey,
                height: 1.45,
                weight: .bold,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // SUB-SECTION: AKAD NIKAH (Langsung di atas background hitam, tanpa kotak)
          ScrollReveal(
            scrollController: widget.scrollController,
            delay: const Duration(milliseconds: 280),
            child: Column(
              children: [
                Text(
                  'Akad Nikah',
                  textAlign: .center,
                  style: GothicTheme.script(size: 32),
                ),
                const SizedBox(height: 6),
                Text(
                  'SABTU, 19 DESEMBER 2026',
                  textAlign: .center,
                  style: GothicTheme.sans(size: 18, weight: .bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '09:00 WIB sd Selesai',
                  textAlign: .center,
                  style: GothicTheme.sans(size: 15),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.location_pin,
                  color: GothicTheme.white,
                  size: 52,
                ),
                const SizedBox(height: 8),
                Text(
                  'KUA BENDA',
                  textAlign: .center,
                  style: GothicTheme.sans(size: 14, weight: .bold),
                ),
                Text(
                  'Jl. Adi Sucipto No.18, RT.001/RW.009,\n'
                  'Belendung, Kec. Benda, Kota Tangerang, Banten 15123',
                  textAlign: .center,
                  style: GothicTheme.sans(
                    size: 12,
                    color: GothicTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                _WhitePillButton(
                  icon: Icons.location_on,
                  label: 'Google Maps',
                  onTap: () => _openMaps('KUA Benda'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // SUB-SECTION: ACARA TASYAKURAN (Sesuai mockup: Judul Script -> Lokasi -> Alamat -> Tombol)
          ScrollReveal(
            scrollController: widget.scrollController,
            delay: const Duration(milliseconds: 350),
            child: Column(
              children: [
                Text(
                  'Acara Tasyakuran',
                  textAlign: .center,
                  style: GothicTheme.script(size: 30),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kediaman Mempelai Wanita',
                  textAlign: .center,
                  style: GothicTheme.sans(size: 16, weight: .bold),
                ),
                Text(
                  'Jl. Halim perdana kusuma, Kp. Jurumudi Pajang RT.02/RW.01\n'
                  'Kec. benda Kel.pajang, Kota Tangerang, Banten',
                  textAlign: .center,
                  style: GothicTheme.sans(
                    size: 12,
                    color: GothicTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                _WhitePillButton(
                  icon: Icons.location_on,
                  label: 'Google Maps',
                  onTap: () => _openMaps('Kediaman Mempelai Wanita'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteCountdownBox extends StatelessWidget {
  final String value;
  final String label;

  const _WhiteCountdownBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: GothicTheme.white,
        borderRadius: .circular(14),
      ),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Text(
            value,
            style: GothicTheme.sans(
              size: 20,
              color: GothicTheme.bgBlack,
              weight: .bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GothicTheme.sans(
              size: 10.5,
              color: Colors.black87,
              weight: .w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhitePillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WhitePillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: GothicTheme.white,
          foregroundColor: GothicTheme.bgBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: .circular(24)),
        ),
        icon: Icon(icon, size: 15, color: GothicTheme.bgBlack),
        label: Text(
          label,
          style: GothicTheme.sans(
            size: 13,
            color: GothicTheme.bgBlack,
            weight: .bold,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 4: WEDDING GIFT (HALAMAN 6 PDF - BERSIH DI ATAS LATAR HITAM + BUNGA)
// ============================================================================
class _WeddingGiftSection extends StatelessWidget {
  final ScrollController scrollController;
  const _WeddingGiftSection({required this.scrollController});

  void _copyRekening(BuildContext context, String name, String norek) {
    Clipboard.setData(ClipboardData(text: norek));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GothicTheme.white,
        content: Text(
          'Nomor rekening $name ($norek) berhasil disalin',
          style: const TextStyle(color: GothicTheme.bgBlack, fontWeight: .bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(24, 24, 24, 64),
      child: Column(
        children: [
          ScrollReveal(
            scrollController: scrollController,
            child: Text(
              'Wedding Gift',
              textAlign: .center,
              style: GothicTheme.script(size: 34),
            ),
          ),
          const SizedBox(height: 12),
          ScrollReveal(
            scrollController: scrollController,
            delay: const Duration(milliseconds: 120),
            child: Text(
              'Doa Restu Anda merupakan karunia yang sangat berarti bagi kami.\n'
              'Namun jika memberi adalah ungkapan tanda kasih Anda,\n'
              'Anda dapat memberi kado secara cashless.',
              textAlign: .center,
              style: GothicTheme.sans(
                size: 11,
                color: GothicTheme.textGrey,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Rekening 1: ACHMAD FAUZI
          ScrollReveal(
            scrollController: scrollController,
            delay: const Duration(milliseconds: 200),
            child: _CashlessAccountItem(
              holderName: 'ACHMAD FAUZI',
              accountNumber: '6040564266',
              onCopy: () =>
                  _copyRekening(context, 'Achmad Fauzi', '6040564266'),
            ),
          ),
          const SizedBox(height: 32),

          // Rekening 2: FITRI ANGGRAINI
          ScrollReveal(
            scrollController: scrollController,
            delay: const Duration(milliseconds: 300),
            child: _CashlessAccountItem(
              holderName: 'FITRI ANGGRAINI',
              accountNumber: '5390800152',
              onCopy: () =>
                  _copyRekening(context, 'Fitri Anggraini', '5390800152'),
            ),
          ),
          const SizedBox(height: 40),

          // Ornamen Bunga Penutup (6-Bunga-Wedding-Gift.png) muncul saat tampil
          ScrollReveal(
            scrollController: scrollController,
            delay: const Duration(milliseconds: 350),
            initialScale: 0.65,
            child: const SizedBox(
              width: 220,
              height: 160,
              child: InvitationAssetImage(
                assetPath: InvitationAssets.flowerGift,
                fit: .contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashlessAccountItem extends StatelessWidget {
  final String holderName;
  final String accountNumber;
  final VoidCallback onCopy;

  const _CashlessAccountItem({
    required this.holderName,
    required this.accountNumber,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo BCA Putih sesuai PDF Halaman 6
        const Text(
          'BCA',
          style: TextStyle(
            fontSize: 28,
            fontWeight: .w900,
            fontStyle: .italic,
            color: GothicTheme.white,
            letterSpacing: 1.2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'GRUP BCA',
          style: GothicTheme.sans(
            size: 8.5,
            color: GothicTheme.textGrey,
            weight: .bold,
          ).copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        Text(holderName, style: GothicTheme.sans(size: 15, weight: .bold)),
        const SizedBox(height: 2),
        Text(accountNumber, style: GothicTheme.sans(size: 15, weight: .bold)),
        const SizedBox(height: 12),
        SizedBox(
          width: 150,
          height: 32,
          child: ElevatedButton.icon(
            onPressed: onCopy,
            style: ElevatedButton.styleFrom(
              backgroundColor: GothicTheme.white,
              foregroundColor: GothicTheme.bgBlack,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: .circular(20)),
            ),
            icon: const Icon(
              Icons.copy_rounded,
              size: 14,
              color: GothicTheme.bgBlack,
            ),
            label: Text(
              'Salin Norek',
              style: GothicTheme.sans(
                size: 11.5,
                color: GothicTheme.bgBlack,
                weight: .bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// WIDGET SCROLL REVEAL: ANIMASI SATU KALI SAAT KOMPONEN MUNCUL DI LAYAR
// ("Yang tadinya tidak ada jadi ada", tanpa gerak berulang-ulang)
// ============================================================================
class ScrollReveal extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final Duration duration;
  final Duration delay;
  final double initialScale;
  final Offset slideOffset;

  const ScrollReveal({
    super.key,
    required this.child,
    required this.scrollController,
    this.duration = const Duration(milliseconds: 750),
    this.delay = Duration.zero,
    this.initialScale = 0.94,
    this.slideOffset = const Offset(0, 28),
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _offset;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _scale = Tween<double>(begin: widget.initialScale, end: 1.0).animate(curve);
    _offset = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(curve);

    widget.scrollController.addListener(_checkVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (_hasTriggered || !mounted) return;
    final renderObj = context.findRenderObject();
    if (renderObj is RenderBox && renderObj.hasSize) {
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final position = renderObj.localToGlobal(Offset.zero);

      // Trigger animasi ketika bagian atas komponen masuk ke 90% tinggi layar
      if (position.dy <= viewportHeight * 0.90) {
        _hasTriggered = true;
        widget.scrollController.removeListener(_checkVisibility);
        if (widget.delay == Duration.zero) {
          _controller.forward();
        } else {
          Future.delayed(widget.delay, () {
            if (mounted) _controller.forward();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _offset.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// SAFE ASSET IMAGE LOADER
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
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
