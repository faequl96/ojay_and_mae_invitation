import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ojay_and_mae_invitation/src/firebase_bootstrap.dart';
import 'package:ojay_and_mae_invitation/src/invitation_theme.dart';
import 'package:ojay_and_mae_invitation/src/music_player.dart';
import 'package:ojay_and_mae_invitation/src/web_interop.dart';
import 'package:ojay_and_mae_invitation/src/whatsapp_dashboard_screen.dart';

export 'package:ojay_and_mae_invitation/src/invitation_theme.dart';
export 'package:ojay_and_mae_invitation/src/whatsapp_dashboard_models.dart';
export 'package:ojay_and_mae_invitation/src/whatsapp_dashboard_screen.dart';

// ============================================================================
// IDENTITAS PERANGKAT & MANAJEMEN SESI PENERIMA
// ============================================================================
abstract final class _DeviceIdentity._() {
  static const String _storageKey = 'ojay_mae_device_id';
  static const String _labelPrefix = 'ojay_mae_label_';
  static const String _attendancePrefix = 'ojay_mae_att_';
  static final RegExp _nonAlnumRegex = RegExp(r'[^a-z0-9]+');
  static final RegExp _edgeUnderscoreRegex = RegExp(r'^_+|_+$');
  static String? _cachedId;
  static bool _isFreshDevice = false;

  static bool get isFreshDevice {
    deviceId;
    return _isFreshDevice;
  }

  static String get deviceId {
    final cached = _cachedId;
    if (cached != null) return cached;

    final existing = WebInterop.getStorageItem(_storageKey);
    if (existing != null && existing.isNotEmpty) {
      _isFreshDevice = false;
      return _cachedId = existing;
    }
    _isFreshDevice = true;
    final generated = _generateRandomId();
    WebInterop.setStorageItem(_storageKey, generated);
    return _cachedId = generated;
  }

  static String buildRecipientDeviceId(String recipientName) {
    final normalized = recipientName
        .trim()
        .toLowerCase()
        .replaceAll(_nonAlnumRegex, '_')
        .replaceAll(_edgeUnderscoreRegex, '');
    final prefix = normalized.isNotEmpty ? normalized : 'guest';
    return '${prefix}_$deviceId';
  }

  static String? getCachedRecipientLabel(String recipientId) {
    if (recipientId.isEmpty) return null;
    final value = WebInterop.getStorageItem('$_labelPrefix$recipientId')?.trim();
    return (value != null && value.isNotEmpty) ? value : null;
  }

  static void setCachedRecipientLabel(String recipientId, String label) {
    if (recipientId.isEmpty || label.isEmpty) return;
    WebInterop.setStorageItem('$_labelPrefix$recipientId', label);
  }

  static String? getLastSubmittedAttendance(String recipientId) {
    if (recipientId.isEmpty) return null;
    final value = WebInterop.getStorageItem('$_attendancePrefix$recipientId')?.trim();
    return (value != null && value.isNotEmpty) ? value : null;
  }

  static void setLastSubmittedAttendance(String recipientId, String attendanceLabel) {
    if (recipientId.isEmpty || attendanceLabel.isEmpty) return;
    WebInterop.setStorageItem('$_attendancePrefix$recipientId', attendanceLabel);
  }

  static String _generateRandomId() {
    final rng = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final randomPart = List.generate(6, (_) => rng.nextInt(36).toRadixString(36)).join();
    return '$timestamp$randomPart';
  }
}

// ============================================================================
// DOMAIN MODEL RSVP (TIPE KETAT TANPA DYNAMIC)
// ============================================================================
enum _AttendanceStatus(final String label) {
  attending('Hadir'),
  notAttending('Tidak Hadir'),
  uncertain('Masih Ragu');

  static _AttendanceStatus fromLabel(String? raw) => switch (raw?.trim()) {
    'Tidak Hadir' => .notAttending,
    'Masih Ragu' => .uncertain,
    _ => .attending,
  };
}

final class const _RsvpEntry({
  required final String recipientId,
  required final String name,
  required final String recipientName,
  required final String recipientLabel,
  required final _AttendanceStatus attendance,
  required final String message,
  final DateTime? createdAt,
});

final class const _RsvpBoardState({
  required final List<_RsvpEntry> entries,
  required final bool isUsingFirestore,
  required final bool isLoading,
  required final bool hasMore,
  final int? totalCount,
  final String? errorMessage,
});

// ============================================================================
// ROOT WIDGET
// ============================================================================
class const OjayMaeWeddingApp({super.key, final String? recipientName}) extends StatelessWidget {
  static const String _recipientParamKey = 'to';
  static const String _dashboardPath = '/dashboard';

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static String formatRsvpTimestamp(DateTime createdAt, {DateTime? now}) {
    final localCreatedAt = createdAt.toLocal();
    final localNow = (now ?? DateTime.now()).toLocal();
    final rawDiff = localNow.difference(localCreatedAt);
    final diff = rawDiff.isNegative ? Duration.zero : rawDiff;

    if (diff <= const Duration(hours: 24)) {
      if (diff.inSeconds < 60) {
        final seconds = math.max(1, diff.inSeconds);
        return '$seconds detik yang lalu';
      }
      if (diff.inHours < 1) {
        return '${diff.inMinutes} menit yang lalu';
      }
      return '${diff.inHours} jam yang lalu';
    }

    final month = _shortMonths[localCreatedAt.month - 1];
    final hour = localCreatedAt.hour.toString().padLeft(2, '0');
    final minute = localCreatedAt.minute.toString().padLeft(2, '0');
    return '${localCreatedAt.day} $month ${localCreatedAt.year}, $hour:$minute';
  }

  static String resolveRecipientName([Uri? uri]) {
    if (uri != null) {
      final fromUri = _extractRecipientName(uri);
      if (fromUri.isNotEmpty) return fromUri;
    }
    return _extractRecipientName(Uri.base);
  }

  static String _extractRecipientName(Uri uri) {
    final params = <String, String>{..._safeSplitQuery(uri.query)};
    final fragQueryIndex = uri.fragment.indexOf('?');
    if (fragQueryIndex != -1) {
      params.addAll(_safeSplitQuery(uri.fragment.substring(fragQueryIndex + 1)));
    }
    return params[_recipientParamKey]?.trim() ?? '';
  }

  static Map<String, String> _safeSplitQuery(String query) {
    if (query.isEmpty) return const {};
    try {
      return Uri.splitQueryString(query);
    } on ArgumentError {
      final result = <String, String>{};
      for (final part in query.split('&')) {
        if (part.isEmpty) continue;
        final eqIndex = part.indexOf('=');
        final rawKey = eqIndex == -1 ? part : part.substring(0, eqIndex);
        final rawValue = eqIndex == -1 ? '' : part.substring(eqIndex + 1);
        final key = _safeDecodeQueryComponent(rawKey);
        final value = _safeDecodeQueryComponent(rawValue);
        if (key.isNotEmpty) result[key] = value;
      }
      return result;
    }
  }

  static String _safeDecodeQueryComponent(String component) {
    try {
      return Uri.decodeQueryComponent(component);
    } on ArgumentError {
      return component.replaceAll('+', ' ');
    }
  }

  static bool isDashboardRoute(Uri? uri) {
    if (uri == null) return false;
    var cleanPath = uri.path.trim().toLowerCase();
    while (cleanPath.length > 1 && cleanPath.endsWith('/')) {
      cleanPath = cleanPath.substring(0, cleanPath.length - 1);
    }
    return cleanPath == _dashboardPath;
  }

  static String _normalizeRouteName(String? routeName) {
    if (routeName == null || routeName.isEmpty) return Navigator.defaultRouteName;
    final normalized = routeName.startsWith('/') ? routeName : '/$routeName';
    return Uri.tryParse(normalized) != null ? normalized : Navigator.defaultRouteName;
  }

  Route<void> _buildInvitationRoute(RouteSettings settings) {
    final routeName = _normalizeRouteName(settings.name);
    final normalizedSettings = routeName == settings.name
        ? settings
        : RouteSettings(name: routeName, arguments: settings.arguments);
    final routeUri = Uri.tryParse(routeName);
    if (isDashboardRoute(routeUri) ||
        (routeName == Navigator.defaultRouteName && isDashboardRoute(Uri.base))) {
      return MaterialPageRoute<void>(
        settings: normalizedSettings,
        builder: (_) => const InvitationDashboardScreen(),
      );
    }

    final explicitRecipient = recipientName;
    final fromRoute = routeUri != null ? _extractRecipientName(routeUri) : '';
    final resolvedRecipient = fromRoute.isNotEmpty
        ? fromRoute
        : (explicitRecipient != null && explicitRecipient.isNotEmpty
              ? explicitRecipient
              : resolveRecipientName(routeUri));
    return MaterialPageRoute<void>(
      settings: normalizedSettings,
      builder: (_) => InvitationScreen(recipientName: resolvedRecipient),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Undangan Pernikahan Ojay & Mae',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: .dark, scaffoldBackgroundColor: GothicTheme.bgBlack),
      onGenerateInitialRoutes: (initialRoute) => [
        _buildInvitationRoute(RouteSettings(name: _normalizeRouteName(initialRoute))),
      ],
      onGenerateRoute: _buildInvitationRoute,
    );
  }
}

