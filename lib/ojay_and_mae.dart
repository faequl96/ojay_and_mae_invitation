import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@JS('localStorage.getItem')
external String? _lsGetItem(String key);

@JS('localStorage.setItem')
external void _lsSetItem(String key, String value);

abstract final class _DeviceIdentity() {
  static const String _storageKey = 'ojay_mae_device_id';
  static String? _cachedId;

  static String get deviceId {
    if (_cachedId != null) return _cachedId!;
    try {
      final existing = _lsGetItem(_storageKey);
      if (existing != null && existing.isNotEmpty) {
        return _cachedId = existing;
      }
      final generated = _generateRandomId();
      _lsSetItem(_storageKey, generated);
      return _cachedId = generated;
    } catch (_) {
      return _cachedId = _generateRandomId();
    }
  }

  static String buildRecipientDeviceId(String recipientName) {
    final normalized = recipientName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final prefix = normalized.isNotEmpty ? normalized : 'guest';
    return '${prefix}_$deviceId';
  }

  static String _generateRandomId() {
    final rng = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final randomPart = List.generate(6, (_) => rng.nextInt(36).toRadixString(36)).join();
    return '$timestamp$randomPart';
  }
}

// ============================================================================
// KONSTANTA ASET & KONFIGURASI TIPOGRAFI
// ============================================================================
abstract final class InvitationAssets() {
  static const String bankBCA = 'assets/images/BCA.png';
  static const String coverBg = 'assets/images/COVER-1-BG-tengkorak.png';
  static const String coverInitialFF = 'assets/images/COVER-1-inisial-FF.png';
  static const String heroBg = 'assets/images/2-BG-tengkorak.png';
  static const String skullCouple = 'assets/images/2-tengkorak-ojay-mae.png';
  static const String flowerGroom = 'assets/images/3-Bunga-samping-tengkorak.png';
  static const String leafGroom = 'assets/images/3-Daun-Font-Ojay.png';
  static const String skullGroom = 'assets/images/3-tengkorak-ojay.png';
  static const String flowerBride = 'assets/images/4-Bunga-samping-tengkorak-wanita.png';
  static const String leafBride = 'assets/images/4-Daun-Font-Mae.png';
  static const String skullBride = 'assets/images/4-Tengkorak-Mae.png';
  static const String flowerGift = 'assets/images/6-Bunga-Wedding-Gift.png';

  static const List<String> all = [
    bankBCA,
    coverBg,
    coverInitialFF,
    heroBg,
    skullCouple,
    flowerGroom,
    leafGroom,
    skullGroom,
    flowerBride,
    leafBride,
    skullBride,
    flowerGift,
  ];
}

abstract final class GothicTheme() {
  static const Color bgBlack = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFD8D8D8);

  static const String fontGothic = 'AngelWish';
  static const String fontGothicAlt = 'AngelRhapsody';
  static const String fontScript = 'BirdsOfParadise';

  static TextStyle gothic({double size = 32, Color color = white}) => TextStyle(
    fontFamily: fontGothic,
    fontFamilyFallback: const [fontGothicAlt, 'serif'],
    fontSize: size,
    color: color,
    height: 1.15,
    letterSpacing: 0.8,
  );

  static TextStyle gothicAlt({double size = 34, Color color = white}) => TextStyle(
    fontFamily: fontGothicAlt,
    fontFamilyFallback: const ['serif'],
    fontSize: size,
    color: color,
    letterSpacing: 1.4,
  );

  static TextStyle script({double size = 30, Color color = white}) => TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: const ['cursive', 'serif'],
    fontSize: size,
    color: color,
    height: 1.25,
  );

  static TextStyle sans({
    double size = 12,
    Color color = white,
    FontWeight weight = .normal,
    double height = 1.45,
    double letterSpacing = 0.2,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class const OjayMaeWeddingApp({super.key, final String? recipientName}) extends StatelessWidget {
  static String resolveRecipientName() {
    final params = <String, String>{...Uri.base.queryParameters};
    if (Uri.base.fragment.contains('?')) {
      final fragQuery = Uri.base.fragment.split('?').last;
      params.addAll(Uri.splitQueryString(fragQuery));
    }
    for (final key in const ['to', 'kepada', 'guest', 'nama', 'name', 'penerima']) {
      final value = params[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final resolvedRecipient = recipientName ?? resolveRecipientName();
    return MaterialApp(
      title: 'Undangan Pernikahan Ojay & Mae',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: .dark, scaffoldBackgroundColor: GothicTheme.bgBlack),
      home: InvitationScreen(recipientName: resolvedRecipient),
    );
  }
}

// ============================================================================
// LAYAR UTAMA: GATE COVER + CONTINUOUS SCROLL (MOBILE & DESKTOP)
// ============================================================================
class const InvitationScreen({super.key, final String recipientName = ''}) extends StatefulWidget {
  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState() extends State<InvitationScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _coverGateController;
  bool _isOpened = false;
  bool _didPrecache = false;

  final _heroKey = GlobalKey();
  final _coupleKey = GlobalKey();
  final _eventKey = GlobalKey();
  final _rsvpKey = GlobalKey();
  final _giftKey = GlobalKey();
  final _thankYouKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _coverGateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      _didPrecache = true;
      for (final asset in InvitationAssets.all) {
        precacheImage(AssetImage(asset), context);
      }
    }
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
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _DesktopLeftShowcase(
                    onNavigate: (index) {
                      final keys = [
                        _heroKey,
                        _coupleKey,
                        _eventKey,
                        _giftKey,
                        _rsvpKey,
                        _thankYouKey,
                      ];
                      _scrollToSection(keys[index]);
                    },
                  ),
                ),
                const ColoredBox(
                  color: Colors.white12,
                  child: SizedBox(width: 1, height: .infinity),
                ),
                Expanded(flex: 6, child: _buildScrollableInvitation()),
              ],
            )
          else
            _buildScrollableInvitation(),

          if (!_isOpened)
            AnimatedBuilder(
              animation: _coverGateController,
              builder: (context, child) {
                final t = Curves.easeInOutCubic.transform(_coverGateController.value);
                return FractionalTranslation(
                  translation: Offset(0, -t),
                  child: Opacity(opacity: (1.0 - t).clamp(0.0, 1.0), child: child),
                );
              },
              child: _CoverSection(recipientName: widget.recipientName, onOpen: _openInvitation),
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
                  child: _WeddingGiftSection(scrollController: _scrollController),
                ),
                KeyedSubtree(
                  key: _rsvpKey,
                  child: _RsvpSection(
                    scrollController: _scrollController,
                    defaultName: widget.recipientName,
                  ),
                ),
                KeyedSubtree(
                  key: _thankYouKey,
                  child: _ThankYouSection(scrollController: _scrollController),
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
class const _DesktopLeftShowcase({required final ValueChanged<int> onNavigate})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        const InvitationAssetImage(assetPath: InvitationAssets.coverBg, fit: .cover),
        const DecoratedBox(
          decoration: BoxDecoration(
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
                    child: InvitationAssetImage(assetPath: InvitationAssets.coverInitialFF),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '19 DESEMBER 2026',
                    style: GothicTheme.sans(size: 12, weight: .bold, letterSpacing: 3),
                  ),
                ],
              ),
              Center(
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    Text('Pernikahan Kami', style: GothicTheme.gothic(size: 24)),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: const InvitationAssetImage(assetPath: InvitationAssets.skullCouple),
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
                  _NavChip(label: 'RSVP', onTap: () => onNavigate(4)),
                  _NavChip(label: 'Penutup', onTap: () => onNavigate(5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class const _NavChip({required final String label, required final VoidCallback onTap})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: .circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: .all(color: Colors.white30),
          borderRadius: .circular(20),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 16, vertical: 8),
          child: Text(label, style: GothicTheme.sans(size: 12)),
        ),
      ),
    );
  }
}

