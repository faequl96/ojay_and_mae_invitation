import 'package:material_ui/material_ui.dart';

// ============================================================================
// KONSTANTA ASET & KONFIGURASI TIPOGRAFI
// ============================================================================
abstract final class InvitationAssets._() {
  static const String bankBCA = 'assets/images/BCA.png';
  static const String coverBg = 'assets/images/COVER-1-BG-tengkorak.png';
  static const String coverInitialFF = 'assets/images/COVER-1-inisial-FF.png';
  static const String heroBg = 'assets/images/2-BG-tengkorak.png';
  static const String skullCouple = 'assets/images/2-tengkorak-ojay-mae.png';
  static const String skullGroom = 'assets/images/3-tengkorak-ojay.png';
  static const String flower = 'assets/images/4-Bunga-samping-tengkorak-wanita.png';
  static const String leaf = 'assets/images/4-Daun-Font-Mae.png';
  static const String skullBride = 'assets/images/4-Tengkorak-Mae.png';
  static const String flowerGift = 'assets/images/6-Bunga-Wedding-Gift.png';
  static const String music = 'assets/musics/music.mp3';

  /// Aset kritikal di atas lipatan (cover gate) yang diprecache sebelum frame pertama.
  static const List<String> coverCritical = [coverBg, coverInitialFF];

  /// Aset lanjutan yang diprecache di latar belakang setelah frame pertama tampil.
  static const List<String> deferred = [
    heroBg,
    skullCouple,
    skullGroom,
    flower,
    leaf,
    skullBride,
    flowerGift,
    bankBCA,
  ];

  static const List<String> all = [...coverCritical, ...deferred];
}

abstract final class GothicTheme._() {
  static const Color bgBlack = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFD8D8D8);
  static const Color cardSurface = Color(0xFF141414);

  static const String fontGothic = 'AngelWish';
  static const String fontGothicAlt = 'AngelRhapsody';
  static const String fontScript = 'BirdsOfParadise';

  static const List<String> _gothicFallback = [fontGothicAlt, 'serif'];
  static const List<String> _gothicAltFallback = ['serif'];
  static const List<String> _scriptFallback = ['cursive', 'serif'];

  static const TextStyle gothic24 = TextStyle(
    fontFamily: fontGothic,
    fontFamilyFallback: _gothicFallback,
    fontSize: 24,
    color: white,
    height: 1.15,
    letterSpacing: 0.8,
  );

  static const TextStyle gothic36 = TextStyle(
    fontFamily: fontGothic,
    fontFamilyFallback: _gothicFallback,
    fontSize: 36,
    color: white,
    height: 1.15,
    letterSpacing: 0.8,
  );

  static const TextStyle gothicAlt42 = TextStyle(
    fontFamily: fontGothicAlt,
    fontFamilyFallback: _gothicAltFallback,
    fontSize: 42,
    color: white,
    letterSpacing: 1.4,
  );

  static const TextStyle gothicAlt44 = TextStyle(
    fontFamily: fontGothicAlt,
    fontFamilyFallback: _gothicAltFallback,
    fontSize: 44,
    color: white,
    letterSpacing: 1.4,
  );

  static const TextStyle gothicAlt46 = TextStyle(
    fontFamily: fontGothicAlt,
    fontFamilyFallback: _gothicAltFallback,
    fontSize: 46,
    color: white,
    letterSpacing: 1.4,
  );

  static const TextStyle gothicAlt160 = TextStyle(
    fontFamily: fontGothicAlt,
    fontFamilyFallback: _gothicAltFallback,
    fontSize: 160,
    color: white,
    letterSpacing: 1.4,
  );

  static const TextStyle script16 = TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: _scriptFallback,
    fontSize: 16,
    color: white,
    height: 1.25,
  );

  static const TextStyle script24 = TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: _scriptFallback,
    fontSize: 24,
    color: white,
    height: 1.25,
  );

  static const TextStyle script28 = TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: _scriptFallback,
    fontSize: 28,
    color: white,
    height: 1.25,
  );

  static const TextStyle script30 = TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: _scriptFallback,
    fontSize: 30,
    color: white,
    height: 1.25,
  );

  static const TextStyle script32 = TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: _scriptFallback,
    fontSize: 32,
    color: white,
    height: 1.25,
  );

  static const TextStyle script34 = TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: _scriptFallback,
    fontSize: 34,
    color: white,
    height: 1.25,
  );

  static const TextStyle script36 = TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: _scriptFallback,
    fontSize: 36,
    color: white,
    height: 1.25,
  );

  static const TextStyle snackbarBold = TextStyle(color: bgBlack, fontWeight: .bold);

  static TextStyle gothic({double size = 32, Color color = white}) => TextStyle(
    fontFamily: fontGothic,
    fontFamilyFallback: _gothicFallback,
    fontSize: size,
    color: color,
    height: 1.15,
    letterSpacing: 0.8,
  );

  static TextStyle gothicAlt({double size = 34, Color color = white}) => TextStyle(
    fontFamily: fontGothicAlt,
    fontFamilyFallback: _gothicAltFallback,
    fontSize: size,
    color: color,
    letterSpacing: 1.4,
  );

  static TextStyle script({double size = 30, Color color = white}) => TextStyle(
    fontFamily: fontScript,
    fontFamilyFallback: _scriptFallback,
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
      filterQuality: .low,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
