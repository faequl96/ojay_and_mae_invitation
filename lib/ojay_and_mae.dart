import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class OjayMaeOutlawWeddingApp extends StatelessWidget {
  const OjayMaeOutlawWeddingApp({super.key, required this.rsvpController});

  final RsvpController rsvpController;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Ojay & Mae 1912 . 2026',
      color: OutlawPalette.voidBlack,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return DefaultTextStyle(
          style: const TextStyle(
            color: OutlawPalette.boneWhite,
            fontFamily: 'HauntedSerif',
            fontFamilyFallback: <String>['serif'],
            fontSize: 15.0,
            height: 1.55,
          ),
          child: OutlawInvitationShell(rsvpController: rsvpController),
        );
      },
    );
  }
}

class OutlawInvitationShell extends StatefulWidget {
  const OutlawInvitationShell({super.key, required this.rsvpController});

  final RsvpController rsvpController;

  @override
  State<OutlawInvitationShell> createState() => _OutlawInvitationShellState();
}

class _OutlawInvitationShellState extends State<OutlawInvitationShell> {
  final ValueNotifier<bool> _gateUnlocked = ValueNotifier<bool>(false);
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _gateUnlocked.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OutlawPalette.voidBlack,
      child: Stack(
        alignment: .center,
        children: <Widget>[
          // 1. Badai Bara Perak & Angin Malam Gurun
          const Positioned.fill(child: NightEclipseEmberStorm()),

          // 2. Pipeline Scroll 10 Seksi (Lazy Sliver)
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620.0),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: <Widget>[
                    // SEKSI 1: COVER
                    SliverToBoxAdapter(
                      child: _OutlawCoverSection(
                        onUnlock: () => _gateUnlocked.value = true,
                      ),
                    ),
                    // SEKSI 2: MAKSUD DAN TUJUAN / KATA PENGANTAR
                    const SliverToBoxAdapter(child: _OutlawPrefaceSection()),
                    // SEKSI 3: PENGANTIN WANITA (MAE)
                    const SliverToBoxAdapter(child: _BrideGunslingerSection()),
                    // SEKSI 4: PENGANTIN PRIA (OJAY)
                    const SliverToBoxAdapter(child: _GroomPaleRiderSection()),
                    // SEKSI 5: ACARA (1912 - 2026)
                    const SliverToBoxAdapter(child: _HighNoonEventSection()),
                    // SEKSI 6: LOKASI
                    const SliverToBoxAdapter(
                      child: _BlackSanctuaryLocationSection(),
                    ),
                    // SEKSI 7: GALERI
                    const SliverToBoxAdapter(
                      child: _ObsidianArcanaGallerySection(),
                    ),
                    // SEKSI 8: KADO PERNIKAHAN
                    const SliverToBoxAdapter(child: _BountyChestGiftSection()),
                    // SEKSI 9: RSVP DAN UCAPAN (FIREBASE)
                    SliverToBoxAdapter(
                      child: _ChronicleOfOathsRsvpSection(
                        controller: widget.rsvpController,
                      ),
                    ),
                    // SEKSI 10: TERIMA KASIH
                    const SliverToBoxAdapter(
                      child: _RideIntoEternityThankYouSection(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Gerbang Segel Perisai Besi Pembuka (Full Screen Modal Gate)
          ValueListenableBuilder<bool>(
            valueListenable: _gateUnlocked,
            builder: (context, unlocked, _) {
              return IgnorePointer(
                ignoring: unlocked,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeInOutCubic,
                  opacity: unlocked ? .0 : 1.0,
                  child: ColoredBox(
                    color: OutlawPalette.voidBlack,
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560.0),
                          child: _OutlawCoverSection(
                            isModalGate: true,
                            onUnlock: () => _gateUnlocked.value = true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 1. COVER (PERISAI BESI TEMPA & TENGKORAK BERSAYAP MALAM)
/// ============================================================================
class _OutlawCoverSection extends StatelessWidget {
  const _OutlawCoverSection({required this.onUnlock, this.isModalGate = false});

  final VoidCallback onUnlock;
  final bool isModalGate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 18.0, vertical: 28.0),
      child: OutlawBastionFrame(
        style: .ironShield,
        padding: const .fromLTRB(18.0, 42.0, 18.0, 34.0),
        child: Column(
          mainAxisSize: .min,
          children: <Widget>[
            Padding(
              padding: const .symmetric(horizontal: 20),
              child: Image.asset(
                'assets/images/ojay_mae_cover.png',
                fit: .contain,
                filterQuality: .high,
                errorBuilder: (context, error, stackTrace) {
                  return const CustomPaint(
                    painter: _IronSkullTwinSabersCrestFallbackPainter(),
                  );
                },
              ),
            ),
            if (isModalGate) ...[
              const SizedBox(height: 12.0),
              const BarbedIronStarDivider(),
              const SizedBox(height: 16.0),
              // Plakat Maklumat Tamu Kehormatan
              DecoratedBox(
                decoration: BoxDecoration(
                  color: OutlawPalette.obsidianDark,
                  border: Border.all(
                    color: OutlawPalette.boneWhite,
                    width: 1.5,
                  ),
                ),
                child: const Padding(
                  padding: .symmetric(horizontal: 22.0, vertical: 14.0),
                  child: Column(
                    children: <Widget>[
                      Text(
                        '★ ROYAL DECREE OF INVITATION ★',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: .bold,
                          letterSpacing: 3.0,
                          color: OutlawPalette.boneWhite,
                        ),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        'KEPADA YTH. BAPAK / IBU / SAUDARA/I:',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 2.0,
                          color: OutlawPalette.phantomSilver,
                        ),
                      ),
                      SizedBox(height: 6.0),
                      FierceOutlawTitle(
                        text: 'TAMU KEHORMATAN',
                        fontSize: 18.0,
                        letterSpacing: 2.0,
                        slashCut: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22.0),
              _OutlawTriggerButton(
                label: '☠ BUKA UNDANGAN ☠',
                isInverted: true,
                onTap: onUnlock,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 2. MAKSUD DAN TUJUAN / KATA PENGANTAR
/// ============================================================================
class _OutlawPrefaceSection extends StatelessWidget {
  const _OutlawPrefaceSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: .symmetric(horizontal: 18.0, vertical: 18.0),
      child: OutlawBastionFrame(
        style: .obsidianCharter,
        child: Column(
          children: <Widget>[
            _OutlawSectionHeader(
              chapterCode: 'CHAPTER I • THE IRON COVENANT',
              title: 'Maksud Dan Tujuan',
              subtitle: 'MAKLUMAT IKATAN SUCI',
            ),
            SizedBox(height: 18.0),
            Text(
              'Assalamu’alaikum Warahmatullahi Wabarakatuh\n'
              'Salam Sejahtera bagi Kita Semua',
              textAlign: .center,
              style: TextStyle(fontWeight: .bold, letterSpacing: 1.0),
            ),
            SizedBox(height: 16.0),
            Text(
              'Di bawah naungan langit malam yang megah dan deru angin perjalanan panjang, '
              'dua jiwa penakluk badai akhirnya menambatkan langkah pada satu takdir. '
              'Bukan sekadar janji yang pudar oleh masa, melainkan ikrar baja '
              'yang ditempa dalam kehormatan, kesetiaan, dan kasih abadi.',
              textAlign: .center,
              style: TextStyle(color: OutlawPalette.phantomSilver),
            ),
            SizedBox(height: 14.0),
            Text(
              'Tanpa mengurangi rasa hormat, kami mengundang Bapak/Ibu/Saudara/i '
              'untuk hadir menjadi saksi penyatuan janji suci pernikahan kami pada '
              'Sabtu, 19 Desember 2026.',
              textAlign: .center,
              style: TextStyle(color: OutlawPalette.phantomSilver),
            ),
            SizedBox(height: 20.0),
            BarbedIronStarDivider(),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 3. PENGANTIN WANITA (MAE — SOVEREIGN LADY OF BLACK ROSE)
/// ============================================================================
class _BrideGunslingerSection extends StatelessWidget {
  const _BrideGunslingerSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: .symmetric(horizontal: 18.0, vertical: 18.0),
      child: OutlawBastionFrame(
        style: .gothicSpire,
        padding: .fromLTRB(24.0, 48.0, 24.0, 28.0),
        child: Column(
          children: <Widget>[
            _OutlawSectionHeader(
              chapterCode: 'CHAPTER II • SOVEREIGN GRACE',
              title: 'Pengantin Wanita',
              subtitle: 'THE LADY OF BLACK ROSE & SILVER LACE',
            ),
            SizedBox(height: 22.0),
            _SovereignShieldMedallion(
              monogram: 'M',
              roleLabel: 'EMPRESS OF THE NIGHT SANCTUARY',
            ),
            SizedBox(height: 18.0),
            FierceOutlawTitle(text: 'MAE', fontSize: 38.0, letterSpacing: 4.0),
            SizedBox(height: 8.0),
            Text(
              'Putri Tercinta dari Keluarga Bapak & Ibu Mempelai Wanita',
              textAlign: .center,
              style: TextStyle(color: OutlawPalette.phantomSilver),
            ),
            SizedBox(height: 18.0),
            BarbedIronStarDivider(width: 200.0),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 4. PENGANTIN PRIA (OJAY — THE SHADOW VANGUARD GROOM)
/// ============================================================================
class _GroomPaleRiderSection extends StatelessWidget {
  const _GroomPaleRiderSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: .symmetric(horizontal: 18.0, vertical: 18.0),
      child: OutlawBastionFrame(
        style: .ironShield,
        padding: .fromLTRB(24.0, 42.0, 24.0, 28.0),
        child: Column(
          children: <Widget>[
            _OutlawSectionHeader(
              chapterCode: 'CHAPTER III • THE IRON VANGUARD',
              title: 'Pengantin Pria',
              subtitle: 'THE KNIGHT IN HERITAGE CROWN & TUXEDO',
            ),
            SizedBox(height: 22.0),
            _SovereignShieldMedallion(
              monogram: 'O',
              roleLabel: 'GUARDIAN OF THE ETERNAL COVENANT',
            ),
            SizedBox(height: 18.0),
            FierceOutlawTitle(text: 'OJAY', fontSize: 38.0, letterSpacing: 4.0),
            SizedBox(height: 8.0),
            Text(
              'Putra Tercinta dari Keluarga Bapak & Ibu Mempelai Pria',
              textAlign: .center,
              style: TextStyle(color: OutlawPalette.phantomSilver),
            ),
            SizedBox(height: 18.0),
            BarbedIronStarDivider(width: 200.0),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 5. ACARA (THE ECLIPSE CONVERGENCE — 19.12.2026)
/// ============================================================================
class _HighNoonEventSection extends StatefulWidget {
  const _HighNoonEventSection();

  @override
  State<_HighNoonEventSection> createState() => _HighNoonEventSectionState();
}

class _HighNoonEventSectionState extends State<_HighNoonEventSection> {
  static final DateTime _targetDate = DateTime(2026, 12, 19, 9, 0);
  late final ValueNotifier<Duration> _countdown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countdown = ValueNotifier<Duration>(_calc());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _countdown.value = _calc();
    });
  }

  Duration _calc() {
    final diff = _targetDate.difference(DateTime.now());
    return diff.isNegative ? .zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 18.0, vertical: 18.0),
      child: OutlawBastionFrame(
        style: .obsidianCharter,
        child: Column(
          children: <Widget>[
            const _OutlawSectionHeader(
              chapterCode: 'CHAPTER IV • THE ECLIPSE CONVERGENCE',
              title: 'Acara',
              subtitle: 'SABTU, 19 DESEMBER 2026 (1912 • 2026)',
            ),
            const SizedBox(height: 22.0),
            RepaintBoundary(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _countdown,
                builder: (context, d, _) {
                  return Row(
                    children: <Widget>[
                      _BulletChamberCounter(
                        value: '${d.inDays}',
                        label: 'HARI',
                      ),
                      const SizedBox(width: 8.0),
                      _BulletChamberCounter(
                        value: d.inHours
                            .remainder(24)
                            .toString()
                            .padLeft(2, '0'),
                        label: 'JAM',
                      ),
                      const SizedBox(width: 8.0),
                      _BulletChamberCounter(
                        value: d.inMinutes
                            .remainder(60)
                            .toString()
                            .padLeft(2, '0'),
                        label: 'MENIT',
                      ),
                      const SizedBox(width: 8.0),
                      _BulletChamberCounter(
                        value: d.inSeconds
                            .remainder(60)
                            .toString()
                            .padLeft(2, '0'),
                        label: 'DETIK',
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 26.0),
            const OutlawBastionFrame(
              style: .ironShield,
              showSkullCrest: false,
              padding: .symmetric(horizontal: 20.0, vertical: 22.0),
              child: Column(
                children: <Widget>[
                  FierceOutlawTitle(text: 'AKAD NIKAH', fontSize: 22.0),
                  SizedBox(height: 8.0),
                  Text(
                    'Sabtu, 19 Desember 2026\nPukul 09.00 WIB – Selesai',
                    textAlign: .center,
                    style: TextStyle(color: OutlawPalette.phantomSilver),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18.0),
            const OutlawBastionFrame(
              style: .ironShield,
              showSkullCrest: false,
              padding: .symmetric(horizontal: 20.0, vertical: 22.0),
              child: Column(
                children: <Widget>[
                  FierceOutlawTitle(text: 'RESEPSI MALAM', fontSize: 22.0),
                  SizedBox(height: 8.0),
                  Text(
                    'Sabtu, 19 Desember 2026\nPukul 19.00 WIB – 22.00 WIB',
                    textAlign: .center,
                    style: TextStyle(color: OutlawPalette.phantomSilver),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    '★ DRESSCODE: HITAM PEKAT / DARK ROYAL GOTHIC ★',
                    textAlign: .center,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: .bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20.0),
            const BarbedIronStarDivider(),
          ],
        ),
      ),
    );
  }
}

class _BulletChamberCounter extends StatelessWidget {
  const _BulletChamberCounter({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OutlawPalette.obsidianDark,
          border: Border.all(color: OutlawPalette.boneWhite, width: 1.4),
        ),
        child: Padding(
          padding: const .symmetric(vertical: 12.0),
          child: Column(
            children: <Widget>[
              FierceOutlawTitle(
                text: value,
                fontSize: 24.0,
                letterSpacing: 1.5,
                slashCut: false,
              ),
              const SizedBox(height: 4.0),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.0,
                  letterSpacing: 2.2,
                  color: OutlawPalette.phantomSilver,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// 6. LOKASI (PETA BENTENG MALAM & JALUR BESI)
/// ============================================================================
class _BlackSanctuaryLocationSection extends StatefulWidget {
  const _BlackSanctuaryLocationSection();

  @override
  State<_BlackSanctuaryLocationSection> createState() =>
      _BlackSanctuaryLocationSectionState();
}

class _BlackSanctuaryLocationSectionState
    extends State<_BlackSanctuaryLocationSection> {
  final ValueNotifier<bool> _copied = ValueNotifier<bool>(false);

  static const String _hall = 'Obsidian Sanctuary & Grand Black Hall';
  static const String _addr =
      'Jl. Kemang Raya No. 19, Jakarta Selatan, DKI Jakarta 12730';

  @override
  void dispose() {
    _copied.dispose();
    super.dispose();
  }

  Future<void> _copyAddress() async {
    await Clipboard.setData(const ClipboardData(text: _addr));
    _copied.value = true;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) _copied.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 18.0, vertical: 18.0),
      child: OutlawBastionFrame(
        style: .obsidianCharter,
        child: Column(
          children: <Widget>[
            const _OutlawSectionHeader(
              chapterCode: 'CHAPTER V • THE BLACK CITADEL',
              title: 'Lokasi',
              subtitle: 'KOORDINAT BENTENG PERJAMUAN',
            ),
            const SizedBox(height: 20.0),
            SizedBox(
              height: 185.0,
              width: .infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: OutlawPalette.obsidianDark,
                  border: Border.all(
                    color: OutlawPalette.boneWhite,
                    width: 1.4,
                  ),
                ),
                child: const CustomPaint(
                  painter: _OutlawRailroadMapPainter(),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: OutlawPalette.frameBackground,
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: OutlawPalette.boneWhite,
                            width: 1.4,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: .symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          'TITIK TEMU: OJAY & MAE (19.12.2026)',
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: .bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18.0),
            const FierceOutlawTitle(
              text: _hall,
              fontSize: 20.0,
              letterSpacing: 1.8,
              slashCut: false,
            ),
            const SizedBox(height: 8.0),
            const Text(
              _addr,
              textAlign: .center,
              style: TextStyle(color: OutlawPalette.phantomSilver),
            ),
            const SizedBox(height: 18.0),
            ValueListenableBuilder<bool>(
              valueListenable: _copied,
              builder: (context, isCopied, _) {
                return _OutlawTriggerButton(
                  label: isCopied
                      ? '✓ KOORDINAT LOKASI TERSALIN'
                      : 'SALIN ALAMAT BENTENG LOKASI',
                  onTap: _copyAddress,
                );
              },
            ),
            const SizedBox(height: 20.0),
            const BarbedIronStarDivider(),
          ],
        ),
      ),
    );
  }
}

class _OutlawRailroadMapPainter extends CustomPainter {
  const _OutlawRailroadMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = .8;

    final trackPaint = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 1.6
      ..style = .stroke;

    for (var x = .0; x < size.width; x += 32.0) {
      canvas.drawLine(Offset(x, .0), Offset(x, size.height), grid);
    }
    for (var y = .0; y < size.height; y += 32.0) {
      canvas.drawLine(Offset(.0, y), Offset(size.width, y), grid);
    }

    // Jalur rel baja melintasi peta
    canvas
      ..drawLine(
        Offset(.0, size.height * .78),
        Offset(size.width, size.height * .22),
        trackPaint,
      )
      ..drawLine(
        Offset(.0, size.height * .83),
        Offset(size.width, size.height * .27),
        trackPaint,
      );

    // Kompas Bintang Besi di Sudut Kanan Atas Peta
    final compass = Offset(size.width - 28.0, 28.0);
    canvas
      ..drawCircle(compass, 14.0, trackPaint)
      ..drawLine(
        Offset(compass.dx, compass.dy - 18.0),
        Offset(compass.dx, compass.dy + 18.0),
        trackPaint,
      )
      ..drawLine(
        Offset(compass.dx - 18.0, compass.dy),
        Offset(compass.dx + 18.0, compass.dy),
        trackPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _OutlawRailroadMapPainter oldDelegate) => false;
}

/// ============================================================================
/// 7. GALERI (ARKANA PERISAI BAJA & KARTU MONOLIT)
/// ============================================================================
class _ObsidianArcanaGallerySection extends StatelessWidget {
  const _ObsidianArcanaGallerySection();

  static final _posters = List.of(const [
    <String, String>{
      'arcana': 'ARCANA #01',
      'title': 'SHADOW ENCOUNTER',
      'caption': 'Awal Pertemuan Dua Pengelana',
    },
    <String, String>{
      'arcana': 'ARCANA #02',
      'title': 'TWIN VANGUARDS',
      'caption': 'Menembus Badai Bersama',
    },
    <String, String>{
      'arcana': 'ARCANA #03',
      'title': 'SILVER ECLIPSE OATH',
      'caption': 'Janji Suci di Bawah Gerhana',
    },
    <String, String>{
      'arcana': 'ARCANA #04',
      'title': 'ETERNAL REIGN',
      'caption': '19 Desember 2026 Selamanya',
    },
  ], growable: false);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 18.0, vertical: 18.0),
      child: OutlawBastionFrame(
        style: .obsidianCharter,
        child: Column(
          children: <Widget>[
            const _OutlawSectionHeader(
              chapterCode: 'CHAPTER VI • HALL OF SOVEREIGNS',
              title: 'Galeri',
              subtitle: 'ARSIP PERJALANAN & IKATAN ABADI',
            ),
            const SizedBox(height: 22.0),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14.0,
                crossAxisSpacing: 14.0,
                childAspectRatio: .66,
              ),
              itemCount: _posters.length,
              itemBuilder: (context, index) {
                final item = _posters[index];
                return ColorFiltered(
                  colorFilter: OutlawPalette.grimMonochromeFilter,
                  child: OutlawBastionFrame(
                    style: .ironShield,
                    showSkullCrest: false,
                    padding: const .all(12.0),
                    child: Column(
                      mainAxisAlignment: .spaceBetween,
                      children: <Widget>[
                        Text(
                          item['arcana']!,
                          style: const TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 2.2,
                            color: OutlawPalette.phantomSilver,
                          ),
                        ),
                        const Expanded(
                          child: Padding(
                            padding: .symmetric(vertical: 6.0),
                            child: OjayMaeOutlawCrest(size: 115.0),
                          ),
                        ),
                        Column(
                          children: <Widget>[
                            FierceOutlawTitle(
                              text: item['title']!,
                              fontSize: 13.0,
                              letterSpacing: 1.5,
                              slashCut: false,
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              item['caption']!,
                              textAlign: .center,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: OutlawPalette.phantomSilver,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22.0),
            const BarbedIronStarDivider(),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 8. KADO PERNIKAHAN (BRANKAS BESI KERAJAAN / ROYAL TREASURY VAULT)
/// ============================================================================
class _BountyChestGiftSection extends StatelessWidget {
  const _BountyChestGiftSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: .symmetric(horizontal: 18.0, vertical: 18.0),
      child: OutlawBastionFrame(
        style: .obsidianCharter,
        child: Column(
          children: <Widget>[
            _OutlawSectionHeader(
              chapterCode: 'CHAPTER VII • THE IRON TREASURY',
              title: 'Kado Pernikahan',
              subtitle: 'PETI PERBENDAHARAAN & TANDA KASIH',
            ),
            SizedBox(height: 16.0),
            Text(
              'Kehadiran dan doa restu Anda di perjamuan kami adalah '
              'kehormatan tertinggi. Namun apabila Anda ingin mengirimkan '
              'tanda kasih secara digital, silakan melalui brankas berikut:',
              textAlign: .center,
              style: TextStyle(color: OutlawPalette.phantomSilver),
            ),
            SizedBox(height: 22.0),
            _OutlawVaultNoteCard(
              bankTitle: 'BRANKAS BANK BCA',
              accountDigits: '1912202688',
              holderName: 'a.n. OJAY',
            ),
            SizedBox(height: 16.0),
            _OutlawVaultNoteCard(
              bankTitle: 'BRANKAS BANK MANDIRI',
              accountDigits: '1912002026999',
              holderName: 'a.n. MAE',
            ),
            SizedBox(height: 22.0),
            BarbedIronStarDivider(),
          ],
        ),
      ),
    );
  }
}

class _OutlawVaultNoteCard extends StatefulWidget {
  const _OutlawVaultNoteCard({
    required this.bankTitle,
    required this.accountDigits,
    required this.holderName,
  });

  final String bankTitle;
  final String accountDigits;
  final String holderName;

  @override
  State<_OutlawVaultNoteCard> createState() => _OutlawVaultNoteCardState();
}

class _OutlawVaultNoteCardState extends State<_OutlawVaultNoteCard> {
  late final TextEditingController _readOnlyCtrl;
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<bool> _copied = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _readOnlyCtrl = TextEditingController(text: widget.accountDigits);
  }

  @override
  void dispose() {
    _readOnlyCtrl.dispose();
    _focusNode.dispose();
    _copied.dispose();
    super.dispose();
  }

  Future<void> _copyVault() async {
    await Clipboard.setData(ClipboardData(text: widget.accountDigits));
    _copied.value = true;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) _copied.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OutlawBastionFrame(
      style: .obsidianCharter,
      showSkullCrest: false,
      padding: const .all(18.0),
      child: Column(
        children: <Widget>[
          FierceOutlawTitle(
            text: widget.bankTitle,
            fontSize: 16.0,
            letterSpacing: 2.5,
            slashCut: false,
          ),
          const SizedBox(height: 10.0),
          EditableText(
            controller: _readOnlyCtrl,
            focusNode: _focusNode,
            readOnly: true,
            textAlign: .center,
            style: const TextStyle(
              fontSize: 22.0,
              fontWeight: .w900,
              letterSpacing: 2.8,
              color: OutlawPalette.boneWhite,
              fontFamily: 'monospace',
            ),
            cursorColor: OutlawPalette.boneWhite,
            backgroundCursorColor: OutlawPalette.gunmetalGrey,
          ),
          const SizedBox(height: 6.0),
          Text(
            widget.holderName,
            style: const TextStyle(color: OutlawPalette.phantomSilver),
          ),
          const SizedBox(height: 14.0),
          ValueListenableBuilder<bool>(
            valueListenable: _copied,
            builder: (context, isCopied, _) {
              return _OutlawTriggerButton(
                label: isCopied
                    ? '✓ NOMOR BRANKAS TERSALIN'
                    : 'SALIN NOMOR REKENING',
                onTap: _copyVault,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 9. RSVP DAN UCAPAN (PRASASTI KEHORMATAN & DOA — FIREBASE)
/// ============================================================================
class _ChronicleOfOathsRsvpSection extends StatefulWidget {
  const _ChronicleOfOathsRsvpSection({required this.controller});

  final RsvpController controller;

  @override
  State<_ChronicleOfOathsRsvpSection> createState() =>
      _ChronicleOfOathsRsvpSectionState();
}

class _ChronicleOfOathsRsvpSectionState
    extends State<_ChronicleOfOathsRsvpSection> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _msgFocus = FocusNode();

  final ValueNotifier<bool> _attending = ValueNotifier<bool>(true);
  final ValueNotifier<int> _pax = ValueNotifier<int>(2);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    _nameFocus.dispose();
    _msgFocus.dispose();
    _attending.dispose();
    _pax.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.controller.submitRsvp(
      name: _nameCtrl.text,
      isAttending: _attending.value,
      pax: _pax.value,
      message: _msgCtrl.text,
    );
    if (ok) {
      _nameCtrl.clear();
      _msgCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 18.0, vertical: 18.0),
      child: OutlawBastionFrame(
        style: .obsidianCharter,
        child: Column(
          crossAxisAlignment: .stretch,
          children: <Widget>[
            const _OutlawSectionHeader(
              chapterCode: 'CHAPTER VIII • CHRONICLE OF OATHS',
              title: 'RSVP dan Ucapan',
              subtitle: 'UKIR NAMA & RESTU KEHORMATAN ANDA',
            ),
            const SizedBox(height: 22.0),
            const Text(
              'NAMA LENGKAP / GELAR TAMU',
              style: TextStyle(
                fontSize: 11.0,
                letterSpacing: 2.0,
                color: OutlawPalette.phantomSilver,
              ),
            ),
            const SizedBox(height: 6.0),
            _OutlawInputBox(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              hint: 'Ketik nama lengkap Anda...',
            ),
            const SizedBox(height: 16.0),
            const Text(
              'STATUS KEHADIRAN DI PERJAMUAN',
              style: TextStyle(
                fontSize: 11.0,
                letterSpacing: 2.0,
                color: OutlawPalette.phantomSilver,
              ),
            ),
            const SizedBox(height: 8.0),
            ValueListenableBuilder<bool>(
              valueListenable: _attending,
              builder: (context, isAttending, _) {
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: _OutlawTriggerButton(
                        label: '★ HADIR',
                        isInverted: isAttending,
                        onTap: () => _attending.value = true,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: _OutlawTriggerButton(
                        label: '✦ BERHALANGAN',
                        isInverted: !isAttending,
                        onTap: () => _attending.value = false,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16.0),
            ValueListenableBuilder<bool>(
              valueListenable: _attending,
              builder: (context, isAttending, _) {
                if (!isAttending) return const SizedBox.shrink();
                return Padding(
                  padding: const .only(bottom: 16.0),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _pax,
                    builder: (context, paxCount, _) {
                      return Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'JUMLAH KEHADIRAN (ORANG)',
                              style: TextStyle(
                                fontSize: 11.0,
                                letterSpacing: 1.8,
                                color: OutlawPalette.phantomSilver,
                              ),
                            ),
                          ),
                          _OutlawTriggerButton(
                            label: '1 ORANG',
                            isInverted: paxCount == 1,
                            onTap: () => _pax.value = 1,
                          ),
                          const SizedBox(width: 8.0),
                          _OutlawTriggerButton(
                            label: '2 ORANG',
                            isInverted: paxCount == 2,
                            onTap: () => _pax.value = 2,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
            const Text(
              'PESAN & DOA RESTU ABADI',
              style: TextStyle(
                fontSize: 11.0,
                letterSpacing: 2.0,
                color: OutlawPalette.phantomSilver,
              ),
            ),
            const SizedBox(height: 6.0),
            _OutlawInputBox(
              controller: _msgCtrl,
              focusNode: _msgFocus,
              hint: 'Tuliskan ucapan selamat & doa untuk Ojay & Mae...',
              maxLines: 3,
            ),
            const SizedBox(height: 18.0),
            ValueListenableBuilder<bool>(
              valueListenable: widget.controller.isSubmittingNotifier,
              builder: (context, busy, _) {
                return _OutlawTriggerButton(
                  label: busy
                      ? 'MENGUKIR PRASASTI KE SERVER...'
                      : '☠ KIRIM KONFIRMASI & UCAPAN ☠',
                  isInverted: true,
                  onTap: busy ? () {} : _submit,
                );
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: widget.controller.feedbackMessageNotifier,
              builder: (context, msg, _) {
                if (msg == null) return const SizedBox.shrink();
                return Padding(
                  padding: const .only(top: 12.0),
                  child: Text(
                    msg,
                    textAlign: .center,
                    style: const TextStyle(fontSize: 12.0),
                  ),
                );
              },
            ),
            const SizedBox(height: 24.0),
            const BarbedIronStarDivider(),
            const SizedBox(height: 18.0),
            ValueListenableBuilder<List<RsvpEntry>>(
              valueListenable: widget.controller.entriesNotifier,
              builder: (context, list, _) {
                return Column(
                  children: List<Widget>.generate(list.length, (idx) {
                    final item = list[idx];
                    return Padding(
                      padding: const .only(bottom: 12.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: OutlawPalette.obsidianDark,
                          border: Border.all(
                            color: OutlawPalette.boneWhite,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: const .all(14.0),
                          child: Column(
                            crossAxisAlignment: .start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: .spaceBetween,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      '☠ ${item.name}',
                                      style: const TextStyle(
                                        fontWeight: .bold,
                                        fontSize: 14.0,
                                      ),
                                    ),
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: OutlawPalette.boneWhite,
                                        width: .8,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const .symmetric(
                                        horizontal: 8.0,
                                        vertical: 2.0,
                                      ),
                                      child: Text(
                                        item.isAttending
                                            ? '★ HADIR (${item.pax})'
                                            : 'BERHALANGAN',
                                        style: const TextStyle(
                                          fontSize: 9.0,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                item.message,
                                style: const TextStyle(
                                  fontSize: 13.0,
                                  color: OutlawPalette.phantomSilver,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 10. TERIMA KASIH (PERISAI MONUMEN PENUTUP)
/// ============================================================================
class _RideIntoEternityThankYouSection extends StatelessWidget {
  const _RideIntoEternityThankYouSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: .fromLTRB(18.0, 18.0, 18.0, 64.0),
      child: OutlawBastionFrame(
        style: .ironShield,
        padding: .fromLTRB(24.0, 48.0, 24.0, 36.0),
        child: Column(
          children: <Widget>[
            _OutlawSectionHeader(
              chapterCode: 'CHAPTER IX • REIGN OF ETERNITY',
              title: 'Terima Kasih',
              subtitle: 'SALAM HORMAT DARI KAMI BERDUA',
            ),
            SizedBox(height: 20.0),
            OjayMaeOutlawCrest(size: 165.0),
            SizedBox(height: 16.0),
            Text(
              'Merupakan kehormatan tertinggi bagi kami apabila Bapak/Ibu/Saudara/i '
              'berkenan hadir dan memberikan doa restu bagi langkah awal perjalanan kami.',
              textAlign: .center,
              style: TextStyle(color: OutlawPalette.phantomSilver),
            ),
            SizedBox(height: 18.0),
            FierceOutlawTitle(
              text: 'Ojay & Mae',
              fontSize: 38.0,
              letterSpacing: 2.5,
            ),
            SizedBox(height: 6.0),
            FierceOutlawTitle(
              text: '1912 • 2026',
              fontSize: 18.0,
              letterSpacing: 4.0,
              slashCut: false,
            ),
            SizedBox(height: 6.0),
            ArchedGothicMotto(
              text: 'Till death do us part',
              fontSize: 20.0,
              height: 52.0,
            ),
            BarbedIronStarDivider(width: 180.0),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// KOMPONEN MURNI PENDUKUNG BERTEMA BESI TEMPA & GOTHIC SOVEREIGN
/// ============================================================================
class _OutlawSectionHeader extends StatelessWidget {
  const _OutlawSectionHeader({
    required this.chapterCode,
    required this.title,
    required this.subtitle,
  });

  final String chapterCode;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          chapterCode,
          style: const TextStyle(
            fontSize: 10.0,
            letterSpacing: 3.0,
            color: OutlawPalette.gunmetalGrey,
          ),
        ),
        const SizedBox(height: 8.0),
        FierceOutlawTitle(text: title, fontSize: 28.0, letterSpacing: 2.5),
        const SizedBox(height: 6.0),
        Text(
          subtitle,
          textAlign: .center,
          style: const TextStyle(
            fontSize: 10.0,
            letterSpacing: 2.8,
            color: OutlawPalette.phantomSilver,
          ),
        ),
      ],
    );
  }
}

class _SovereignShieldMedallion extends StatelessWidget {
  const _SovereignShieldMedallion({
    required this.monogram,
    required this.roleLabel,
  });

  final String monogram;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: OutlawPalette.grimMonochromeFilter,
      child: SizedBox(
        width: 180.0,
        height: 220.0,
        child: OutlawBastionFrame(
          style: .ironShield,
          showSkullCrest: false,
          padding: const .all(16.0),
          child: Column(
            mainAxisAlignment: .center,
            children: <Widget>[
              const Text(
                '★ SOVEREIGN ★',
                style: TextStyle(
                  fontSize: 9.0,
                  letterSpacing: 3.0,
                  color: OutlawPalette.phantomSilver,
                ),
              ),
              const SizedBox(height: 8.0),
              FierceOutlawTitle(
                text: monogram,
                fontSize: 64.0,
                letterSpacing: 2.0,
              ),
              const SizedBox(height: 8.0),
              Text(
                roleLabel,
                textAlign: .center,
                style: const TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 2.0,
                  color: OutlawPalette.phantomSilver,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlawTriggerButton extends StatelessWidget {
  const _OutlawTriggerButton({
    required this.label,
    required this.onTap,
    this.isInverted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isInverted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isInverted
              ? OutlawPalette.boneWhite
              : OutlawPalette.frameBackground,
          border: Border.all(color: OutlawPalette.boneWhite, width: 1.5),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 18.0, vertical: 12.0),
          child: Center(
            child: Text(
              label,
              textAlign: .center,
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: .w900,
                letterSpacing: 2.2,
                color: isInverted
                    ? OutlawPalette.voidBlack
                    : OutlawPalette.boneWhite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlawInputBox extends StatelessWidget {
  const _OutlawInputBox({
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: focusNode.requestFocus,
      behavior: .opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OutlawPalette.obsidianDark,
          border: Border.all(color: OutlawPalette.boneWhite, width: 1.2),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 14.0, vertical: 12.0),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, val, _) {
              return Stack(
                alignment: .topLeft,
                children: <Widget>[
                  if (val.text.isEmpty)
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 13.0,
                        color: OutlawPalette.gunmetalGrey,
                      ),
                    ),
                  EditableText(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: maxLines,
                    style: const TextStyle(
                      fontSize: 14.0,
                      color: OutlawPalette.boneWhite,
                      fontFamily: 'HauntedSerif',
                    ),
                    cursorColor: OutlawPalette.boneWhite,
                    backgroundCursorColor: OutlawPalette.gunmetalGrey,
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

@immutable
class RsvpEntry {
  factory RsvpEntry.fromDoc(DocumentSnapshot doc) {
    final data =
        (doc.data() ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final timestamp = data['createdAt'] as Timestamp?;
    return RsvpEntry(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Tamu Kehormatan',
      isAttending: ((data['attendance'] as num?)?.toInt() ?? 1) == 1,
      pax: (data['pax'] as num?)?.toInt() ?? 1,
      message: (data['message'] as String?) ?? '',
      createdAt: timestamp?.toDate() ?? DateTime.now(),
    );
  }
  const RsvpEntry({
    required this.id,
    required this.name,
    required this.isAttending,
    required this.pax,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String name;
  final bool isAttending;
  final int pax;
  final String message;
  final DateTime createdAt;

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'name': name,
    'attendance': isAttending ? 1 : 0,
    'pax': isAttending ? pax : 0,
    'message': message,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class RsvpController {
  RsvpController({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  final ValueNotifier<List<RsvpEntry>>
  entriesNotifier = ValueNotifier<List<RsvpEntry>>(
    List<RsvpEntry>.of(<RsvpEntry>[
      RsvpEntry(
        id: 'seed_1',
        name: 'Keluarga Besar Hendrawan',
        isAttending: true,
        pax: 2,
        message:
            'Selamat menempuh ikatan suci Ojay & Mae. Semoga selalu diberkahi kebahagiaan dan ketangguhan bersama.',
        createdAt: DateTime(2026, 11, 3, 19, 30),
      ),
      RsvpEntry(
        id: 'seed_2',
        name: 'Raka & Dinda',
        isAttending: true,
        pax: 2,
        message:
            'Tema undangannya sangar dan berkelas luar biasa! Lancar sampai hari H Tanggal 19 Desember 2026.',
        createdAt: DateTime(2026, 11, 3, 20, 15),
      ),
    ], growable: false),
  );

  final ValueNotifier<bool> isSubmittingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> feedbackMessageNotifier = ValueNotifier<String?>(
    null,
  );

  static const Map<String, String> _firebaseErrorLookup = <String, String>{
    'permission-denied':
        'Akses ditolak oleh gerbang server. Periksa izin Firestore.',
    'unavailable':
        'Koneksi terputus dari jaringan. Silakan coba beberapa saat lagi.',
    'deadline-exceeded':
        'Waktu pengiriman habis. Periksa kestabilan jaringan Anda.',
    'resource-exhausted': 'Kuota pesan sedang penuh. Silakan tunggu sejenak.',
  };

  Future<void> loadInitialMessages() async {
    final db = _firestore;
    if (db == null) return;

    try {
      final snapshot = await db
          .collection('rsvps')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .get();

      if (snapshot.docs.isNotEmpty) {
        entriesNotifier.value = List<RsvpEntry>.generate(
          snapshot.docs.length,
          (index) => RsvpEntry.fromDoc(snapshot.docs[index]),
          growable: false,
        );
      }
    } on FirebaseException catch (e) {
      feedbackMessageNotifier.value =
          _firebaseErrorLookup[e.code] ?? 'Gagal memuat daftar ucapan.';
    }
  }

  Future<bool> submitRsvp({
    required String name,
    required bool isAttending,
    required int pax,
    required String message,
  }) async {
    final cleanName = name.trim();
    final cleanMessage = message.trim();

    if (cleanName.isEmpty || cleanMessage.isEmpty) {
      feedbackMessageNotifier.value =
          'Nama lengkap dan untaian doa wajib diisi.';
      return false;
    }

    isSubmittingNotifier.value = true;
    feedbackMessageNotifier.value = null;

    final optimisticEntry = RsvpEntry(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      isAttending: isAttending,
      pax: isAttending ? pax : 0,
      message: cleanMessage,
      createdAt: DateTime.now(),
    );

    final current = entriesNotifier.value;
    final updated = List<RsvpEntry>.generate(
      current.length + 1,
      (i) => i == 0 ? optimisticEntry : current[i - 1],
      growable: false,
    );
    entriesNotifier.value = updated;

    final db = _firestore;
    if (db != null) {
      try {
        await db.collection('rsvps').add(optimisticEntry.toFirestore());
      } on FirebaseException catch (e) {
        isSubmittingNotifier.value = false;
        feedbackMessageNotifier.value =
            _firebaseErrorLookup[e.code] ?? 'Gagal menyimpan ke server.';
        return false;
      }
    }

    isSubmittingNotifier.value = false;
    feedbackMessageNotifier.value =
        'Tanda kehadiran & doa Anda telah terukir dengan hormat.';
    return true;
  }

  void dispose() {
    entriesNotifier.dispose();
    isSubmittingNotifier.dispose();
    feedbackMessageNotifier.dispose();
  }
}

abstract final class OutlawPalette {
  static const Color voidBlack = Color(0xFF000000);
  static const Color frameBackground = Color(0xBB000000);
  static const Color obsidianDark = Color(0xFF080808);

  static const Color boneWhite = Color(0xFFFFFFFF);
  static const Color phantomSilver = Color(0xFFC8C8C8);
  static const Color gunmetalGrey = Color(0xFF666666);

  static const ColorFilter grimMonochromeFilter = ColorFilter.matrix(<double>[
    .55,
    .55,
    .20,
    .0,
    -40.0,
    .55,
    .55,
    .20,
    .0,
    -40.0,
    .55,
    .55,
    .20,
    .0,
    -40.0,
    .0,
    .0,
    .0,
    1.0,
    .0,
  ]);
}

/// Tipografi Sangar dengan Efek Tebasan Pedang Perak & Outline Ganda
class FierceOutlawTitle extends StatelessWidget {
  const FierceOutlawTitle({
    super.key,
    required this.text,
    this.fontSize = 28.0,
    this.letterSpacing = 3.0,
    this.slashCut = true,
  });

  final String text;
  final double fontSize;
  final double letterSpacing;
  final bool slashCut;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: 'OutlawBlackletter',
      fontFamilyFallback: const <String>['WesternSlab', 'serif'],
      fontSize: fontSize,
      fontWeight: .w900,
      letterSpacing: letterSpacing,
      height: 1.1,
    );

    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: slashCut ? const _SlashScarOverlayPainter() : null,
        child: Stack(
          alignment: .center,
          children: <Widget>[
            Transform.translate(
              offset: const Offset(2.5, 2.5),
              child: Text(
                text.toUpperCase(),
                textAlign: .center,
                style: baseStyle.copyWith(
                  foreground: Paint()
                    ..style = .stroke
                    ..strokeWidth = 1.2
                    ..color = const Color(0x77FFFFFF),
                ),
              ),
            ),
            Text(
              text.toUpperCase(),
              textAlign: .center,
              style: baseStyle.copyWith(color: OutlawPalette.boneWhite),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlashScarOverlayPainter extends CustomPainter {
  const _SlashScarOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scarBlack = Paint()
      ..color = OutlawPalette.voidBlack
      ..strokeWidth = 1.8
      ..style = .stroke;

    final scarWhite = Paint()
      ..color = OutlawPalette.boneWhite
      ..strokeWidth = .7
      ..style = .stroke;

    final yMid = size.height * .48;
    canvas
      ..drawLine(
        Offset(size.width * .08, yMid - 2.0),
        Offset(size.width * .92, yMid + 2.0),
        scarBlack,
      )
      ..drawLine(
        Offset(size.width * .15, yMid - 3.5),
        Offset(size.width * .45, yMid - 1.5),
        scarWhite,
      );
  }

  @override
  bool shouldRepaint(covariant _SlashScarOverlayPainter oldDelegate) => false;
}

/// Teks Melengkung Busur Bergaya Banner Gotik
class ArchedGothicMotto extends StatelessWidget {
  const ArchedGothicMotto({
    super.key,
    required this.text,
    this.height = 64.0,
    this.fontSize = 22.0,
  });

  final String text;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 320.0,
        height: height,
        child: CustomPaint(
          painter: _ArchedTextPainter(text: text, fontSize: fontSize),
        ),
      ),
    );
  }
}

class _ArchedTextPainter extends CustomPainter {
  _ArchedTextPainter({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * .82;
    final center = Offset(size.width * .5, -radius + size.height * .78);

    final chars = text.split('');
    const totalAngle = .56;
    final startAngle = (math.pi * .5) + (totalAngle * .5);
    final step = chars.length > 1 ? totalAngle / (chars.length - 1) : .0;

    for (var i = 0; i < chars.length; i++) {
      final angle = startAngle - (i * step);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: chars[i],
          style: TextStyle(
            fontFamily: 'OutlawBlackletter',
            fontFamilyFallback: const <String>['serif'],
            fontSize: fontSize,
            fontWeight: .w900,
            color: OutlawPalette.boneWhite,
            shadows: const <Shadow>[
              Shadow(color: OutlawPalette.boneWhite, blurRadius: 1.5),
            ],
          ),
        ),
        textDirection: .ltr,
      )..layout();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle - math.pi * .5);
      tp.paint(canvas, Offset(-tp.width * .5, -tp.height * .5));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ArchedTextPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.fontSize != fontSize;
}

/// Partikel Badai Bara Perak Malam (Zero Allocation via Float32List)
class NightEclipseEmberStorm extends StatefulWidget {
  const NightEclipseEmberStorm({super.key, this.emberCount = 72});

  final int emberCount;

  @override
  State<NightEclipseEmberStorm> createState() => _NightEclipseEmberStormState();
}

class _NightEclipseEmberStormState extends State<NightEclipseEmberStorm>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _tickNotifier = ValueNotifier<int>(0);
  late final Float32List _emberSegments;
  late final Float32List _speeds;
  Size _viewport = .zero;

  @override
  void initState() {
    super.initState();
    final n = widget.emberCount;
    _emberSegments = Float32List(n * 4);
    _speeds = Float32List(n * 2);

    final rng = math.Random(19122026);
    for (var i = 0; i < n; i++) {
      final sIdx = i * 2;
      _speeds[sIdx] = .4 + rng.nextDouble() * 1.1;
      _speeds[sIdx + 1] = -(.3 + rng.nextDouble() * .9);
    }

    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_viewport == .zero) return;
    final w = _viewport.width;
    final h = _viewport.height;
    final n = widget.emberCount;

    for (var i = 0; i < n; i++) {
      final idx = i * 4;
      final sIdx = i * 2;
      final vx = _speeds[sIdx];
      final vy = _speeds[sIdx + 1];

      var x = _emberSegments[idx] + vx;
      var y = _emberSegments[idx + 1] + vy;

      if (x > w) x = .0;
      if (y < .0) y = h;

      _emberSegments[idx] = x;
      _emberSegments[idx + 1] = y;
      _emberSegments[idx + 2] = x - vx * 3.5;
      _emberSegments[idx + 3] = y - vy * 3.5;
    }
    _tickNotifier.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tickNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_viewport != size && size.width > .0) {
            final rng = math.Random(1926);
            for (var i = 0; i < widget.emberCount; i++) {
              final idx = i * 4;
              final x = rng.nextDouble() * size.width;
              final y = rng.nextDouble() * size.height;
              _emberSegments[idx] = x;
              _emberSegments[idx + 1] = y;
              _emberSegments[idx + 2] = x - 3.0;
              _emberSegments[idx + 3] = y + 3.0;
            }
            _viewport = size;
          }
          return CustomPaint(
            size: size,
            painter: _NightEclipseEmberPainter(
              segments: _emberSegments,
              repaint: _tickNotifier,
            ),
          );
        },
      ),
    );
  }
}

class _NightEclipseEmberPainter extends CustomPainter {
  _NightEclipseEmberPainter({
    required this.segments,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Float32List segments;

  static final Paint _streakPaint = Paint()
    ..color = const Color(0x48FFFFFF)
    ..strokeWidth = 2.5
    ..strokeCap = .round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRawPoints(ui.PointMode.lines, segments, _streakPaint);
  }

  @override
  bool shouldRepaint(covariant _NightEclipseEmberPainter oldDelegate) => false;
}

/// Bingkai Perisai Ksatria Besi (Iron Shield), Kubah Katedral Gotik, & Plakat Baja
enum OutlawFrameStyle {
  ironShield, // Perisai Tempur Ksatria (Heraldic Aegis War Shield — bebas pamali)
  obsidianCharter, // Plakat Baja Berpaku Keling & Duri Besi
  gothicSpire, // Kubah Runcing Katedral Gotik & Menara Kembar
}

class OutlawBastionFrame extends StatelessWidget {
  const OutlawBastionFrame({
    super.key,
    required this.child,
    this.style = .obsidianCharter,
    this.padding = const .fromLTRB(24.0, 32.0, 24.0, 28.0),
    this.showSkullCrest = true,
  });

  final Widget child;
  final OutlawFrameStyle style;
  final EdgeInsetsGeometry padding;
  final bool showSkullCrest;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _OutlawBastionFramePainter(
          style: style,
          showSkullCrest: showSkullCrest,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _OutlawBastionFramePainter extends CustomPainter {
  _OutlawBastionFramePainter({
    required this.style,
    required this.showSkullCrest,
  });

  final OutlawFrameStyle style;
  final bool showSkullCrest;

  Size? _cachedSize;
  Path? _outerBorder;
  Path? _innerBorder;
  Path? _ironSpikesAndRivets;

  static final Paint _thickWhite = Paint()
    ..color = OutlawPalette.boneWhite
    ..style = .stroke
    ..strokeWidth = 1.8;

  static final Paint _thinWhite = Paint()
    ..color = const Color(0xBBFFFFFF)
    ..style = .stroke
    ..strokeWidth = .9;

  static final Paint _fillWhite = Paint()
    ..color = OutlawPalette.boneWhite
    ..style = .fill;

  static final Paint _solidBlackFill = Paint()
    ..color = OutlawPalette.voidBlack
    ..style = .fill;

  static final Paint _frameBgFill = Paint()
    ..color = OutlawPalette.frameBackground
    ..style = .fill;

  void _compilePaths(Size size) {
    final w = size.width;
    final h = size.height;
    const pad = 7.0;

    final outer = Path();
    final inner = Path();
    final details = Path();

    switch (style) {
      case .ironShield:
        // Perisai Ksatria Besi (Heraldic War Shield)
        const notch = 20.0;
        final shieldWallY = h - math.min(w * .14, 52.0);
        final bottomTaperX = math.min(w * .09, 34.0);

        outer
          ..moveTo(notch, .0)
          ..lineTo(w - notch, .0)
          ..lineTo(w, notch)
          ..lineTo(w, shieldWallY)
          ..lineTo(w - bottomTaperX, h)
          ..lineTo(w * .5, h + 4.0)
          ..lineTo(bottomTaperX, h)
          ..lineTo(.0, shieldWallY)
          ..lineTo(.0, notch)
          ..close();

        inner
          ..moveTo(notch + 4.0, pad)
          ..lineTo(w - notch - 4.0, pad)
          ..lineTo(w - pad, notch + 4.0)
          ..lineTo(w - pad, shieldWallY - 3.0)
          ..lineTo(w - bottomTaperX - 4.0, h - pad)
          ..lineTo(w * .5, h - pad + 3.0)
          ..lineTo(bottomTaperX + 4.0, h - pad)
          ..lineTo(pad, shieldWallY - 3.0)
          ..lineTo(pad, notch + 4.0)
          ..close();

        // Ornamen Bintang Perisai di Bahu Kiri & Kanan
        _addStarSpikeCluster(details, notch, .0);
        _addStarSpikeCluster(details, w - notch, .0);
        _addStarSpikeCluster(details, .0, shieldWallY);
        _addStarSpikeCluster(details, w, shieldWallY);

      case .gothicSpire:
        // Kubah Runcing Katedral Gotik (Pointed Cathedral Arch + Side Finials)
        final spireH = math.min(w * .28, 62.0);
        outer
          ..moveTo(.0, spireH)
          ..lineTo(.0, spireH - 18.0) // Menara runcing kiri
          ..lineTo(12.0, spireH - 6.0)
          ..quadraticBezierTo(
            w * .24,
            6.0,
            w * .5,
            -8.0,
          ) // Puncak Runcing Gotik
          ..quadraticBezierTo(w * .76, 6.0, w - 12.0, spireH - 6.0)
          ..lineTo(w, spireH - 18.0) // Menara runcing kanan
          ..lineTo(w, spireH)
          ..lineTo(w, h)
          ..lineTo(.0, h)
          ..close();

        inner
          ..moveTo(pad, spireH + 2.0)
          ..quadraticBezierTo(w * .25, 14.0, w * .5, 2.0)
          ..quadraticBezierTo(w * .75, 14.0, w - pad, spireH + 2.0)
          ..lineTo(w - pad, h - pad)
          ..lineTo(pad, h - pad)
          ..close();

      case .obsidianCharter:
        // Plakat Baja Besi Tempa dengan Sudut Terpotong Geometris
        const c = 18.0;
        outer
          ..moveTo(c, .0)
          ..lineTo(w - c, .0)
          ..lineTo(w - c * .5, c * .5)
          ..lineTo(w, c)
          ..lineTo(w, h - c)
          ..lineTo(w - c * .5, h - c * .5)
          ..lineTo(w - c, h)
          ..lineTo(c, h)
          ..lineTo(c * .5, h - c * .5)
          ..lineTo(.0, h - c)
          ..lineTo(.0, c)
          ..lineTo(c * .5, c * .5)
          ..close();

        inner.addRect(Rect.fromLTWH(pad, pad, w - pad * 2.0, h - pad * 2.0));

        // Rantai Duri Besi (Iron Thorns) di garis atas dan bawah
        _addIronThorns(details, w * .2, .0, w * .8);
        _addIronThorns(details, w * .2, h, w * .8);
    }

    _outerBorder = outer;
    _innerBorder = inner;
    _ironSpikesAndRivets = details;
    _cachedSize = size;
  }

  void _addStarSpikeCluster(Path path, double x, double y) {
    const s = 6.5;
    path
      ..moveTo(x - s, y)
      ..lineTo(x + s, y)
      ..moveTo(x, y - s)
      ..lineTo(x, y + s);
  }

  void _addIronThorns(Path path, double startX, double y, double endX) {
    const step = 44.0;
    for (var x = startX; x <= endX; x += step) {
      path
        ..moveTo(x - 5.0, y - 5.0)
        ..lineTo(x + 5.0, y + 5.0)
        ..moveTo(x + 5.0, y - 5.0)
        ..lineTo(x - 5.0, y + 5.0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedSize != size || _outerBorder == null) {
      _compilePaths(size);
    }

    canvas
      ..drawPath(_outerBorder!, _frameBgFill)
      ..drawPath(_outerBorder!, _thickWhite)
      ..drawPath(_innerBorder!, _thinWhite)
      ..drawPath(_ironSpikesAndRivets!, _thickWhite);

    // Roda Gigi / Silinder Baja 6 Paku di Keempat Sudut Plakat
    if (style == .obsidianCharter) {
      _drawIronCylinderRosette(canvas, const Offset(20.0, 20.0), 8.5);
      _drawIronCylinderRosette(canvas, Offset(size.width - 20.0, 20.0), 8.5);
      _drawIronCylinderRosette(canvas, Offset(20.0, size.height - 20.0), 8.5);
      _drawIronCylinderRosette(
        canvas,
        Offset(size.width - 20.0, size.height - 20.0),
        8.5,
      );
    }

    // Emblem Tengkorak Bersayap Malam (Winged Skull Crest) di Puncak Atas Bingkai
    if (showSkullCrest) {
      _drawIronSkullCrest(canvas, Offset(size.width * .5, .0));
    }
  }

  void _drawIronCylinderRosette(Canvas canvas, Offset center, double radius) {
    canvas
      ..drawCircle(center, radius, _solidBlackFill)
      ..drawCircle(center, radius, _thinWhite)
      ..drawCircle(center, 1.8, _fillWhite);

    for (var i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3.0);
      final hole = Offset(
        center.dx + (radius * .56) * math.cos(angle),
        center.dy + (radius * .56) * math.sin(angle),
      );
      canvas.drawCircle(hole, 1.6, _fillWhite);
    }
  }

  void _drawIronSkullCrest(Canvas canvas, Offset center) {
    // Medali Perisai Lingkar Hitam-Putih
    canvas
      ..drawCircle(center, 16.0, _solidBlackFill)
      ..drawCircle(center, 16.0, _thickWhite);

    // Sayap Elang/Gagak Malam (Dark Sovereign Wings) di Kiri & Kanan Medali
    final wings = Path()
      ..moveTo(center.dx - 14.0, center.dy - 2.0)
      ..quadraticBezierTo(
        center.dx - 32.0,
        center.dy - 16.0,
        center.dx - 44.0,
        center.dy - 4.0,
      )
      ..quadraticBezierTo(
        center.dx - 30.0,
        center.dy - 4.0,
        center.dx - 15.0,
        center.dy + 4.0,
      )
      ..moveTo(center.dx + 14.0, center.dy - 2.0)
      ..quadraticBezierTo(
        center.dx + 32.0,
        center.dy - 16.0,
        center.dx + 44.0,
        center.dy - 4.0,
      )
      ..quadraticBezierTo(
        center.dx + 30.0,
        center.dy - 4.0,
        center.dx + 15.0,
        center.dy + 4.0,
      );
    canvas.drawPath(wings, _fillWhite);

    // Kepala Tengkorak Putih di Dalam Medali
    canvas
      ..drawCircle(Offset(center.dx, center.dy - 2.0), 9.0, _fillWhite)
      ..drawRect(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 7.0),
          width: 10.0,
          height: 6.0,
        ),
        _fillWhite,
      )
      ..drawCircle(
        Offset(center.dx - 3.5, center.dy - 2.0),
        2.4,
        _solidBlackFill,
      )
      ..drawCircle(
        Offset(center.dx + 3.5, center.dy - 2.0),
        2.4,
        _solidBlackFill,
      );

    // Garis Gigi Tengkorak
    for (var dx = -3.0; dx <= 3.0; dx += 3.0) {
      canvas.drawLine(
        Offset(center.dx + dx, center.dy + 4.5),
        Offset(center.dx + dx, center.dy + 9.5),
        Paint()
          ..color = OutlawPalette.voidBlack
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OutlawBastionFramePainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.showSkullCrest != showSkullCrest;
}

/// Pembatas Seksi: Kawat Duri Besi + Bintang Kompas Segi Enam
class BarbedIronStarDivider extends StatelessWidget {
  const BarbedIronStarDivider({super.key, this.width = 280.0});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width,
        height: 36.0,
        child: const CustomPaint(painter: _BarbedIronStarDividerPainter()),
      ),
    );
  }
}

class _BarbedIronStarDividerPainter extends CustomPainter {
  const _BarbedIronStarDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * .5;
    final cy = size.height * .5;

    final wirePaint = Paint()
      ..color = OutlawPalette.boneWhite
      ..strokeWidth = 1.3
      ..style = .stroke;

    final fillWhite = Paint()
      ..color = OutlawPalette.boneWhite
      ..style = .fill;

    canvas
      ..drawLine(Offset(.0, cy), Offset(cx - 28.0, cy), wirePaint)
      ..drawLine(Offset(cx + 28.0, cy), Offset(size.width, cy), wirePaint);

    for (final x in <double>[cx - 95.0, cx - 58.0, cx + 58.0, cx + 95.0]) {
      if (x > 8.0 && x < size.width - 8.0) {
        canvas
          ..drawLine(
            Offset(x - 4.0, cy - 5.0),
            Offset(x + 4.0, cy + 5.0),
            wirePaint,
          )
          ..drawLine(
            Offset(x + 4.0, cy - 5.0),
            Offset(x - 4.0, cy + 5.0),
            wirePaint,
          );
      }
    }

    final starPath = Path();
    for (var i = 0; i < 12; i++) {
      final r = i.isEven ? 14.0 : 7.0;
      final a = i * (math.pi / 6.0) - (math.pi * .5);
      final px = cx + r * math.cos(a);
      final py = cy + r * math.sin(a);
      if (i == 0) {
        starPath.moveTo(px, py);
      } else {
        starPath.lineTo(px, py);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, wirePaint);
    canvas.drawCircle(Offset(cx, cy), 3.2, fillWhite);
  }

  @override
  bool shouldRepaint(covariant _BarbedIronStarDividerPainter oldDelegate) =>
      false;
}

/// Ilustrasi Utama Ojay & Mae + Bingkai Halo Gerhana Berduri Putih
class OjayMaeOutlawCrest extends StatelessWidget {
  const OjayMaeOutlawCrest({super.key, this.size = 240.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          foregroundPainter: const _OutlawHaloSpikesPainter(),
          child: Padding(
            padding: const .all(10.0),
            child: Image.asset(
              'assets/images/ojay_mae_cover.png',
              fit: .contain,
              filterQuality: .high,
              errorBuilder: (context, error, stackTrace) {
                return const CustomPaint(
                  painter: _IronSkullTwinSabersCrestFallbackPainter(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlawHaloSpikesPainter extends CustomPainter {
  const _OutlawHaloSpikesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * .5;
    final cy = size.height * .5;
    final r = math.min(cx, cy) - 2.0;

    final stroke = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = .stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset(cx, cy), r, stroke);
    for (var i = 0; i < 16; i++) {
      final a = i * (math.pi / 8.0);
      final innerR = i.isEven ? r - 6.0 : r - 3.0;
      final outerR = i.isEven ? r + 5.0 : r + 2.0;
      canvas.drawLine(
        Offset(cx + innerR * math.cos(a), cy + innerR * math.sin(a)),
        Offset(cx + outerR * math.cos(a), cy + outerR * math.sin(a)),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OutlawHaloSpikesPainter oldDelegate) => false;
}

/// Fallback Ilustrasi Bebas Pamali namun Sangar: Perisai Pedang Kembar, Tengkorak, & Mawar Hitam
class _IronSkullTwinSabersCrestFallbackPainter extends CustomPainter {
  const _IronSkullTwinSabersCrestFallbackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * .5;
    final cy = size.height * .5;

    final whiteStroke = Paint()
      ..color = OutlawPalette.boneWhite
      ..style = .stroke
      ..strokeWidth = 1.8;

    final whiteFill = Paint()
      ..color = OutlawPalette.boneWhite
      ..style = .fill;

    // Pedang Kembar Menyilang di Belakang Perisai (Twin Crossed Sabers)
    canvas
      ..drawLine(
        Offset(cx - 56.0, cy + 52.0),
        Offset(cx + 56.0, cy - 52.0),
        whiteStroke,
      )
      ..drawLine(
        Offset(cx + 56.0, cy + 52.0),
        Offset(cx - 56.0, cy - 52.0),
        whiteStroke,
      );

    // Perisai Ksatria Tengah (Heraldic Escutcheon Shield)
    final shield = Path()
      ..moveTo(cx - 34.0, cy - 34.0)
      ..lineTo(cx + 34.0, cy - 34.0)
      ..lineTo(cx + 34.0, cy + 4.0)
      ..quadraticBezierTo(cx + 28.0, cy + 36.0, cx, cy + 52.0)
      ..quadraticBezierTo(cx - 28.0, cy + 36.0, cx - 34.0, cy + 4.0)
      ..close();
    canvas
      ..drawPath(
        shield,
        Paint()
          ..color = OutlawPalette.voidBlack
          ..style = .fill,
      )
      ..drawPath(shield, whiteStroke);

    // Mahkota Besi Raja & Ratu di Atas Perisai
    final crown = Path()
      ..moveTo(cx - 22.0, cy - 38.0)
      ..lineTo(cx - 26.0, cy - 56.0)
      ..lineTo(cx - 11.0, cy - 46.0)
      ..lineTo(cx, cy - 62.0)
      ..lineTo(cx + 11.0, cy - 46.0)
      ..lineTo(cx + 26.0, cy - 56.0)
      ..lineTo(cx + 22.0, cy - 38.0)
      ..close();
    canvas.drawPath(crown, whiteStroke);

    // Mawar Gotik Geometris & Bintang Inti di Tengah Perisai
    canvas
      ..drawCircle(Offset(cx, cy + 4.0), 14.0, whiteStroke)
      ..drawCircle(Offset(cx, cy + 4.0), 4.5, whiteFill);
  }

  @override
  bool shouldRepaint(
    covariant _IronSkullTwinSabersCrestFallbackPainter oldDelegate,
  ) => false;
}