// ============================================================================
// COVER PEMBUKA
// ============================================================================
class const _CoverSection({required final String recipientName, required final VoidCallback onOpen})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final displayGuest = recipientName.isNotEmpty ? recipientName : 'Tamu Undangan';
    return ColoredBox(
      color: GothicTheme.bgBlack,
      child: Stack(
        fit: .expand,
        children: [
          const InvitationAssetImage(assetPath: InvitationAssets.coverBg, fit: .cover),
          Padding(
            padding: const .symmetric(horizontal: 24, vertical: 36),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text('Pernikahan Kami', style: GothicTheme.script(size: 24)),
                Text('Fauzi & Fitri', style: GothicTheme.gothicAlt(size: 44)),
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
                const Spacer(),
                const SizedBox(
                  width: 220,
                  height: 220,
                  child: InvitationAssetImage(assetPath: InvitationAssets.coverInitialFF),
                ),
                const SizedBox(height: 24),
                const Spacer(),
                Text('Kepada Yth', style: GothicTheme.script(size: 16)),
                Text(displayGuest, textAlign: .center, style: GothicTheme.script(size: 28)),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: onOpen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GothicTheme.white,
                    foregroundColor: GothicTheme.bgBlack,
                    shape: RoundedRectangleBorder(borderRadius: .circular(24)),
                    padding: const .symmetric(horizontal: 40, vertical: 4),
                  ),
                  child: const Text(
                    'Buka Undangan',
                    style: TextStyle(fontSize: 18, fontWeight: .bold, letterSpacing: .5),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION 1: HERO
// ============================================================================
class const _HeroSection({required final ScrollController scrollController})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      width: .infinity,
      height: size.height,
      child: Stack(
        alignment: .center,
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.78, 1.0],
              ).createShader(rect),
              blendMode: .dstIn,
              child: const InvitationAssetImage(assetPath: InvitationAssets.heroBg, fit: .cover),
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
                  triggerFraction: 0.90,
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
                  initialScale: 0.86,
                  triggerFraction: 0.90,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340, maxHeight: 420),
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
                  triggerFraction: 0.92,
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
// SECTION 2: PROFIL MEMPELAI
// ============================================================================
class const _CoupleSection({required final ScrollController scrollController})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
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
                  style: GothicTheme.sans(size: 12, color: GothicTheme.textGrey, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 76),

          // PROFIL MEMPELAI PRIA (OJAY)
          _BrideGroomBlock(
            scrollController: scrollController,
            nickname: 'Ojay',
            fullName: 'Achmad Fauzi',
            parentInfo: 'Putra Bungsu dari Bpk Moch Noer (alm) dan Ibu Rochilah (almh)',
            skullAsset: InvitationAssets.skullGroom,
            flowerAsset: InvitationAssets.flowerGroom,
            leafAsset: InvitationAssets.leafGroom,
            isFlowerOnLeft: true,
          ),

          const SizedBox(height: 14),

          ScrollReveal(
            scrollController: scrollController,
            initialScale: 0.6,
            child: Text('&', textAlign: .center, style: GothicTheme.gothicAlt(size: 160)),
          ),

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

class const _BrideGroomBlock({
  required final ScrollController scrollController,
  required final String nickname,
  required final String fullName,
  required final String parentInfo,
  required final String skullAsset,
  required final String flowerAsset,
  required final String leafAsset,
  required final bool isFlowerOnLeft,
}) extends StatelessWidget {
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
                child: InvitationAssetImage(assetPath: skullAsset, fit: .contain),
              ),
              Positioned(
                bottom: -24,
                left: isFlowerOnLeft ? -4 : null,
                right: !isFlowerOnLeft ? -4 : null,
                child: ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 220),
                  initialScale: 0.72,
                  slideOffset: Offset(isFlowerOnLeft ? -18 : 18, 16),
                  child: WindSwayFlower(
                    alignment: isFlowerOnLeft ? .bottomRight : .bottomLeft,
                    phaseOffset: isFlowerOnLeft ? 0.0 : 1.8,
                    maxAngle: 0.038,
                    swayShift: isFlowerOnLeft ? -3.5 : 3.5,
                    child: SizedBox(
                      width: 210,
                      height: 240,
                      child: InvitationAssetImage(assetPath: flowerAsset, fit: .contain),
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
          initialScale: 0.86,
          child: SizedBox(
            width: 200,
            height: 60,
            child: Stack(
              alignment: .center,
              children: [
                Positioned.fill(
                  child: WindSwayFlower(
                    duration: const Duration(milliseconds: 7800),
                    maxAngle: 0.016,
                    swayShift: 1.8,
                    phaseOffset: isFlowerOnLeft ? 0.7 : 2.4,
                    child: InvitationAssetImage(assetPath: leafAsset, fit: .contain),
                  ),
                ),
                Padding(
                  padding: const .only(bottom: 4),
                  child: Text(nickname, textAlign: .center, style: GothicTheme.gothicAlt(size: 46)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        ScrollReveal(
          scrollController: scrollController,
          delay: const Duration(milliseconds: 250),
          child: Text(fullName, textAlign: .center, style: GothicTheme.script(size: 28)),
        ),
        const SizedBox(height: 6),
        ScrollReveal(
          scrollController: scrollController,
          delay: const Duration(milliseconds: 320),
          child: Text(
            parentInfo,
            textAlign: .center,
            style: GothicTheme.sans(size: 11, color: GothicTheme.textGrey, weight: .bold),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SECTION 3: ACARA PERNIKAHAN
// ============================================================================
class const _EventSection({required final ScrollController scrollController})
    extends StatelessWidget {
  void _openMaps(BuildContext context, String label) {
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
    return Padding(
      padding: const .symmetric(horizontal: 24, vertical: 76),
      child: Column(
        children: [
          ScrollReveal(
            scrollController: scrollController,
            child: Text(
              'Acara Pernikahan',
              textAlign: .center,
              style: GothicTheme.script(size: 32),
            ),
          ),
          const SizedBox(height: 22),
          ScrollReveal(
            scrollController: scrollController,
            delay: const Duration(milliseconds: 150),
            initialScale: 0.9,
            child: const RepaintBoundary(child: _CountdownTimerRow()),
          ),
          const SizedBox(height: 22),
          ScrollReveal(
            scrollController: scrollController,
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
          ScrollReveal(
            scrollController: scrollController,
            delay: const Duration(milliseconds: 280),
            child: Column(
              children: [
                Text('Akad Nikah', textAlign: .center, style: GothicTheme.script(size: 32)),
                const SizedBox(height: 6),
                Text(
                  'SABTU, 19 DESEMBER 2026',
                  textAlign: .center,
                  style: GothicTheme.sans(size: 18, weight: .bold),
                ),
                const SizedBox(height: 6),
                Text('09:00 WIB sd Selesai', textAlign: .center, style: GothicTheme.sans(size: 15)),
                const SizedBox(height: 12),
                const Icon(Icons.location_pin, color: GothicTheme.white, size: 52),
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
                  style: GothicTheme.sans(size: 12, color: GothicTheme.textGrey),
                ),
                const SizedBox(height: 8),
                _WhitePillButton(
                  icon: Icons.location_on,
                  label: 'Google Maps',
                  onTap: () => _openMaps(context, 'KUA Benda'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          ScrollReveal(
            scrollController: scrollController,
            delay: const Duration(milliseconds: 350),
            child: Column(
              children: [
                Text('Acara Tasyakuran', textAlign: .center, style: GothicTheme.script(size: 30)),
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
                  style: GothicTheme.sans(size: 12, color: GothicTheme.textGrey),
                ),
                const SizedBox(height: 8),
                _WhitePillButton(
                  icon: Icons.location_on,
                  label: 'Google Maps',
                  onTap: () => _openMaps(context, 'Kediaman Mempelai Wanita'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _CountdownTimerRow() extends StatefulWidget {
  @override
  State<_CountdownTimerRow> createState() => _CountdownTimerRowState();
}

class _CountdownTimerRowState() extends State<_CountdownTimerRow> {
  static final DateTime _targetDate = DateTime(2026, 12, 19, 9, 0);
  Timer? _timer;
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
    _remaining = diff.isNegative ? .zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Row(
      mainAxisAlignment: .center,
      children: [
        _WhiteCountdownBox(value: '$days', label: 'Hari'),
        const SizedBox(width: 12),
        _WhiteCountdownBox(value: hours.toString().padLeft(2, '0'), label: 'Jam'),
        const SizedBox(width: 12),
        _WhiteCountdownBox(value: minutes.toString().padLeft(2, '0'), label: 'Menit'),
        const SizedBox(width: 12),
        _WhiteCountdownBox(value: seconds.toString().padLeft(2, '0'), label: 'Detik'),
      ],
    );
  }
}

class const _WhiteCountdownBox({required final String value, required final String label})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: GothicTheme.white, borderRadius: .all(.circular(14))),
      child: SizedBox(
        width: 68,
        height: 68,
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
              style: GothicTheme.sans(size: 10.5, color: Colors.black87, weight: .w600),
            ),
          ],
        ),
      ),
    );
  }
}

class const _WhitePillButton({
  required final IconData icon,
  required final String label,
  required final VoidCallback onTap,
}) extends StatelessWidget {
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
          style: GothicTheme.sans(size: 13, color: GothicTheme.bgBlack, weight: .bold),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 4: RSVP & UCAPAN DOA (FIRESTORE)
// ============================================================================
class const _RsvpSection({
  required final ScrollController scrollController,
  required final String defaultName,
}) extends StatefulWidget {
  @override
  State<_RsvpSection> createState() => _RsvpSectionState();
}

class _RsvpSectionState() extends State<_RsvpSection> {
  static const String _collectionName = 'rsvps';
  static const String _sessionsCollectionName = 'rsvp_sessions';
  static const int _pageSize = 5;
  static const List<String> _attendanceOptions = ['Hadir', 'Tidak Hadir', 'Masih Ragu'];

  final List<Map<String, String>> _dummyRsvps = [
    {
      'recipientId': 'rizky_pratama_dev02',
      'name': 'Dimas (Sepupu Rizky)',
      'recipientName': 'Rizky Pratama',
      'recipientLabel': 'Rizky Pratama+1',
      'attendance': 'Hadir',
      'message':
          'Selamat Ojay & Mae! Ikut hadir bareng rombongan Rizky ya, semoga lancar sampai hari H!',
    },
    {
      'recipientId': 'rizky_pratama_dev01',
      'name': 'Rizky & Nadya',
      'recipientName': 'Rizky Pratama',
      'recipientLabel': 'Rizky Pratama',
      'attendance': 'Hadir',
      'message':
          'Selamat menempuh hidup baru Ojay & Mae! Semoga menjadi keluarga yang sakinah, mawaddah, warahmah.',
    },
    {
      'recipientId': 'dinda_lestari_dev02',
      'name': 'Dinda Lestari',
      'recipientName': 'Dinda Lestari',
      'recipientLabel': 'Dinda Lestari',
      'attendance': 'Hadir',
      'message':
          'Happy wedding Fauzi & Fitri! Lancar terus sampai hari H dan bahagia selalu selamanya.',
    },
    {
      'recipientId': 'budi_santoso_dev03',
      'name': 'Keluarga Besar Pak Budi',
      'recipientName': 'Budi Santoso',
      'recipientLabel': 'Budi Santoso',
      'attendance': 'Masih Ragu',
      'message': 'Selamat ya bro Ojay! Semoga dilancarkan segala urusannya. Diusahakan hadir!',
    },
    {
      'recipientId': 'siti_rahmawati_dev04',
      'name': 'Siti Rahmawati',
      'recipientName': 'Siti Rahmawati',
      'recipientLabel': 'Siti Rahmawati',
      'attendance': 'Tidak Hadir',
      'message':
          'Mohon maaf belum bisa hadir karena ada agenda di luar kota. Doa terbaik untuk Ojay & Mae!',
    },
    {
      'recipientId': 'andi_wijaya_dev05',
      'name': 'Andi Wijaya & Istri',
      'recipientName': 'Andi Wijaya',
      'recipientLabel': 'Andi Wijaya',
      'attendance': 'Hadir',
      'message': 'Selamat berbahagia Ojay & Mae! Semoga langgeng dunia akhirat.',
    },
    {
      'recipientId': 'fajar_teman_smk_dev06',
      'name': 'Fajar Nugroho',
      'recipientName': 'Fajar (Teman SMK)',
      'recipientLabel': 'Fajar (Teman SMK)',
      'attendance': 'Hadir',
      'message': 'Mantap Ojay! Akhirnya berlabuh juga. Sampai ketemu di hari bahagia bro!',
    },
  ];

  late final TextEditingController _nameController;
  final _messageController = TextEditingController();
  String _attendance = _attendanceOptions.first;
  bool _isSubmitting = false;
  int _currentPage = 0;
  String? _resolvedRecipientLabel;

  CollectionReference<Map<String, dynamic>>? get _collection {
    try {
      return FirebaseFirestore.instance.collection(_collectionName);
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _sessionsCollection {
    try {
      return FirebaseFirestore.instance.collection(_sessionsCollectionName);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
    unawaited(_registerRecipientVisit());
  }

  @override
  void didUpdateWidget(covariant _RsvpSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultName != widget.defaultName && _nameController.text.trim().isEmpty) {
      _nameController.text = widget.defaultName;
      unawaited(_registerRecipientVisit());
    }
  }

  Future<String> _registerRecipientVisit() async {
    final recipientName = widget.defaultName.trim();
    if (recipientName.isEmpty) return '';
    if (_resolvedRecipientLabel != null) return _resolvedRecipientLabel!;

    final recipientId = _DeviceIdentity.buildRecipientDeviceId(recipientName);
    final deviceId = _DeviceIdentity.deviceId;
    final normalizedRecipient = recipientName.toLowerCase();

    final sessionsCol = _sessionsCollection;
    if (sessionsCol != null) {
      try {
        final existingDoc = await sessionsCol.doc(recipientId).get();
        if (existingDoc.exists) {
          final savedLabel = (existingDoc.data()?['recipientLabel'] as String?)?.trim();
          if (savedLabel != null && savedLabel.isNotEmpty) {
            return _resolvedRecipientLabel = savedLabel;
          }
        }

        final sameRecipientDocs = await sessionsCol
            .where('normalizedRecipient', isEqualTo: normalizedRecipient)
            .get();
        final orderIndex = sameRecipientDocs.docs.length;
        final label = orderIndex == 0 ? recipientName : '$recipientName+$orderIndex';

        await sessionsCol.doc(recipientId).set({
          'recipientId': recipientId,
          'deviceId': deviceId,
          'recipientName': recipientName,
          'normalizedRecipient': normalizedRecipient,
          'orderIndex': orderIndex,
          'recipientLabel': label,
          'openedAt': FieldValue.serverTimestamp(),
        });

        return _resolvedRecipientLabel = label;
      } catch (_) {}
    }

    return _resolvedRecipientLabel = _computeLocalRecipientLabel(
      recipientId: recipientId,
      recipientName: recipientName,
    );
  }

  String _computeLocalRecipientLabel({
    required String recipientId,
    required String recipientName,
  }) {
    if (recipientName.isEmpty) return '';
    final normalized = recipientName.toLowerCase();
    final seenRecipientIds = <String>[];

    for (final item in _dummyRsvps.reversed) {
      if ((item['recipientName'] ?? '').trim().toLowerCase() == normalized) {
        final rId = item['recipientId'] ?? '';
        if (rId.isNotEmpty && !seenRecipientIds.contains(rId)) {
          seenRecipientIds.add(rId);
        }
      }
    }

    final existingIdx = seenRecipientIds.indexOf(recipientId);
    final orderIndex = existingIdx >= 0 ? existingIdx : seenRecipientIds.length;
    return orderIndex == 0 ? recipientName : '$recipientName+$orderIndex';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _applyLocalRsvp({
    required String recipientId,
    required String name,
    required String recipientName,
    required String recipientLabel,
    required String attendance,
    required String message,
  }) {
    for (final item in _dummyRsvps) {
      if (item['recipientId'] == recipientId) {
        item['attendance'] = attendance;
      }
    }
    _dummyRsvps.insert(0, {
      'recipientId': recipientId,
      'name': name,
      'recipientName': recipientName,
      'recipientLabel': recipientLabel,
      'attendance': attendance,
      'message': message,
    });
    _currentPage = 0;
  }

  Future<void> _submitRsvp() async {
    final name = _nameController.text.trim();
    final message = _messageController.text.trim();
    final recipientName = widget.defaultName.trim();
    final recipientId = _DeviceIdentity.buildRecipientDeviceId(recipientName);
    final deviceId = _DeviceIdentity.deviceId;

    if (name.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GothicTheme.white,
          behavior: .floating,
          content: Text(
            'Mohon isi nama dan ucapan doa terlebih dahulu.',
            style: TextStyle(color: GothicTheme.bgBlack, fontWeight: .bold),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    final recipientLabel = await _registerRecipientVisit();

    final col = _collection;
    if (col == null) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _applyLocalRsvp(
          recipientId: recipientId,
          name: name,
          recipientName: recipientName,
          recipientLabel: recipientLabel,
          attendance: _attendance,
          message: message,
        );
        _isSubmitting = false;
      });
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GothicTheme.white,
          behavior: .floating,
          content: Text(
            'Terima kasih! Konfirmasi kehadiran & doa berhasil dikirim.',
            style: TextStyle(color: GothicTheme.bgBlack, fontWeight: .bold),
          ),
        ),
      );
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final previousDocs = await col.where('recipientId', isEqualTo: recipientId).get();
      for (final doc in previousDocs.docs) {
        batch.update(doc.reference, {'attendance': _attendance});
      }

      final newDocRef = col.doc();
      batch.set(newDocRef, {
        'recipientId': recipientId,
        'deviceId': deviceId,
        'name': name,
        'recipientName': recipientName,
        'recipientLabel': recipientLabel,
        'attendance': _attendance,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      if (!mounted) return;
      setState(() => _currentPage = 0);
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GothicTheme.white,
          behavior: .floating,
          content: Text(
            'Terima kasih! Konfirmasi kehadiran & doa berhasil dikirim.',
            style: TextStyle(color: GothicTheme.bgBlack, fontWeight: .bold),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _applyLocalRsvp(
          recipientId: recipientId,
          name: name,
          recipientName: recipientName,
          recipientLabel: recipientLabel,
          attendance: _attendance,
          message: message,
        );
      });
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GothicTheme.white,
          behavior: .floating,
          content: Text(
            'Terima kasih! Konfirmasi kehadiran & doa berhasil ditambahkan.',
            style: TextStyle(color: GothicTheme.bgBlack, fontWeight: .bold),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration({required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GothicTheme.sans(size: 12, color: GothicTheme.textGrey, weight: .w600),
      hintStyle: GothicTheme.sans(size: 12, color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF141414),
      contentPadding: const .symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: .circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: .circular(14),
        borderSide: const BorderSide(color: GothicTheme.white, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final col = _collection;

    return Padding(
      padding: const .symmetric(horizontal: 16, vertical: 48),
      child: Column(
        children: [
          ScrollReveal(
            scrollController: widget.scrollController,
            child: Text(
              'RSVP & Ucapan Doa',
              textAlign: .center,
              style: GothicTheme.script(size: 34),
            ),
          ),
          const SizedBox(height: 28),
          ScrollReveal(
            scrollController: widget.scrollController,
            delay: const Duration(milliseconds: 200),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: .topLeft,
                  end: .bottomRight,
                  colors: [Color(0xFF1A1A1A), Color(0xFF0B0B0B)],
                ),
                borderRadius: .circular(20),
                border: .all(color: Colors.white30, width: 1),
              ),
              child: Padding(
                padding: const .all(22),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: GothicTheme.sans(size: 13, weight: .w600),
                      decoration: _inputDecoration(label: 'Nama Tamu', hint: 'Masukkan nama Anda'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Konfirmasi Kehadiran',
                      style: GothicTheme.sans(size: 12, color: GothicTheme.textGrey, weight: .w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 0; i < _attendanceOptions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _AttendanceOptionChip(
                              label: _attendanceOptions[i],
                              isSelected: _attendance == _attendanceOptions[i],
                              onTap: () => setState(() => _attendance = _attendanceOptions[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      maxLines: 3,
                      style: GothicTheme.sans(size: 13),
                      decoration: _inputDecoration(
                        label: 'Ucapan & Doa',
                        hint: 'Tuliskan ucapan dan doa restu untuk kedua mempelai...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitRsvp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GothicTheme.white,
                          foregroundColor: GothicTheme.bgBlack,
                          disabledBackgroundColor: Colors.white38,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: .circular(24)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: GothicTheme.bgBlack,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16, color: GothicTheme.bgBlack),
                        label: Text(
                          _isSubmitting ? 'Mengirim...' : 'Kirim Konfirmasi',
                          style: GothicTheme.sans(
                            size: 13,
                            color: GothicTheme.bgBlack,
                            weight: .bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ScrollReveal(
            scrollController: widget.scrollController,
            delay: const Duration(milliseconds: 280),
            child: col != null
                ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: col.orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? const [];
                      if (docs.isEmpty) return _buildRsvpListCard(_dummyRsvps);

                      final latestAttendanceByRecipientId = <String, String>{};
                      for (final d in docs) {
                        final data = d.data();
                        final rId = (data['recipientId'] as String?)?.trim() ?? '';
                        final att = (data['attendance'] as String?)?.trim() ?? 'Hadir';
                        if (rId.isNotEmpty && !latestAttendanceByRecipientId.containsKey(rId)) {
                          latestAttendanceByRecipientId[rId] = att;
                        }
                      }

                      final recipientOrderByGroup = <String, List<String>>{};
                      for (final d in docs.reversed) {
                        final data = d.data();
                        final rId = (data['recipientId'] as String?)?.trim() ?? '';
                        final rName = (data['recipientName'] as String?)?.trim() ?? '';
                        if (rId.isNotEmpty && rName.isNotEmpty) {
                          final list = recipientOrderByGroup.putIfAbsent(
                            rName.toLowerCase(),
                            () => <String>[],
                          );
                          if (!list.contains(rId)) list.add(rId);
                        }
                      }

                      final items = docs.map((d) {
                        final data = d.data();
                        final rId = (data['recipientId'] as String?)?.trim() ?? '';
                        final rName = (data['recipientName'] as String?)?.trim() ?? '';
                        final savedLabel = (data['recipientLabel'] as String?)?.trim() ?? '';
                        final rawAttendance = (data['attendance'] as String?)?.trim() ?? 'Hadir';

                        String displayLabel = savedLabel;
                        if (displayLabel.isEmpty && rName.isNotEmpty) {
                          final groupList = recipientOrderByGroup[rName.toLowerCase()] ?? const [];
                          final idx = groupList.indexOf(rId);
                          displayLabel = idx > 0 ? '$rName+$idx' : rName;
                        }

                        return {
                          'recipientId': rId,
                          'name': (data['name'] as String?)?.trim() ?? 'Tamu',
                          'recipientName': rName,
                          'recipientLabel': displayLabel,
                          'attendance': latestAttendanceByRecipientId[rId] ?? rawAttendance,
                          'message': (data['message'] as String?)?.trim() ?? '',
                        };
                      }).toList();

                      return _buildRsvpListCard(items);
                    },
                  )
                : _buildRsvpListCard(_dummyRsvps),
          ),
        ],
      ),
    );
  }

  Widget _buildRsvpListCard(List<Map<String, String>> items) {
    final totalPages = (items.length / _pageSize).ceil().clamp(1, 9999);
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = safePage * _pageSize;
    final pageItems = items.skip(startIndex).take(_pageSize).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: .circular(20),
        border: .all(color: Colors.white24),
      ),
      child: Padding(
        padding: const .all(18),
        child: Column(
          children: [
            ListView.separated(
              padding: .zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pageItems.length,
              separatorBuilder: (_, _) => const Divider(color: Colors.white12, height: 22),
              itemBuilder: (context, index) {
                final data = pageItems[index];
                final sender = data['name'] ?? 'Tamu';
                final recipientLabel =
                    (data['recipientLabel'] ?? data['recipientName'] ?? '').trim();
                final status = data['attendance'] ?? 'Hadir';
                final msg = data['message'] ?? '';

                return Column(
                  crossAxisAlignment: .start,
                  children: [
                    Row(
                      crossAxisAlignment: .start,
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              Text(sender, style: GothicTheme.sans(size: 13, weight: .bold)),
                              if (recipientLabel.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Undangan: $recipientLabel',
                                  style: GothicTheme.sans(
                                    size: 10.5,
                                    color: Colors.white54,
                                    weight: .w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: status == 'Hadir' ? GothicTheme.white : Colors.white12,
                            borderRadius: .circular(12),
                            border: .all(color: Colors.white30),
                          ),
                          child: Padding(
                            padding: const .symmetric(horizontal: 10, vertical: 3),
                            child: Text(
                              status,
                              style: GothicTheme.sans(
                                size: 10,
                                color: status == 'Hadir' ? GothicTheme.bgBlack : GothicTheme.white,
                                weight: .bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      msg,
                      style: GothicTheme.sans(size: 12, color: GothicTheme.textGrey, height: 1.4),
                    ),
                  ],
                );
              },
            ),
            if (totalPages > 1) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  _PaginationButton(
                    icon: Icons.chevron_left_rounded,
                    label: 'Sebelumnya',
                    enabled: safePage > 0,
                    onTap: () => setState(() => _currentPage = safePage - 1),
                  ),
                  Text(
                    'Hal ${safePage + 1} / $totalPages',
                    style: GothicTheme.sans(size: 11, color: GothicTheme.textGrey, weight: .bold),
                  ),
                  _PaginationButton(
                    icon: Icons.chevron_right_rounded,
                    label: 'Selanjutnya',
                    isTrailingIcon: true,
                    enabled: safePage < totalPages - 1,
                    onTap: () => setState(() => _currentPage = safePage + 1),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class const _PaginationButton({
  required final IconData icon,
  required final String label,
  required final bool enabled,
  required final VoidCallback onTap,
  final bool isTrailingIcon = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fgColor = enabled ? GothicTheme.white : Colors.white24;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: .circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: .circular(14),
          border: .all(color: enabled ? Colors.white30 : Colors.white10),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: .min,
            children: [
              if (!isTrailingIcon) ...[
                Icon(icon, size: 16, color: fgColor),
                const SizedBox(width: 2),
              ],
              Text(
                label,
                style: GothicTheme.sans(size: 11, color: fgColor, weight: .bold),
              ),
              if (isTrailingIcon) ...[
                const SizedBox(width: 2),
                Icon(icon, size: 16, color: fgColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class const _AttendanceOptionChip({
  required final String label,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: .circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? GothicTheme.white : const Color(0xFF141414),
          borderRadius: .circular(12),
          border: .all(color: isSelected ? GothicTheme.white : Colors.white24),
        ),
        child: Padding(
          padding: const .symmetric(vertical: 10, horizontal: 6),
          child: Text(
            label,
            textAlign: .center,
            style: GothicTheme.sans(
              size: 11,
              color: isSelected ? GothicTheme.bgBlack : GothicTheme.textGrey,
              weight: .bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 5: WEDDING GIFT
// ============================================================================
class const _WeddingGiftSection({required final ScrollController scrollController})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(0, 24, 0, 64),
      child: Column(
        children: [
          ScrollReveal(
            scrollController: scrollController,
            delay: const Duration(milliseconds: 180),
            initialScale: 0.78,
            child: const WindSwayFlower(
              alignment: .bottomCenter,
              maxAngle: 0.034,
              swayShift: 3.2,
              phaseOffset: 1.1,
              child: SizedBox(
                width: 220,
                height: 160,
                child: InvitationAssetImage(assetPath: InvitationAssets.flowerGift, fit: .contain),
              ),
            ),
          ),
          ScrollReveal(
            scrollController: scrollController,
            child: Text('Wedding Gift', textAlign: .center, style: GothicTheme.script(size: 34)),
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
                size: 11.5,
                color: GothicTheme.textGrey,
                height: 1.45,
                weight: .bold,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: ScrollReveal(
              scrollController: scrollController,
              delay: const Duration(milliseconds: 200),
              child: const _BankGiftCard(
                accountHolder: 'ACHMAD FAUZI',
                accountNumber: '6040564266',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: ScrollReveal(
              scrollController: scrollController,
              delay: const Duration(milliseconds: 300),
              child: const _BankGiftCard(
                accountHolder: 'FITRI ANGGRAINI',
                accountNumber: '5390800152',
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION 6: UCAPAN TERIMA KASIH (CLOSING / THANK YOU)
// ============================================================================
class const _ThankYouSection({required final ScrollController scrollController})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: .infinity,
      child: Stack(
        alignment: .center,
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                colors: [Colors.transparent, Colors.black, Colors.black],
                stops: [0.0, 0.25, 1.0],
              ).createShader(rect),
              blendMode: .dstIn,
              child: const Opacity(
                opacity: 0.45,
                child: InvitationAssetImage(assetPath: InvitationAssets.heroBg, fit: .cover),
              ),
            ),
          ),
          Padding(
            padding: const .fromLTRB(24, 56, 24, 84),
            child: Column(
              children: [
                ScrollReveal(
                  scrollController: scrollController,
                  initialScale: 0.85,
                  child: const WindSwayFlower(
                    alignment: .bottomCenter,
                    maxAngle: 0.03,
                    swayShift: 2.8,
                    phaseOffset: 0.5,
                    child: SizedBox(
                      width: 190,
                      height: 135,
                      child: InvitationAssetImage(
                        assetPath: InvitationAssets.flowerGift,
                        fit: .contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    'Terima Kasih',
                    textAlign: .center,
                    style: GothicTheme.script(size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 180),
                  child: Text(
                    'Merupakan suatu kehormatan dan kebahagiaan bagi kami\n'
                    'apabila Bapak/Ibu/Saudara/i berkenan hadir dan memberikan\n'
                    'doa restu kepada kedua mempelai.\n\n'
                    'Atas kehadiran dan doa restu Bapak/Ibu/Saudara/i,\n'
                    'kami ucapkan terima kasih.',
                    textAlign: .center,
                    style: GothicTheme.sans(
                      size: 12,
                      color: GothicTheme.textGrey,
                      height: 1.5,
                      weight: .bold,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 240),
                  child: Text(
                    "Wassalamu'alaikum Warahmatullaahi Wabarakaatuh",
                    textAlign: .center,
                    style: GothicTheme.sans(size: 12.5, weight: .bold),
                  ),
                ),
                const SizedBox(height: 36),
                ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 320),
                  initialScale: 0.88,
                  child: const SizedBox(
                    width: 140,
                    height: 140,
                    child: InvitationAssetImage(
                      assetPath: InvitationAssets.coverInitialFF,
                      fit: .contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ScrollReveal(
                  scrollController: scrollController,
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      Text(
                        'Kami yang berbahagia,',
                        textAlign: .center,
                        style: GothicTheme.sans(size: 11.5, color: GothicTheme.textGrey),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Fauzi & Fitri',
                        textAlign: .center,
                        style: GothicTheme.gothicAlt(size: 42),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ojay & Mae',
                        textAlign: .center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: .w300,
                          color: Colors.white,
                          letterSpacing: 5,
                          fontStyle: .italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const ColoredBox(
                        color: Colors.white24,
                        child: SizedBox(width: 64, height: 1),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '19 . 12 . 2026',
                        textAlign: .center,
                        style: GothicTheme.sans(
                          size: 11,
                          color: Colors.white54,
                          weight: .bold,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ],
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
// WIDGET ANIMASI BUNGA TERTIUP ANGIN (CONTINUOUS ORGANIC WIND SWAY)
// ============================================================================
class const WindSwayFlower({
  super.key,
  required final Widget child,
  final Duration duration = const Duration(milliseconds: 6800),
  final double maxAngle = 0.036,
  final double swayShift = 3.2,
  final double phaseOffset = 0.0,
  final Alignment alignment = .bottomCenter,
}) extends StatefulWidget {
  @override
  State<WindSwayFlower> createState() => _WindSwayFlowerState();
}

class _WindSwayFlowerState() extends State<WindSwayFlower> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * math.pi + widget.phaseOffset;
          final wave = math.sin(t);
          final subWave = math.cos(t) * 0.25;

          final angle = wave * widget.maxAngle;
          final dx = wave * widget.swayShift;
          final dy = subWave * (widget.swayShift * 0.35);
          final scale = 1.0 + (wave * 0.01);

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: angle,
              alignment: widget.alignment,
              child: Transform.scale(scale: scale, alignment: widget.alignment, child: child),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// WIDGET SCROLL REVEAL (MUNCUL SAAT SCROLL KE BAWAH MAUPUN BALIK KE ATAS)
// ============================================================================
class const ScrollReveal({
  super.key,
  required final Widget child,
  required final ScrollController scrollController,
  final Duration duration = const Duration(milliseconds: 1150),
  final Duration delay = .zero,
  final double initialScale = 0.94,
  final Offset slideOffset = const Offset(0, 24),
  final double triggerFraction = 0.83,
}) extends StatefulWidget {
  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState() extends State<ScrollReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late Animation<Offset> _offset;
  Timer? _delayTimer;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_curve);
    _scale = Tween<double>(begin: widget.initialScale, end: 1.0).animate(_curve);
    _updateOffsetTween(fromTop: false);

    widget.scrollController.addListener(_checkVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _updateOffsetTween({required bool fromTop}) {
    final beginOffset = fromTop
        ? Offset(widget.slideOffset.dx, -widget.slideOffset.dy.abs())
        : widget.slideOffset;
    _offset = Tween<Offset>(begin: beginOffset, end: .zero).animate(_curve);
  }

  @override
  void didUpdateWidget(covariant ScrollReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_checkVisibility);
      widget.scrollController.addListener(_checkVisibility);
    }
  }

  void _checkVisibility() {
    if (!mounted) return;
    final renderObj = context.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize) return;

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final top = renderObj.localToGlobal(.zero).dy;
    final height = renderObj.size.height;
    final bottom = top + height;

    final isCompletelyBelow = top >= viewportHeight * 0.98;
    final isCompletelyAbove = bottom <= viewportHeight * 0.02;

    if (isCompletelyBelow || isCompletelyAbove) {
      if (_hasTriggered || _controller.value > 0.0) {
        _hasTriggered = false;
        _delayTimer?.cancel();
        _updateOffsetTween(fromTop: isCompletelyAbove);
        _controller.reset();
      }
      return;
    }

    if (_hasTriggered) return;

    final enterMargin = math.min(height * 0.12, 24.0);
    final hasScroll =
        widget.scrollController.hasClients && widget.scrollController.position.maxScrollExtent > 0;
    final pixels = hasScroll ? widget.scrollController.position.pixels : 0.0;
    final maxScroll = hasScroll ? widget.scrollController.position.maxScrollExtent : 0.0;

    final isNearBottom = hasScroll && pixels >= maxScroll - 32;
    final isNearTop = !hasScroll || pixels <= 32;

    final enteredFromBottom =
        (top + enterMargin) <= viewportHeight * widget.triggerFraction ||
        (isNearBottom && top < viewportHeight * 0.95);
    final enteredFromTop =
        (bottom - enterMargin) >= viewportHeight * (1.0 - widget.triggerFraction) ||
        (isNearTop && bottom > viewportHeight * 0.05);

    if (enteredFromBottom && enteredFromTop) {
      _hasTriggered = true;
      _delayTimer?.cancel();
      if (widget.delay == .zero) {
        _controller.forward();
      } else {
        _delayTimer = Timer(widget.delay, () {
          if (mounted && _hasTriggered) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    widget.scrollController.removeListener(_checkVisibility);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: _offset.value,
            child: Transform.scale(scale: _scale.value, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// SAFE ASSET IMAGE LOADER
// ============================================================================
class const InvitationAssetImage({
  super.key,
  required final String assetPath,
  final BoxFit fit = .contain,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: fit,
      filterQuality: .medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class const _BankGiftCard({
  required final String accountHolder,
  required final String accountNumber,
}) extends StatelessWidget {
  void _copyAccountNumber(BuildContext context) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GothicTheme.white,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: .topLeft,
          end: .bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF0B0B0B)],
        ),
        borderRadius: .circular(20),
        border: .all(color: Colors.white30, width: 1),
      ),
      child: Padding(
        padding: const .all(24),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: .circular(6),
                    border: .all(color: Colors.white54, width: 0.8),
                  ),
                  child: const SizedBox(width: 40, height: 30),
                ),
                const SizedBox(
                  width: 80,
                  child: InvitationAssetImage(assetPath: InvitationAssets.bankBCA),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              accountHolder,
              style: GothicTheme.sans(
                size: 13,
                color: GothicTheme.white,
                weight: .bold,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              accountNumber,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 23,
                fontWeight: .bold,
                letterSpacing: 2.5,
                color: GothicTheme.white,
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: .centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _copyAccountNumber(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GothicTheme.white,
                  side: const BorderSide(color: GothicTheme.white),
                  shape: RoundedRectangleBorder(borderRadius: .circular(20)),
                  padding: const .symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Salin Norek', style: TextStyle(fontSize: 12, fontWeight: .bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