// ============================================================================
// KOORDINATOR SCROLL REVEAL TERPADU (THROTTLED, TANPA REBUILD SCOPE)
// ============================================================================
final class _ScrollRevealSignal() extends ChangeNotifier {
  void notify() => notifyListeners();
}

final class const _ScrollRevealScope({required final Listenable signal, required super.child})
    extends InheritedWidget {
  static Listenable? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ScrollRevealScope>()?.signal;

  @override
  bool updateShouldNotify(_ScrollRevealScope oldWidget) => oldWidget.signal != signal;
}

final class const _NoScrollbarScrollBehavior() extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

// ============================================================================
// LAYAR UTAMA: GATE COVER + LAZY SLIVER SCROLL (MOBILE & DESKTOP)
// ============================================================================
class const InvitationScreen({super.key, final String recipientName = ''}) extends StatefulWidget {
  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState() extends State<InvitationScreen> with SingleTickerProviderStateMixin {
  static const List<double> _estimatedSectionOffsets = [0.0, 820.0, 2100.0, 3000.0, 3750.0, 4650.0];

  final ScrollController _scrollController = ScrollController();
  late final InvitationMusicController _musicController;
  late final AnimationController _coverMorphController;
  final ValueNotifier<bool> _isMorphComplete = ValueNotifier<bool>(false);

  int _navGeneration = 0;

  late final List<GlobalKey> _sectionKeys = List<GlobalKey>.generate(
    6,
    (_) => GlobalKey(),
    growable: false,
  );

  @override
  void initState() {
    super.initState();
    _musicController = InvitationMusicController(assetPath: InvitationAssets.music);
    _coverMorphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
  }

  @override
  void dispose() {
    _musicController.dispose();
    _coverMorphController.dispose();
    _isMorphComplete.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openInvitation() {
    if (_coverMorphController.isAnimating || _isMorphComplete.value) return;
    HapticFeedback.mediumImpact();
    _musicController.play();
    _coverMorphController.forward().then((_) {
      if (mounted) _isMorphComplete.value = true;
    });
  }

  Future<void> _scrollToSection(int index) async {
    final generation = ++_navGeneration;
    final targetKey = _sectionKeys[index];
    final immediateCtx = targetKey.currentContext;
    if (immediateCtx != null) {
      await Scrollable.ensureVisible(
        immediateCtx,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final estimatedTarget = _estimatedSectionOffsets[index].clamp(0.0, position.maxScrollExtent);

    await _scrollController.animateTo(
      estimatedTarget,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted || generation != _navGeneration) return;

    // Jika target masih di luar cacheExtent sliver, gulir bertahap hingga termuat.
    for (var attempt = 0; attempt < 4 && targetKey.currentContext == null; attempt++) {
      final pos = _scrollController.position;
      final nextTarget = index == 0 ? 0.0 : math.min(pos.pixels + 650.0, pos.maxScrollExtent);
      if ((nextTarget - pos.pixels).abs() < 1.0) break;
      await _scrollController.animateTo(
        nextTarget,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      if (!mounted || generation != _navGeneration) return;
    }

    final resolvedCtx = targetKey.currentContext;
    if (resolvedCtx != null && resolvedCtx.mounted) {
      await Scrollable.ensureVisible(
        resolvedCtx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 960;

    final Widget scrollBody = _InvitationScrollBody(
      scrollController: _scrollController,
      sectionKeys: _sectionKeys,
      recipientName: widget.recipientName,
    );

    return Scaffold(
      backgroundColor: GothicTheme.bgBlack,
      body: Stack(
        fit: .expand,
        children: [
          RepaintBoundary(
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(flex: 5, child: _DesktopLeftShowcase(onNavigate: _scrollToSection)),
                      const ColoredBox(
                        color: Colors.white12,
                        child: SizedBox(width: 1, height: .infinity),
                      ),
                      Expanded(flex: 6, child: scrollBody),
                    ],
                  )
                : scrollBody,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isMorphComplete,
            builder: (context, morphComplete, _) => CoverMusicPlayerOverlay(
              recipientName: widget.recipientName,
              coverBgAsset: InvitationAssets.coverBg,
              coverLogoAsset: InvitationAssets.coverInitialFF,
              musicController: _musicController,
              morphAnimation: _coverMorphController,
              isMorphComplete: morphComplete,
              onOpenInvitation: _openInvitation,
              titleScriptStyle: GothicTheme.script24,
              coupleGothicStyle: GothicTheme.gothicAlt44,
              guestIntroStyle: GothicTheme.script16,
              guestNameStyle: GothicTheme.script28,
            ),
          ),
        ],
      ),
    );
  }
}

class const _InvitationScrollBody({
  required final ScrollController scrollController,
  required final List<GlobalKey> sectionKeys,
  required final String recipientName,
}) extends StatefulWidget {
  @override
  State<_InvitationScrollBody> createState() => _InvitationScrollBodyState();
}

class _InvitationScrollBodyState() extends State<_InvitationScrollBody> {
  final _ScrollRevealSignal _revealSignal = _ScrollRevealSignal();
  double? _lastNotifiedPixels;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _InvitationScrollBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
      _lastNotifiedPixels = null;
    }
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final pixels = widget.scrollController.position.pixels;
    if (_lastNotifiedPixels != null && (pixels - _lastNotifiedPixels!).abs() < 16.0) {
      return;
    }
    _lastNotifiedPixels = pixels;
    _revealSignal.notify();
  }

  bool _onScrollEnd(ScrollEndNotification _) {
    _lastNotifiedPixels = null;
    _revealSignal.notify();
    return false;
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _revealSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ScrollRevealScope(
      signal: _revealSignal,
      child: ScrollConfiguration(
        behavior: const _NoScrollbarScrollBehavior(),
        child: NotificationListener<ScrollEndNotification>(
          onNotification: _onScrollEnd,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = math.max(0.0, (constraints.maxWidth - 460.0) * 0.5);
              return CustomScrollView(
                controller: widget.scrollController,
                physics: const ClampingScrollPhysics(),
                scrollCacheExtent: const .pixels(480),
                slivers: [
                  SliverPadding(
                    padding: .symmetric(horizontal: horizontalPadding),
                    sliver: SliverList.builder(
                      itemCount: widget.sectionKeys.length,
                      itemBuilder: (context, index) {
                        final Widget section = switch (index) {
                          0 => const _HeroSection(),
                          1 => const _CoupleSection(),
                          2 => const _EventSection(),
                          3 => const _WeddingGiftSection(),
                          4 => _RsvpSection(defaultName: widget.recipientName),
                          _ => const _ThankYouSection(),
                        };
                        return KeyedSubtree(key: widget.sectionKeys[index], child: section);
                      },
                    ),
                  ),
                ],
              );
            },
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
  static const List<({String label, int index})> _navItems = [
    (label: 'Pembuka', index: 0),
    (label: 'Mempelai', index: 1),
    (label: 'Acara', index: 2),
    (label: 'Wedding Gift', index: 3),
    (label: 'RSVP', index: 4),
    (label: 'Penutup', index: 5),
  ];

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
                    const Text('Pernikahan Kami', style: GothicTheme.gothic24),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: const InvitationAssetImage(assetPath: InvitationAssets.skullCouple),
                    ),
                    const SizedBox(height: 16),
                    const Text('Fauzi & Fitri', style: GothicTheme.script36),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in _navItems)
                    _NavChip(label: item.label, onTap: () => onNavigate(item.index)),
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
  static const BorderRadius _radius = .all(.circular(20));
  static const BoxDecoration _decoration = BoxDecoration(
    border: Border.fromBorderSide(BorderSide(color: Colors.white30)),
    borderRadius: _radius,
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: _decoration,
        child: Padding(
          padding: const .symmetric(horizontal: 16, vertical: 8),
          child: Text(label, style: GothicTheme.sans(size: 12)),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 1: HERO
// ============================================================================
class const _HeroSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SizedBox(
      width: .infinity,
      height: height,
      child: Stack(
        alignment: .center,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                fit: .expand,
                children: [
                  InvitationAssetImage(assetPath: InvitationAssets.heroBg, fit: .cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: .topCenter,
                        end: .bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, GothicTheme.bgBlack],
                        stops: [0.0, 0.78, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          RepaintBoundary(
            child: Padding(
              padding: const .symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: .center,
                children: [
                  const SizedBox(height: 24),
                  const ScrollReveal(
                    delay: Duration(milliseconds: 100),
                    triggerFraction: 0.90,
                    child: Text('Pernikahan Kami', textAlign: .center, style: GothicTheme.gothic36),
                  ),
                  const SizedBox(height: 42),
                  ScrollReveal(
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
                  const ScrollReveal(
                    delay: Duration(milliseconds: 400),
                    triggerFraction: 0.92,
                    child: Text(
                      'Sabtu, 19 Desember 2026',
                      textAlign: .center,
                      style: GothicTheme.gothic24,
                    ),
                  ),
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
// SECTION 2: PROFIL MEMPELAI
// ============================================================================
class const _CoupleSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          ScrollReveal(
            child: Column(
              children: [
                const Text(
                  'We Are Getting Married',
                  textAlign: .center,
                  style: GothicTheme.script28,
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
          const _BrideGroomBlock(
            nickname: 'Ojay',
            fullName: 'Achmad Fauzi',
            parentInfo: 'Putra Bungsu dari Bpk Moch Noer (alm) dan Ibu Rochilah (almh)',
            skullAsset: InvitationAssets.skullGroom,
            flowerAsset: InvitationAssets.flower,
            leafAsset: InvitationAssets.leaf,
            isFlowerOnLeft: true,
          ),

          const SizedBox(height: 14),

          const ScrollReveal(
            initialScale: 0.6,
            child: Text('&', textAlign: .center, style: GothicTheme.gothicAlt160),
          ),

          // PROFIL MEMPELAI WANITA (MAE)
          const _BrideGroomBlock(
            nickname: 'Mae',
            fullName: 'Fitri Anggraini',
            parentInfo: 'Putri Bungsu dari Bpk Aryanto dan Ibu Nami',
            skullAsset: InvitationAssets.skullBride,
            flowerAsset: InvitationAssets.flower,
            leafAsset: InvitationAssets.leaf,
            isFlowerOnLeft: false,
          ),
        ],
      ),
    );
  }
}

class const _BrideGroomBlock({
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
    final flowerImage = InvitationAssetImage(assetPath: flowerAsset, fit: .contain);
    final leafImage = InvitationAssetImage(assetPath: leafAsset, fit: .contain);

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
                initialScale: 0.88,
                child: InvitationAssetImage(assetPath: skullAsset, fit: .contain),
              ),
              Positioned(
                bottom: -24,
                left: isFlowerOnLeft ? -4 : null,
                right: !isFlowerOnLeft ? -4 : null,
                child: ScrollReveal(
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
                      child: isFlowerOnLeft
                          ? Transform.flip(flipX: true, child: flowerImage)
                          : flowerImage,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ScrollReveal(
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
                    maxAngle: 0.016,
                    swayShift: 1.8,
                    phaseOffset: isFlowerOnLeft ? 0.7 : 2.4,
                    child: isFlowerOnLeft
                        ? Transform.flip(flipX: true, child: leafImage)
                        : leafImage,
                  ),
                ),
                Padding(
                  padding: const .only(bottom: 4),
                  child: Text(nickname, textAlign: .center, style: GothicTheme.gothicAlt46),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        ScrollReveal(
          delay: const Duration(milliseconds: 250),
          child: Text(fullName, textAlign: .center, style: GothicTheme.script28),
        ),
        const SizedBox(height: 6),
        ScrollReveal(
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
class const _EventSection() extends StatelessWidget {
  void _openMaps(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GothicTheme.white,
        content: Text('Membuka lokasi: $label', style: GothicTheme.snackbarBold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 24, vertical: 76),
      child: Column(
        children: [
          const ScrollReveal(
            child: Text('Acara Pernikahan', textAlign: .center, style: GothicTheme.script32),
          ),
          const SizedBox(height: 22),
          const ScrollReveal(
            delay: Duration(milliseconds: 150),
            initialScale: 0.9,
            child: RepaintBoundary(child: _CountdownTimerRow()),
          ),
          const SizedBox(height: 22),
          ScrollReveal(
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
            delay: const Duration(milliseconds: 280),
            child: Column(
              children: [
                const Text('Akad Nikah', textAlign: .center, style: GothicTheme.script32),
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
            delay: const Duration(milliseconds: 350),
            child: Column(
              children: [
                const Text('Acara Tasyakuran', textAlign: .center, style: GothicTheme.script30),
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

  final ValueNotifier<int> _days = ValueNotifier<int>(0);
  final ValueNotifier<int> _hours = ValueNotifier<int>(0);
  final ValueNotifier<int> _minutes = ValueNotifier<int>(0);
  final ValueNotifier<int> _seconds = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncRemaining();
    if (_targetDate.isAfter(DateTime.now())) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _syncRemaining();
      });
    }
  }

  void _syncRemaining() {
    final diff = _targetDate.difference(DateTime.now());
    final remaining = diff.isNegative ? Duration.zero : diff;
    _days.value = remaining.inDays;
    _hours.value = remaining.inHours % 24;
    _minutes.value = remaining.inMinutes % 60;
    _seconds.value = remaining.inSeconds % 60;
    if (remaining == .zero) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _days.dispose();
    _hours.dispose();
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .center,
      children: [
        _WhiteCountdownBox(valueListenable: _days, label: 'Hari', padZero: false),
        const SizedBox(width: 12),
        _WhiteCountdownBox(valueListenable: _hours, label: 'Jam'),
        const SizedBox(width: 12),
        _WhiteCountdownBox(valueListenable: _minutes, label: 'Menit'),
        const SizedBox(width: 12),
        _WhiteCountdownBox(valueListenable: _seconds, label: 'Detik'),
      ],
    );
  }
}

class const _WhiteCountdownBox({
  required final ValueListenable<int> valueListenable,
  required final String label,
  final bool padZero = true,
}) extends StatelessWidget {
  static const BoxDecoration _decoration = BoxDecoration(
    color: GothicTheme.white,
    borderRadius: .all(.circular(14)),
  );
  static const TextStyle _valueStyle = TextStyle(
    fontSize: 20,
    color: GothicTheme.bgBlack,
    fontWeight: .bold,
    height: 1.1,
    letterSpacing: 0.2,
  );
  static const TextStyle _labelStyle = TextStyle(
    fontSize: 10.5,
    color: Colors.black87,
    fontWeight: .w600,
    height: 1.45,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _decoration,
      child: SizedBox(
        width: 68,
        height: 68,
        child: ValueListenableBuilder<int>(
          valueListenable: valueListenable,
          child: Column(
            mainAxisSize: .min,
            children: [
              const SizedBox(height: 2),
              Text(label, style: _labelStyle),
            ],
          ),
          builder: (context, value, staticFooter) {
            final formatted = padZero ? value.toString().padLeft(2, '0') : '$value';
            return Column(
              mainAxisAlignment: .center,
              children: [
                Text(formatted, style: _valueStyle),
                ?staticFooter,
              ],
            );
          },
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
  static final ButtonStyle _style = ElevatedButton.styleFrom(
    backgroundColor: GothicTheme.white,
    foregroundColor: GothicTheme.bgBlack,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(24))),
  );
  static const TextStyle _labelStyle = TextStyle(
    fontSize: 13,
    color: GothicTheme.bgBlack,
    fontWeight: .bold,
    height: 1.45,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: _style,
        icon: Icon(icon, size: 15, color: GothicTheme.bgBlack),
        label: Text(label, style: _labelStyle),
      ),
    );
  }
}

// ============================================================================
// SECTION 4: RSVP & UCAPAN DOA (FIRESTORE)
// ============================================================================
class const _RsvpSection({required final String defaultName}) extends StatefulWidget {
  @override
  State<_RsvpSection> createState() => _RsvpSectionState();
}

class _RsvpSectionState()
    extends State<_RsvpSection>
    with AutomaticKeepAliveClientMixin<_RsvpSection> {
  static const String _collectionName = 'rsvps';
  static const String _sessionsCollectionName = 'rsvp_sessions';
  static const int _pageSize = 5;

  List<_RsvpEntry> _localEntries = const [];
  List<_RsvpEntry> _remoteEntries = const [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastRemoteDoc;
  bool _hasMoreRemote = false;
  int? _totalRemoteCount;
  bool _isFetchingPage = false;
  DateTime? _lastRemoteFetchAt;

  final ValueNotifier<_RsvpBoardState> _boardState = ValueNotifier<_RsvpBoardState>(
    const _RsvpBoardState(
      entries: [],
      isUsingFirestore: false,
      isLoading: false,
      hasMore: false,
      totalCount: 0,
    ),
  );
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  final ValueNotifier<DateTime> _relativeClock = ValueNotifier<DateTime>(DateTime.now());
  Timer? _relativeClockTimer;

  String? _resolvedRecipientLabel;

  @override
  bool get wantKeepAlive => true;

  CollectionReference<Map<String, dynamic>>? get _collection {
    if (!FirebaseBootstrap.isReady) return null;
    try {
      return FirebaseFirestore.instance.collection(_collectionName);
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _sessionsCollection {
    if (!FirebaseBootstrap.isReady) return null;
    try {
      return FirebaseFirestore.instance.collection(_sessionsCollectionName);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_attachFirestore());
  }

  @override
  void didUpdateWidget(covariant _RsvpSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultName != widget.defaultName) {
      _resolvedRecipientLabel = null;
    }
  }

  Future<void> _attachFirestore() async {
    if (kIsWeb && !FirebaseBootstrap.isReady && mounted) {
      _publishRemoteState(isLoading: true);
    }
    final ready = await FirebaseBootstrap.ensureInitialized();
    if (!mounted) return;
    if (!ready) {
      if (kIsWeb) {
        _publishRemoteState(
          isLoading: false,
          errorMessage:
              'Gagal terhubung ke server Firebase. Periksa koneksi atau konfigurasi Firebase.',
        );
      }
      return;
    }
    await _loadInitialRsvps();
  }

  void _publishRemoteState({required bool isLoading, String? errorMessage}) {
    _boardState.value = _RsvpBoardState(
      entries: List.unmodifiable(_remoteEntries),
      isUsingFirestore: true,
      isLoading: isLoading,
      hasMore: _hasMoreRemote,
      totalCount: _totalRemoteCount,
      errorMessage: errorMessage,
    );
    _syncRelativeClockTimer();
  }

  void _publishLocalState() {
    _boardState.value = _RsvpBoardState(
      entries: _localEntries,
      isUsingFirestore: false,
      isLoading: false,
      hasMore: false,
      totalCount: _localEntries.length,
    );
    _syncRelativeClockTimer();
  }

  static bool _hasRecentEntry(List<_RsvpEntry> entries, DateTime now) => entries.any((entry) {
    final createdAt = entry.createdAt;
    return createdAt != null && now.difference(createdAt) <= const Duration(hours: 24);
  });

  void _syncRelativeClockTimer() {
    final now = DateTime.now();
    if (!_hasRecentEntry(_boardState.value.entries, now)) {
      _relativeClockTimer?.cancel();
      _relativeClockTimer = null;
      return;
    }
    _relativeClock.value = now;
    _relativeClockTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final tickNow = DateTime.now();
      _relativeClock.value = tickNow;
      if (!_hasRecentEntry(_boardState.value.entries, tickNow)) {
        _relativeClockTimer?.cancel();
        _relativeClockTimer = null;
      }
    });
  }

  static DateTime? _parseCreatedAt(Object? raw) => switch (raw) {
    Timestamp ts => ts.toDate().toLocal(),
    DateTime dt => dt.toLocal(),
    String iso => DateTime.tryParse(iso)?.toLocal(),
    int ms => DateTime.fromMillisecondsSinceEpoch(ms).toLocal(),
    _ => null,
  };

  static _RsvpEntry _mapFirestoreDoc(Map<String, Object?> data) {
    final rId = (data['recipientId'] as String?)?.trim() ?? '';
    final rName = (data['recipientName'] as String?)?.trim() ?? '';
    final savedLabel = (data['recipientLabel'] as String?)?.trim() ?? '';
    return _RsvpEntry(
      recipientId: rId,
      name: (data['name'] as String?)?.trim() ?? 'Tamu',
      recipientName: rName,
      recipientLabel: savedLabel.isNotEmpty ? savedLabel : rName,
      attendance: _AttendanceStatus.fromLabel(data['attendance'] as String?),
      message: (data['message'] as String?)?.trim() ?? '',
      createdAt: _parseCreatedAt(data['createdAt']),
    );
  }

  static List<_RsvpEntry> _syncLatestAttendance(List<_RsvpEntry> entries) {
    if (entries.isEmpty) return const [];
    final latestAttendanceByRecipientId = <String, _AttendanceStatus>{};
    for (final entry in entries) {
      final rId = entry.recipientId;
      if (rId.isNotEmpty && !latestAttendanceByRecipientId.containsKey(rId)) {
        latestAttendanceByRecipientId[rId] = entry.attendance;
      }
    }
    return [
      for (final entry in entries)
        if (entry.recipientId.isNotEmpty &&
            latestAttendanceByRecipientId[entry.recipientId] != entry.attendance)
          _RsvpEntry(
            recipientId: entry.recipientId,
            name: entry.name,
            recipientName: entry.recipientName,
            recipientLabel: entry.recipientLabel,
            attendance: latestAttendanceByRecipientId[entry.recipientId]!,
            message: entry.message,
            createdAt: entry.createdAt,
          )
        else
          entry,
    ];
  }

  Future<void> _loadInitialRsvps() async {
    if (_isFetchingPage) return;

    _isFetchingPage = true;
    final previousState = _boardState.value;
    if (kIsWeb || FirebaseBootstrap.isReady) {
      _boardState.value = _RsvpBoardState(
        entries: previousState.entries,
        isUsingFirestore: true,
        isLoading: true,
        hasMore: previousState.hasMore,
        totalCount: previousState.totalCount,
      );
    }

    try {
      final ready = FirebaseBootstrap.isReady || await FirebaseBootstrap.ensureInitialized();
      if (!mounted) return;
      final col = ready ? _collection : null;
      if (col == null) {
        if (kIsWeb) {
          _publishRemoteState(
            isLoading: false,
            errorMessage:
                'Gagal terhubung ke server Firebase. Periksa koneksi atau konfigurasi Firebase.',
          );
        }
        return;
      }

      final snap = await col.orderBy('createdAt', descending: true).limit(_pageSize).get();
      if (!mounted) return;
      _lastRemoteFetchAt = DateTime.now();

      if (snap.docs.isEmpty) {
        _remoteEntries = const [];
        _lastRemoteDoc = null;
        _hasMoreRemote = false;
        _totalRemoteCount = 0;
        _currentPage.value = 0;
        _publishRemoteState(isLoading: false);
        return;
      }

      _remoteEntries = _syncLatestAttendance([
        for (final doc in snap.docs) _mapFirestoreDoc(doc.data()),
      ]);
      _lastRemoteDoc = snap.docs.last;

      if (snap.docs.length < _pageSize) {
        _totalRemoteCount = snap.docs.length;
        _hasMoreRemote = false;
      } else {
        int? fetchedCount;
        try {
          final countSnap = await col.count().get();
          fetchedCount = countSnap.count;
        } catch (error) {
          if (kDebugMode && kIsWeb) {
            debugPrint('Firestore count() failed: $error');
          }
        }
        if (!mounted) return;
        _totalRemoteCount = fetchedCount;
        _hasMoreRemote = fetchedCount == null || fetchedCount > _remoteEntries.length;
      }

      _currentPage.value = 0;
      _publishRemoteState(isLoading: false);
    } catch (error) {
      if (kDebugMode && kIsWeb) {
        debugPrint('Firestore _loadInitialRsvps failed: $error');
      }
      if (!mounted) return;
      _publishRemoteState(
        isLoading: false,
        errorMessage: 'Gagal memuat ucapan dari server. Periksa koneksi atau aturan Firestore.',
      );
    } finally {
      _isFetchingPage = false;
    }
  }

  Future<void> _goToPage(int targetPage) async {
    if (targetPage < 0) return;

    final state = _boardState.value;
    if (!state.isUsingFirestore) {
      final totalPages = (_localEntries.length / _pageSize).ceil().clamp(1, 9999);
      _currentPage.value = targetPage.clamp(0, totalPages - 1);
      return;
    }

    final neededCount = (targetPage + 1) * _pageSize;
    final knownTotal = _totalRemoteCount;
    final alreadyLoaded =
        _remoteEntries.length >= neededCount ||
        !_hasMoreRemote ||
        (knownTotal != null && _remoteEntries.length >= knownTotal);
    if (alreadyLoaded) {
      _currentPage.value = targetPage;
      return;
    }

    final col = _collection;
    final cursor = _lastRemoteDoc;
    if (col == null || cursor == null || _isFetchingPage) return;

    _isFetchingPage = true;
    _publishRemoteState(isLoading: true);

    try {
      final nextSnap = await col
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cursor)
          .limit(_pageSize)
          .get();
      if (!mounted) return;

      if (nextSnap.docs.isEmpty) {
        _hasMoreRemote = false;
        _totalRemoteCount = _remoteEntries.length;
        final maxPage = ((_remoteEntries.length - 1) ~/ _pageSize).clamp(0, 9999);
        _currentPage.value = targetPage.clamp(0, maxPage);
      } else {
        _lastRemoteDoc = nextSnap.docs.last;
        _remoteEntries = _syncLatestAttendance([
          ..._remoteEntries,
          for (final doc in nextSnap.docs) _mapFirestoreDoc(doc.data()),
        ]);
        _hasMoreRemote =
            nextSnap.docs.length == _pageSize &&
            (_totalRemoteCount == null || _remoteEntries.length < _totalRemoteCount!);
        if (!_hasMoreRemote) {
          _totalRemoteCount = _remoteEntries.length;
        }
        _currentPage.value = targetPage;
      }
    } catch (error) {
      if (kDebugMode && kIsWeb) {
        debugPrint('Firestore _goToPage failed: $error');
      }
    } finally {
      _isFetchingPage = false;
      if (mounted) _publishRemoteState(isLoading: false);
    }
  }

  Future<String> _resolveRecipientLabelForSubmit() async {
    final recipientName = widget.defaultName.trim();
    if (recipientName.isEmpty) return '';

    final cachedInMemory = _resolvedRecipientLabel;
    if (cachedInMemory != null) return cachedInMemory;

    final recipientId = _DeviceIdentity.buildRecipientDeviceId(recipientName);
    final cachedInStorage = _DeviceIdentity.getCachedRecipientLabel(recipientId);
    if (cachedInStorage != null) {
      return _resolvedRecipientLabel = cachedInStorage;
    }

    final deviceId = _DeviceIdentity.deviceId;
    final normalizedRecipient = recipientName.toLowerCase();

    final sessionsCol = _sessionsCollection;
    if (sessionsCol != null) {
      try {
        if (!_DeviceIdentity.isFreshDevice) {
          final existingDoc = await sessionsCol.doc(recipientId).get();
          if (existingDoc.exists) {
            final savedLabel = (existingDoc.data()?['recipientLabel'] as String?)?.trim();
            if (savedLabel != null && savedLabel.isNotEmpty) {
              _DeviceIdentity.setCachedRecipientLabel(recipientId, savedLabel);
              return _resolvedRecipientLabel = savedLabel;
            }
          }
        }

        // Gunakan agregasi .count() (1 read per 1.000 entri) alih-alih mengunduh semua dokumen sesi.
        final countSnap = await sessionsCol
            .where('normalizedRecipient', isEqualTo: normalizedRecipient)
            .count()
            .get();
        final orderIndex = countSnap.count ?? 0;
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
        _DeviceIdentity.setCachedRecipientLabel(recipientId, label);
        return _resolvedRecipientLabel = label;
      } catch (error) {
        if (kDebugMode && kIsWeb) {
          debugPrint('Firestore _resolveRecipientLabelForSubmit failed: $error');
        }
      }
    }

    return _resolvedRecipientLabel = _computeLocalRecipientLabel(
      recipientId: recipientId,
      recipientName: recipientName,
    );
  }

  String _computeLocalRecipientLabel({required String recipientId, required String recipientName}) {
    if (recipientName.isEmpty) return '';
    final normalized = recipientName.toLowerCase();
    final seenRecipientIds = <String>[];
    final source = _remoteEntries.isNotEmpty ? _remoteEntries : _localEntries;

    for (final item in source.reversed) {
      if (item.recipientName.trim().toLowerCase() == normalized) {
        if (item.recipientId.isNotEmpty && !seenRecipientIds.contains(item.recipientId)) {
          seenRecipientIds.add(item.recipientId);
        }
      }
    }

    final existingIdx = seenRecipientIds.indexOf(recipientId);
    final orderIndex = existingIdx >= 0 ? existingIdx : seenRecipientIds.length;
    return orderIndex == 0 ? recipientName : '$recipientName+$orderIndex';
  }

  void _applyLocalRsvp({
    required String recipientId,
    required String name,
    required String recipientName,
    required String recipientLabel,
    required _AttendanceStatus attendance,
    required String message,
  }) {
    _localEntries = _syncLatestAttendance([
      _RsvpEntry(
        recipientId: recipientId,
        name: name,
        recipientName: recipientName,
        recipientLabel: recipientLabel,
        attendance: attendance,
        message: message,
        createdAt: DateTime.now(),
      ),
      ..._localEntries,
    ]);
    _currentPage.value = 0;
    _publishLocalState();
  }

  Future<bool> _submitRsvp({
    required String name,
    required String message,
    required _AttendanceStatus attendance,
  }) async {
    final ready = FirebaseBootstrap.isReady || await FirebaseBootstrap.ensureInitialized();
    if (!mounted) return false;

    final recipientName = widget.defaultName.trim();
    final recipientId = _DeviceIdentity.buildRecipientDeviceId(recipientName);
    final deviceId = _DeviceIdentity.deviceId;
    final recipientLabel = await _resolveRecipientLabelForSubmit();
    if (!mounted) return false;

    final col = ready ? _collection : null;
    if (col == null) {
      if (kIsWeb) {
        _showSnackBar('Gagal mengirim ucapan. Periksa koneksi atau konfigurasi Firebase.');
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return false;
      _applyLocalRsvp(
        recipientId: recipientId,
        name: name,
        recipientName: recipientName,
        recipientLabel: recipientLabel,
        attendance: attendance,
        message: message,
      );
      _showSnackBar('Terima kasih! Konfirmasi kehadiran & doa berhasil dikirim.');
      return true;
    }

    try {
      final previousAttendance = _DeviceIdentity.getLastSubmittedAttendance(recipientId);
      final payload = <String, Object?>{
        'recipientId': recipientId,
        'deviceId': deviceId,
        'name': name,
        'recipientName': recipientName,
        'recipientLabel': recipientLabel,
        'attendance': attendance.label,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Hanya kueri & perbarui dokumen lama jika perangkat ini pernah mengirim dengan status berbeda.
      if (previousAttendance != null && previousAttendance != attendance.label) {
        final db = FirebaseFirestore.instance;
        final batch = db.batch();
        final previousDocs = await col.where('recipientId', isEqualTo: recipientId).get();
        for (final doc in previousDocs.docs) {
          if ((doc.data()['attendance'] as String?) != attendance.label) {
            batch.update(doc.reference, {'attendance': attendance.label});
          }
        }
        batch.set(col.doc(), payload);
        await batch.commit();
      } else {
        await col.doc().set(payload);
      }

      _DeviceIdentity.setLastSubmittedAttendance(recipientId, attendance.label);
      if (!mounted) return false;

      if (_lastRemoteFetchAt == null) {
        await _loadInitialRsvps();
      } else {
        final newEntry = _RsvpEntry(
          recipientId: recipientId,
          name: name,
          recipientName: recipientName,
          recipientLabel: recipientLabel,
          attendance: attendance,
          message: message,
          createdAt: DateTime.now(),
        );
        _remoteEntries = _syncLatestAttendance([newEntry, ..._remoteEntries]);
        if (_totalRemoteCount != null) {
          _totalRemoteCount = _totalRemoteCount! + 1;
          _hasMoreRemote = _totalRemoteCount! > _remoteEntries.length;
        } else if (!_hasMoreRemote) {
          _totalRemoteCount = _remoteEntries.length;
        }
        _lastRemoteFetchAt = DateTime.now();
        _currentPage.value = 0;
        _publishRemoteState(isLoading: false);
      }

      _showSnackBar('Terima kasih! Konfirmasi kehadiran & doa berhasil dikirim.');
      return true;
    } catch (error) {
      if (kDebugMode && kIsWeb) {
        debugPrint('Firestore _submitRsvp failed: $error');
      }
      if (!mounted) return false;
      _showSnackBar('Gagal mengirim ucapan. Periksa koneksi atau konfigurasi Firebase.');
      return false;
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GothicTheme.white,
        behavior: .floating,
        content: Text(text, style: GothicTheme.snackbarBold),
      ),
    );
  }

  @override
  void dispose() {
    _relativeClockTimer?.cancel();
    _relativeClock.dispose();
    _boardState.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const .symmetric(horizontal: 16, vertical: 48),
      child: Column(
        children: [
          const ScrollReveal(
            child: Text('RSVP & Ucapan Doa', textAlign: .center, style: GothicTheme.script34),
          ),
          const SizedBox(height: 28),
          ScrollReveal(
            delay: const Duration(milliseconds: 200),
            child: _RsvpFormCard(defaultName: widget.defaultName, onSubmit: _submitRsvp),
          ),
          const SizedBox(height: 24),
          ScrollReveal(
            delay: const Duration(milliseconds: 280),
            child: _RsvpMessagesBoard(
              boardStateListenable: _boardState,
              currentPage: _currentPage,
              relativeClock: _relativeClock,
              onPageChanged: _goToPage,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _RsvpSubmitCallback = Future<bool> Function({
  required String name,
  required String message,
  required _AttendanceStatus attendance,
});

class const _RsvpFormCard({
  required final String defaultName,
  required final _RsvpSubmitCallback onSubmit,
}) extends StatefulWidget {
  @override
  State<_RsvpFormCard> createState() => _RsvpFormCardState();
}

class _RsvpFormCardState() extends State<_RsvpFormCard> {
  static const BoxDecoration _cardDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: .topLeft,
      end: .bottomRight,
      colors: [Color(0xFF1A1A1A), Color(0xFF0B0B0B)],
    ),
    borderRadius: .all(.circular(20)),
    border: Border.fromBorderSide(BorderSide(color: Colors.white30)),
  );
  static const OutlineInputBorder _enabledBorder = OutlineInputBorder(
    borderRadius: .all(.circular(14)),
    borderSide: BorderSide(color: Colors.white24),
  );
  static const OutlineInputBorder _focusedBorder = OutlineInputBorder(
    borderRadius: .all(.circular(14)),
    borderSide: BorderSide(color: GothicTheme.white, width: 1.4),
  );
  static final ButtonStyle _submitButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: GothicTheme.white,
    foregroundColor: GothicTheme.bgBlack,
    disabledBackgroundColor: Colors.white38,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(24))),
  );
  static const InputDecoration _nameDecoration = InputDecoration(
    labelText: 'Nama Tamu',
    hintText: 'Masukkan nama Anda',
    labelStyle: TextStyle(fontSize: 12, color: GothicTheme.textGrey, fontWeight: .w600),
    hintStyle: TextStyle(fontSize: 12, color: Colors.white38),
    filled: true,
    fillColor: GothicTheme.cardSurface,
    contentPadding: .symmetric(horizontal: 16, vertical: 14),
    enabledBorder: _enabledBorder,
    focusedBorder: _focusedBorder,
  );
  static const InputDecoration _messageDecoration = InputDecoration(
    labelText: 'Ucapan & Doa',
    hintText: 'Tuliskan ucapan dan doa restu untuk kedua mempelai...',
    labelStyle: TextStyle(fontSize: 12, color: GothicTheme.textGrey, fontWeight: .w600),
    hintStyle: TextStyle(fontSize: 12, color: Colors.white38),
    filled: true,
    fillColor: GothicTheme.cardSurface,
    contentPadding: .symmetric(horizontal: 16, vertical: 14),
    enabledBorder: _enabledBorder,
    focusedBorder: _focusedBorder,
  );

  static final List<TextInputFormatter> _nameInputFormatters =
      List<TextInputFormatter>.unmodifiable([LengthLimitingTextInputFormatter(100)]);
  static final List<TextInputFormatter> _messageInputFormatters =
      List<TextInputFormatter>.unmodifiable([LengthLimitingTextInputFormatter(1000)]);

  late final TextEditingController _nameController;
  final TextEditingController _messageController = TextEditingController();
  final ValueNotifier<_AttendanceStatus> _attendance = ValueNotifier<_AttendanceStatus>(.attending);
  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
  }

  @override
  void didUpdateWidget(covariant _RsvpFormCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultName != widget.defaultName && _nameController.text.trim().isEmpty) {
      _nameController.text = widget.defaultName;
    }
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final message = _messageController.text.trim();

    if (name.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GothicTheme.white,
          behavior: .floating,
          content: Text(
            'Mohon isi nama dan ucapan doa terlebih dahulu.',
            style: GothicTheme.snackbarBold,
          ),
        ),
      );
      return;
    }

    _isSubmitting.value = true;
    HapticFeedback.lightImpact();

    try {
      final ok = await widget.onSubmit(name: name, message: message, attendance: _attendance.value);
      if (ok && mounted) _messageController.clear();
    } finally {
      if (mounted) _isSubmitting.value = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    _attendance.dispose();
    _isSubmitting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _cardDecoration,
      child: Padding(
        padding: const .all(22),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            TextField(
              controller: _nameController,
              inputFormatters: _nameInputFormatters,
              style: GothicTheme.sans(size: 13, weight: .w600),
              decoration: _nameDecoration,
            ),
            const SizedBox(height: 16),
            Text(
              'Konfirmasi Kehadiran',
              style: GothicTheme.sans(size: 12, color: GothicTheme.textGrey, weight: .w600),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<_AttendanceStatus>(
              valueListenable: _attendance,
              builder: (context, selected, _) => Row(
                children: [
                  for (var i = 0; i < _AttendanceStatus.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _AttendanceOptionChip(
                        label: _AttendanceStatus.values[i].label,
                        isSelected: selected == _AttendanceStatus.values[i],
                        onTap: () => _attendance.value = _AttendanceStatus.values[i],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              inputFormatters: _messageInputFormatters,
              maxLines: 3,
              style: GothicTheme.sans(size: 13),
              decoration: _messageDecoration,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 42,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isSubmitting,
                builder: (context, isSubmitting, _) => ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _handleSubmit,
                  style: _submitButtonStyle,
                  icon: isSubmitting
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
                    isSubmitting ? 'Mengirim...' : 'Kirim Konfirmasi',
                    style: GothicTheme.sans(size: 13, color: GothicTheme.bgBlack, weight: .bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _RsvpMessagesBoard({
  required final ValueListenable<_RsvpBoardState> boardStateListenable,
  required final ValueNotifier<int> currentPage,
  required final ValueListenable<DateTime> relativeClock,
  required final ValueChanged<int> onPageChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_RsvpBoardState>(
      valueListenable: boardStateListenable,
      builder: (context, boardState, _) => _RsvpListCard(
        boardState: boardState,
        currentPage: currentPage,
        relativeClock: relativeClock,
        onPageChanged: onPageChanged,
      ),
    );
  }
}

class const _RsvpListCard({
  required final _RsvpBoardState boardState,
  required final ValueNotifier<int> currentPage,
  required final ValueListenable<DateTime> relativeClock,
  required final ValueChanged<int> onPageChanged,
}) extends StatelessWidget {
  static const int _pageSize = _RsvpSectionState._pageSize;
  static const BoxDecoration _cardDecoration = BoxDecoration(
    color: Color(0xFF0E0E0E),
    borderRadius: .all(.circular(20)),
    border: Border.fromBorderSide(BorderSide(color: Colors.white24)),
  );

  @override
  Widget build(BuildContext context) {
    final items = boardState.entries;
    final totalCount = boardState.totalCount;
    final knownTotal = totalCount != null
        ? math.max(totalCount, items.length)
        : (boardState.hasMore ? items.length + 1 : items.length);
    final totalPages = (knownTotal / _pageSize).ceil().clamp(1, 9999);
    final hasKnownTotalPages = totalCount != null || !boardState.hasMore;

    return DecoratedBox(
      decoration: _cardDecoration,
      child: Padding(
        padding: const .all(18),
        child: ValueListenableBuilder<int>(
          valueListenable: currentPage,
          builder: (context, page, _) {
            final safePage = page.clamp(0, totalPages - 1);
            final startIndex = math.min(safePage * _pageSize, items.length);
            final endIndex = math.min(startIndex + _pageSize, items.length);

            final Widget headerSection = Padding(
              padding: const .only(bottom: 12),
              child: Column(
                crossAxisAlignment: .stretch,
                mainAxisSize: .min,
                children: [
                  Text(
                    totalCount != null ? 'Ucapan & Doa ($totalCount)' : 'Ucapan & Doa',
                    style: GothicTheme.sans(size: 11.5, color: GothicTheme.textGrey, weight: .bold),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                ],
              ),
            );

            final Widget? loadingBar = boardState.isLoading
                ? const Padding(
                    padding: .only(bottom: 12),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: GothicTheme.white,
                      backgroundColor: Colors.white12,
                    ),
                  )
                : null;

            final Widget? paginationSection = totalPages > 1
                ? Column(
                    mainAxisSize: .min,
                    children: [
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          Flexible(
                            child: _PaginationButton(
                              icon: Icons.chevron_left_rounded,
                              label: 'Sebelumnya',
                              enabled: !boardState.isLoading && safePage > 0,
                              onTap: () => onPageChanged(safePage - 1),
                            ),
                          ),
                          Padding(
                            padding: const .symmetric(horizontal: 6),
                            child: Text(
                              hasKnownTotalPages
                                  ? 'Hal ${safePage + 1} / $totalPages'
                                  : 'Hal ${safePage + 1}',
                              style: GothicTheme.sans(
                                size: 11,
                                color: GothicTheme.textGrey,
                                weight: .bold,
                              ),
                            ),
                          ),
                          Flexible(
                            child: _PaginationButton(
                              icon: Icons.chevron_right_rounded,
                              label: 'Selanjutnya',
                              isTrailingIcon: true,
                              enabled: !boardState.isLoading && safePage < totalPages - 1,
                              onTap: () => onPageChanged(safePage + 1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : null;

            final String? statusMessage = boardState.isLoading
                ? 'Memuat ucapan & doa...'
                : boardState.errorMessage;

            final Widget? emptyStateSection = items.isEmpty
                ? (statusMessage != null
                      ? Padding(
                          padding: const .symmetric(vertical: 12),
                          child: Text(
                            statusMessage,
                            textAlign: .center,
                            style: GothicTheme.sans(size: 12, color: Colors.white54),
                          ),
                        )
                      : const _RsvpEmptyNotice())
                : null;

            return Column(
              children: [
                headerSection,
                ?loadingBar,
                ?emptyStateSection,
                for (var i = startIndex; i < endIndex; i++) ...[
                  if (i > startIndex) const Divider(color: Colors.white12, height: 22),
                  _RsvpItemTile(entry: items[i], relativeClock: relativeClock),
                ],
                ?paginationSection,
              ],
            );
          },
        ),
      ),
    );
  }
}

class const _RsvpEmptyNotice() extends StatelessWidget {
  static const TextStyle _titleStyle = TextStyle(
    fontSize: 12.5,
    color: GothicTheme.textGrey,
    fontWeight: .w600,
    height: 1.45,
    letterSpacing: 0.2,
  );
  static const TextStyle _subtitleStyle = TextStyle(
    fontSize: 11.5,
    color: Colors.white54,
    height: 1.45,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: .symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(Icons.edit_note_rounded, size: 28, color: Colors.white38),
          SizedBox(height: 8),
          Text('Belum ada ucapan & doa.', textAlign: .center, style: _titleStyle),
          SizedBox(height: 4),
          Text(
            'Belum ada tamu yang menulis ucapan dan doa. Jadilah yang pertama mengirim!',
            textAlign: .center,
            style: _subtitleStyle,
          ),
        ],
      ),
    );
  }
}

class const _RsvpItemTile({
  required final _RsvpEntry entry,
  required final ValueListenable<DateTime> relativeClock,
}) extends StatelessWidget {
  static const BoxDecoration _attendingBadgeDecoration = BoxDecoration(
    color: GothicTheme.white,
    borderRadius: .all(.circular(12)),
    border: Border.fromBorderSide(BorderSide(color: Colors.white30)),
  );
  static const BoxDecoration _otherBadgeDecoration = BoxDecoration(
    color: Colors.white12,
    borderRadius: .all(.circular(12)),
    border: Border.fromBorderSide(BorderSide(color: Colors.white30)),
  );
  static const TextStyle _senderStyle = TextStyle(
    fontSize: 13,
    color: GothicTheme.white,
    fontWeight: .bold,
    height: 1.45,
    letterSpacing: 0.2,
  );
  static const TextStyle _recipientLabelStyle = TextStyle(
    fontSize: 10.5,
    color: Colors.white54,
    fontWeight: .w600,
    height: 1.45,
    letterSpacing: 0.2,
  );
  static const TextStyle _messageStyle = TextStyle(
    fontSize: 12,
    color: GothicTheme.textGrey,
    height: 1.4,
    letterSpacing: 0.2,
  );
  static const TextStyle _timestampStyle = TextStyle(
    fontSize: 10.5,
    color: Colors.white54,
    height: 1.4,
    letterSpacing: 0.2,
  );
  static const TextStyle _badgeAttendingTextStyle = TextStyle(
    fontSize: 10,
    color: GothicTheme.bgBlack,
    fontWeight: .bold,
    height: 1.45,
    letterSpacing: 0.2,
  );
  static const TextStyle _badgeOtherTextStyle = TextStyle(
    fontSize: 10,
    color: GothicTheme.white,
    fontWeight: .bold,
    height: 1.45,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    final label = (entry.recipientLabel.isNotEmpty ? entry.recipientLabel : entry.recipientName)
        .trim();
    final isAttending = entry.attendance == .attending;
    final createdAt = entry.createdAt;
    final currentClock = relativeClock.value;
    final isWithin24Hours =
        createdAt != null && currentClock.difference(createdAt) <= const Duration(hours: 24);

    final Widget? recipientSubtitle = label.isNotEmpty
        ? Padding(
            padding: const .only(top: 2),
            child: Text('Undangan: $label', style: _recipientLabelStyle),
          )
        : null;

    final Widget? timestampFooter = createdAt != null
        ? Padding(
            padding: const .only(top: 6),
            child: Row(
              mainAxisSize: .min,
              children: [
                const Icon(Icons.schedule_rounded, size: 11.5, color: Colors.white54),
                const SizedBox(width: 4),
                if (isWithin24Hours)
                  ValueListenableBuilder<DateTime>(
                    valueListenable: relativeClock,
                    builder: (context, now, _) => Text(
                      OjayMaeWeddingApp.formatRsvpTimestamp(createdAt, now: now),
                      style: _timestampStyle,
                    ),
                  )
                else
                  Text(
                    OjayMaeWeddingApp.formatRsvpTimestamp(createdAt, now: currentClock),
                    style: _timestampStyle,
                  ),
              ],
            ),
          )
        : null;

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
                  Text(entry.name, style: _senderStyle),
                  ?recipientSubtitle,
                ],
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: isAttending ? _attendingBadgeDecoration : _otherBadgeDecoration,
              child: Padding(
                padding: const .symmetric(horizontal: 10, vertical: 3),
                child: Text(
                  entry.attendance.label,
                  style: isAttending ? _badgeAttendingTextStyle : _badgeOtherTextStyle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(entry.message, style: _messageStyle),
        ?timestampFooter,
      ],
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
  static const BorderRadius _radius = .all(.circular(14));
  static const BoxDecoration _enabledDecoration = BoxDecoration(
    borderRadius: _radius,
    border: Border.fromBorderSide(BorderSide(color: Colors.white30)),
  );
  static const BoxDecoration _disabledDecoration = BoxDecoration(
    borderRadius: _radius,
    border: Border.fromBorderSide(BorderSide(color: Colors.white10)),
  );

  @override
  Widget build(BuildContext context) {
    final fgColor = enabled ? GothicTheme.white : Colors.white24;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: enabled ? _enabledDecoration : _disabledDecoration,
        child: Padding(
          padding: const .symmetric(horizontal: 10, vertical: 6),
          child: FittedBox(
            fit: .scaleDown,
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
      ),
    );
  }
}

class const _AttendanceOptionChip({
  required final String label,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  static const BorderRadius _radius = .all(.circular(12));
  static const BoxDecoration _selectedDecoration = BoxDecoration(
    color: GothicTheme.white,
    borderRadius: _radius,
    border: Border.fromBorderSide(BorderSide(color: GothicTheme.white)),
  );
  static const BoxDecoration _unselectedDecoration = BoxDecoration(
    color: GothicTheme.cardSurface,
    borderRadius: _radius,
    border: Border.fromBorderSide(BorderSide(color: Colors.white24)),
  );
  static const TextStyle _selectedTextStyle = TextStyle(
    fontSize: 11,
    color: GothicTheme.bgBlack,
    fontWeight: .bold,
    height: 1.45,
    letterSpacing: 0.2,
  );
  static const TextStyle _unselectedTextStyle = TextStyle(
    fontSize: 11,
    color: GothicTheme.textGrey,
    fontWeight: .bold,
    height: 1.45,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: isSelected ? _selectedDecoration : _unselectedDecoration,
        child: Padding(
          padding: const .symmetric(vertical: 10, horizontal: 6),
          child: Text(
            label,
            textAlign: .center,
            style: isSelected ? _selectedTextStyle : _unselectedTextStyle,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 5: WEDDING GIFT
// ============================================================================
class const _WeddingGiftSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(0, 24, 0, 64),
      child: Column(
        children: [
          const ScrollReveal(
            delay: Duration(milliseconds: 180),
            initialScale: 0.78,
            child: WindSwayFlower(
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
          const ScrollReveal(
            child: Text('Wedding Gift', textAlign: .center, style: GothicTheme.script34),
          ),
          const SizedBox(height: 12),
          ScrollReveal(
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
          const Padding(
            padding: .symmetric(horizontal: 16),
            child: ScrollReveal(
              delay: Duration(milliseconds: 200),
              child: _BankGiftCard(accountHolder: 'ACHMAD FAUZI', accountNumber: '6040564266'),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: .symmetric(horizontal: 16),
            child: ScrollReveal(
              delay: Duration(milliseconds: 300),
              child: _BankGiftCard(accountHolder: 'FITRI ANGGRAINI', accountNumber: '5390800152'),
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
class const _ThankYouSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: .infinity,
      child: Stack(
        alignment: .center,
        children: [
          const Positioned.fill(
            child: InvitationAssetImage(assetPath: InvitationAssets.heroBg, fit: .cover),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: .topCenter,
                  end: .bottomCenter,
                  colors: [GothicTheme.bgBlack, Colors.transparent, Colors.transparent],
                  stops: [0.0, 0.25, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const .fromLTRB(24, 56, 24, 104),
            child: Column(
              children: [
                const ScrollReveal(
                  initialScale: 0.85,
                  child: WindSwayFlower(
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
                const ScrollReveal(
                  delay: Duration(milliseconds: 100),
                  child: Text('Terima Kasih', textAlign: .center, style: GothicTheme.script36),
                ),
                const SizedBox(height: 16),
                ScrollReveal(
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
                  delay: const Duration(milliseconds: 240),
                  child: Text(
                    "Wassalamu'alaikum Warahmatullaahi Wabarakaatuh",
                    textAlign: .center,
                    style: GothicTheme.sans(size: 12.5, weight: .bold),
                  ),
                ),
                const SizedBox(height: 36),
                const ScrollReveal(
                  delay: Duration(milliseconds: 320),
                  initialScale: 0.88,
                  child: SizedBox(
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
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      Text(
                        'Kami yang berbahagia,',
                        textAlign: .center,
                        style: GothicTheme.sans(size: 11.5, color: GothicTheme.textGrey),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Fauzi & Fitri',
                        textAlign: .center,
                        style: GothicTheme.gothicAlt42,
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
                      const SizedBox(height: 22),
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed(OjayMaeWeddingApp._dashboardPath),
                        icon: const Icon(
                          Icons.dashboard_customize_outlined,
                          size: 13,
                          color: Colors.white38,
                        ),
                        label: Text(
                          'Dashboard Kirim WA',
                          style: GothicTheme.sans(size: 10.5, color: Colors.white38),
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
// WIDGET ANIMASI BUNGA TERTIUP ANGIN (SINGLE-MATRIX ZERO-ALLOC HOT PATH)
// ============================================================================
class const WindSwayFlower({
  super.key,
  required final Widget child,
  final Duration duration = const Duration(milliseconds: 3500),
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
  final Matrix4 _swayMatrix = Matrix4.identity();

  Listenable? _scrollSignal;
  ScrollPosition? _scrollPosition;
  double _viewportHeight = 800.0;
  double? _lastCheckedPixels;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility(force: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewportHeight = MediaQuery.sizeOf(context).height;
    _scrollPosition = Scrollable.maybeOf(context)?.position;

    final nextSignal = _ScrollRevealScope.maybeOf(context) ?? _scrollPosition;
    if (_scrollSignal != nextSignal) {
      _scrollSignal?.removeListener(_onScroll);
      _scrollSignal = nextSignal;
      _scrollSignal?.addListener(_onScroll);
    }
  }

  void _onScroll() => _checkVisibility();

  void _checkVisibility({bool force = false}) {
    if (!mounted) return;
    final pixels = _scrollPosition?.pixels ?? 0.0;
    if (!force && _lastCheckedPixels != null && (pixels - _lastCheckedPixels!).abs() < 24.0) {
      return;
    }
    _lastCheckedPixels = pixels;

    final renderObj = context.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize) return;

    final top = renderObj.localToGlobal(.zero).dy;
    final bottom = top + renderObj.size.height;
    final visible = bottom >= -40 && top <= _viewportHeight + 40;

    if (visible != _isVisible) {
      _isVisible = visible;
      if (visible) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        _controller.stop(canceled: false);
      }
    }
  }

  @override
  void dispose() {
    _scrollSignal?.removeListener(_onScroll);
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

          _swayMatrix
            ..setIdentity()
            ..translateByDouble(dx, dy, 0.0, 1.0)
            ..rotateZ(angle)
            ..scaleByDouble(scale, scale, 1.0, 1.0);

          return Transform(alignment: widget.alignment, transform: _swayMatrix, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// WIDGET SCROLL REVEAL (SINGLE-MATRIX TRANSFORM + KOORDINATOR THROTTLED)
// ============================================================================
class const ScrollReveal({
  super.key,
  required final Widget child,
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
  final Matrix4 _revealMatrix = Matrix4.identity();

  Listenable? _scrollSignal;
  ScrollPosition? _scrollPosition;
  double _viewportHeight = 800.0;
  Timer? _delayTimer;
  bool _hasTriggered = false;
  bool _fromTop = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewportHeight = MediaQuery.sizeOf(context).height;
    _scrollPosition = Scrollable.maybeOf(context)?.position;

    final nextSignal = _ScrollRevealScope.maybeOf(context) ?? _scrollPosition;
    if (_scrollSignal != nextSignal) {
      _scrollSignal?.removeListener(_checkVisibility);
      _scrollSignal = nextSignal;
      _scrollSignal?.addListener(_checkVisibility);
    }
  }

  void _checkVisibility() {
    if (!mounted) return;
    final renderObj = context.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize) return;

    final viewportHeight = _viewportHeight;
    final top = renderObj.localToGlobal(.zero).dy;
    final height = renderObj.size.height;
    final bottom = top + height;

    final isCompletelyBelow = top >= viewportHeight * 0.98;
    final isCompletelyAbove = bottom <= viewportHeight * 0.02;

    if (isCompletelyBelow || isCompletelyAbove) {
      _fromTop = isCompletelyAbove;
      if (_hasTriggered || _controller.value > 0.0) {
        _hasTriggered = false;
        _delayTimer?.cancel();
        _controller.reset();
      }
      return;
    }

    if (_hasTriggered) return;

    final enterMargin = math.min(height * 0.12, 24.0);
    final pos = _scrollPosition;
    final hasScroll = pos != null && pos.hasPixels && pos.maxScrollExtent > 0;
    final pixels = hasScroll ? pos.pixels : 0.0;
    final maxScroll = hasScroll ? pos.maxScrollExtent : 0.0;

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
    _scrollSignal?.removeListener(_checkVisibility);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value;
          final invT = 1.0 - t;
          final scale = widget.initialScale + (1.0 - widget.initialScale) * t;
          final dx = widget.slideOffset.dx * invT;
          final baseDy = _fromTop ? -widget.slideOffset.dy.abs() : widget.slideOffset.dy;
          final dy = baseDy * invT;

          _revealMatrix
            ..setIdentity()
            ..translateByDouble(dx, dy, 0.0, 1.0)
            ..scaleByDouble(scale, scale, 1.0, 1.0);

          return Transform(alignment: .center, transform: _revealMatrix, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

class const _BankGiftCard({
  required final String accountHolder,
  required final String accountNumber,
}) extends StatelessWidget {
  static const BoxDecoration _cardDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: .topLeft,
      end: .bottomRight,
      colors: [Color(0xFF1A1A1A), Color(0xFF0B0B0B)],
    ),
    borderRadius: .all(.circular(20)),
    border: Border.fromBorderSide(BorderSide(color: Colors.white30)),
  );
  static const BoxDecoration _chipDecoration = BoxDecoration(
    color: Colors.white24,
    borderRadius: .all(.circular(6)),
    border: Border.fromBorderSide(BorderSide(color: Colors.white54, width: 0.8)),
  );
  static const TextStyle _accountNumberStyle = TextStyle(
    fontFamily: 'Courier',
    fontSize: 23,
    fontWeight: .bold,
    letterSpacing: 2.5,
    color: GothicTheme.white,
  );
  static final ButtonStyle _copyButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: GothicTheme.white,
    side: const BorderSide(color: GothicTheme.white),
    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(20))),
    padding: const .symmetric(horizontal: 16, vertical: 8),
  );

  void _copyAccountNumber(BuildContext context) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GothicTheme.white,
        behavior: .floating,
        content: Text(
          'Nomor rekening $accountHolder ($accountNumber) berhasil disalin!',
          style: GothicTheme.snackbarBold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _cardDecoration,
      child: Padding(
        padding: const .all(24),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            const Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                DecoratedBox(decoration: _chipDecoration, child: SizedBox(width: 40, height: 30)),
                SizedBox(
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
            Text(accountNumber, style: _accountNumberStyle),
            const SizedBox(height: 14),
            Align(
              alignment: .centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _copyAccountNumber(context),
                style: _copyButtonStyle,
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
