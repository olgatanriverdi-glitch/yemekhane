import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Elle ayarlanmış, isimli palet. Renk tonları (hue) ve doygunluklar verilir; açık/koyu modun tüm
/// tonları (vurgu, kap, yüzey seviyeleri) buradan, kontrastı AA (>= 4.5) olacak biçimde üretilir.
class TemaRengi {
  final String kimlik;
  final String ad;
  final double ton; // birincil vurgu tonu (0-360)
  final double doygunluk; // birincil vurgu doygunluğu (0-1)
  final double ikinciTon;
  final double ucuncuTon;
  final double yuzeyTon;
  final double yuzeyDoygunluk;
  const TemaRengi(
    this.kimlik,
    this.ad, {
    required this.ton,
    required this.doygunluk,
    required this.ikinciTon,
    required this.ucuncuTon,
    required this.yuzeyTon,
    required this.yuzeyDoygunluk,
  });

  /// Örnek renk (seçicide ve önizlemede görünen vurgu): açık moddaki birincil renk.
  Color get renk => renkSemasiUret(this, Brightness.light).primary;
}

/// İlk palet varsayılandır. Eski kayıtlı kimlikler (turuncu, kirmizi, ...) _eskiKimlikler ile eşlenir.
const List<TemaRengi> temaRenkleri = [
  TemaRengi('safran', 'Safran',
      ton: 28, doygunluk: 0.88, ikinciTon: 38, ucuncuTon: 95, yuzeyTon: 34, yuzeyDoygunluk: 0.30),
  TemaRengi('domates', 'Domates',
      ton: 5, doygunluk: 0.72, ikinciTon: 18, ucuncuTon: 140, yuzeyTon: 8, yuzeyDoygunluk: 0.22),
  TemaRengi('gul', 'Gül',
      ton: 338, doygunluk: 0.62, ikinciTon: 350, ucuncuTon: 270, yuzeyTon: 340, yuzeyDoygunluk: 0.22),
  TemaRengi('lavanta', 'Lavanta',
      ton: 262, doygunluk: 0.55, ikinciTon: 272, ucuncuTon: 325, yuzeyTon: 266, yuzeyDoygunluk: 0.24),
  TemaRengi('gece', 'Gece Mavisi',
      ton: 220, doygunluk: 0.68, ikinciTon: 210, ucuncuTon: 172, yuzeyTon: 222, yuzeyDoygunluk: 0.26),
  TemaRengi('deniz', 'Deniz',
      ton: 180, doygunluk: 0.78, ikinciTon: 192, ucuncuTon: 28, yuzeyTon: 185, yuzeyDoygunluk: 0.24),
  TemaRengi('zeytin', 'Zeytin',
      ton: 100, doygunluk: 0.42, ikinciTon: 78, ucuncuTon: 38, yuzeyTon: 92, yuzeyDoygunluk: 0.20),
  TemaRengi('grafit', 'Grafit',
      ton: 220, doygunluk: 0.10, ikinciTon: 220, ucuncuTon: 28, yuzeyTon: 220, yuzeyDoygunluk: 0.06),
];

/// Sürümler arası uyumluluk: eski renk kimlikleri yeni paletlere gider.
const Map<String, String> _eskiKimlikler = {
  'turuncu': 'safran',
  'kirmizi': 'domates',
  'pembe': 'gul',
  'mor': 'lavanta',
  'mavi': 'gece',
  'turkuaz': 'deniz',
  'yesil': 'zeytin',
};

TemaRengi temaRengiBul(String? kimlik) {
  final k = _eskiKimlikler[kimlik] ?? kimlik;
  return temaRenkleri.firstWhere((r) => r.kimlik == k,
      orElse: () => temaRenkleri.first);
}

Color _hsl(double h, double s, double l) =>
    HSLColor.fromAHSL(1, h % 360, s.clamp(0.0, 1.0), l.clamp(0.0, 1.0))
        .toColor();

/// WCAG kontrast oranı (1-21).
double kontrastOrani(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final acik = la > lb ? la : lb, koyu = la > lb ? lb : la;
  return (acik + 0.05) / (koyu + 0.05);
}

/// Verilen tonu, zeminle en az [enAz] kontrasta ulaşana dek zeminden uzaklaştırır.
Color _uzlastir(double h, double s, double l, Color zemin, {double enAz = 4.8}) {
  final acilsin = zemin.computeLuminance() < 0.4;
  var renk = _hsl(h, s, l);
  for (var i = 0; i < 100 && kontrastOrani(renk, zemin) < enAz; i++) {
    l += acilsin ? 0.01 : -0.01;
    renk = _hsl(h, s, l);
  }
  return renk;
}

/// Bir vurgu ailesi: ana renk, üstündeki yazı, kap rengi ve kabın üstündeki yazı.
class _Aile {
  final Color ana, ustuAna, kap, ustuKap;
  const _Aile(this.ana, this.ustuAna, this.kap, this.ustuKap);
}

_Aile _aile(double h, double s, bool acik) {
  if (acik) {
    final ust = _hsl(h, 0.25, 0.99);
    // 5.1: vurgu rengi en açık zeminde (0.99) değil, diyalog / menü zemininde (surfaceContainerHigh) da >= 4.5 kalsın
    return _Aile(_uzlastir(h, s, 0.46, ust, enAz: 5.1), ust,
        _hsl(h, s * 0.85, 0.89), _hsl(h, s, 0.15));
  }
  final ust = _hsl(h, s * 0.6, 0.10);
  return _Aile(_uzlastir(h, s, 0.70, ust), ust, _hsl(h, s * 0.55, 0.25),
      _hsl(h, s * 0.8, 0.90));
}

/// Paletin açık/koyu (isteğe bağlı saf siyah zeminli) renk şemasını üretir.
ColorScheme renkSemasiUret(TemaRengi p, Brightness parlaklik,
    {bool amoled = false}) {
  final acik = parlaklik == Brightness.light;
  final b = _aile(p.ton, p.doygunluk, acik);
  final i = _aile(p.ikinciTon, p.doygunluk * 0.40, acik);
  final u = _aile(p.ucuncuTon, p.doygunluk * 0.70, acik);
  final h = p.yuzeyTon, ys = p.yuzeyDoygunluk;
  final hata = _aile(4, 0.70, acik);

  Color yuzey(double l, [double carpan = 1]) => _hsl(h, ys * carpan, l);

  late final Color zemin,
      enAlcak,
      alcak,
      orta,
      yuksek,
      enYuksek,
      dim,
      bright,
      yazi,
      yaziVaryant,
      cerceve,
      cerceveVaryant,
      tersYuzey,
      tersYazi;
  if (acik) {
    zemin = yuzey(0.950);
    enAlcak = yuzey(0.995, 0.5);
    alcak = yuzey(0.982, 0.7);
    orta = yuzey(0.965);
    yuksek = yuzey(0.940);
    enYuksek = yuzey(0.915);
    dim = yuzey(0.905);
    bright = yuzey(0.975, 0.7);
    yazi = yuzey(0.11, 1.2);
    yaziVaryant = yuzey(0.33, 1.0);
    cerceve = yuzey(0.48, 0.8);
    cerceveVaryant = yuzey(0.82);
    tersYuzey = yuzey(0.17, 1.2);
    tersYazi = yuzey(0.95);
  } else if (amoled) {
    zemin = const Color(0xFF000000);
    enAlcak = const Color(0xFF000000);
    alcak = yuzey(0.075, 0.8);
    orta = yuzey(0.095, 0.8);
    yuksek = yuzey(0.125, 0.8);
    enYuksek = yuzey(0.155, 0.8);
    dim = const Color(0xFF000000);
    bright = yuzey(0.18, 0.8);
    yazi = yuzey(0.93, 0.6);
    yaziVaryant = yuzey(0.74, 0.5);
    cerceve = yuzey(0.52, 0.5);
    cerceveVaryant = yuzey(0.22, 0.6);
    tersYuzey = yuzey(0.90, 0.5);
    tersYazi = yuzey(0.12);
  } else {
    zemin = yuzey(0.085);
    enAlcak = yuzey(0.060);
    alcak = yuzey(0.118);
    orta = yuzey(0.145);
    yuksek = yuzey(0.175);
    enYuksek = yuzey(0.205);
    dim = yuzey(0.070);
    bright = yuzey(0.230);
    yazi = yuzey(0.93, 0.8);
    yaziVaryant = yuzey(0.75, 0.7);
    cerceve = yuzey(0.55, 0.6);
    cerceveVaryant = yuzey(0.27, 0.8);
    tersYuzey = yuzey(0.90, 0.8);
    tersYazi = yuzey(0.13);
  }

  return ColorScheme(
    brightness: parlaklik,
    primary: b.ana,
    onPrimary: b.ustuAna,
    primaryContainer: b.kap,
    onPrimaryContainer: b.ustuKap,
    secondary: i.ana,
    onSecondary: i.ustuAna,
    secondaryContainer: i.kap,
    onSecondaryContainer: i.ustuKap,
    tertiary: u.ana,
    onTertiary: u.ustuAna,
    tertiaryContainer: u.kap,
    onTertiaryContainer: u.ustuKap,
    error: hata.ana,
    onError: hata.ustuAna,
    errorContainer: hata.kap,
    onErrorContainer: hata.ustuKap,
    surface: zemin,
    onSurface: yazi,
    onSurfaceVariant: yaziVaryant,
    surfaceDim: dim,
    surfaceBright: bright,
    surfaceContainerLowest: enAlcak,
    surfaceContainerLow: alcak,
    surfaceContainer: orta,
    surfaceContainerHigh: yuksek,
    surfaceContainerHighest: enYuksek,
    outline: cerceve,
    outlineVariant: cerceveVaryant,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: tersYuzey,
    onInverseSurface: tersYazi,
    // bildirim çubuğu eylem rengi (örn. "Geri al"): ters yüzeyle >= 4.5 olacak biçimde üretilir
    inversePrimary: _uzlastir(p.ton, p.doygunluk, acik ? 0.70 : 0.46, tersYuzey),
    surfaceTint: Colors.transparent,
  );
}

const Map<String, ThemeMode> _modlar = {
  'sistem': ThemeMode.system,
  'acik': ThemeMode.light,
  'koyu': ThemeMode.dark,
  'siyah': ThemeMode.dark, // koyu mod + saf siyah zemin
};

/// Kullanıcının görünüm seçimi: açık/koyu/sistem modu, isteğe bağlı siyah (AMOLED) zemin ve palet. Cihazda saklanır; değişince dinleyenler (MaterialApp) yenilenir.
class TemaAyari extends ChangeNotifier {
  static const modAnahtari = 'tema_mod';
  static const renkAnahtari = 'tema_renk';

  ThemeMode _mod;
  bool _siyah;
  TemaRengi _renk;

  TemaAyari({ThemeMode mod = ThemeMode.system, TemaRengi? renk, bool siyah = false})
      : _mod = mod,
        _siyah = siyah && mod == ThemeMode.dark,
        _renk = renk ?? temaRenkleri.first;

  ThemeMode get mod => _mod;

  /// Koyu modda saf siyah zemin (AMOLED) kullanılsın mı.
  bool get siyah => _siyah;
  TemaRengi get renk => _renk;

  /// Kayıtlı seçimi okur; hiç kayıt yoksa ya da değer tanınmıyorsa varsayılan (sistem modu, Safran) kalır.
  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      final mod = p.getString(modAnahtari);
      _mod = _modlar[mod] ?? ThemeMode.system;
      _siyah = mod == 'siyah';
      _renk = temaRengiBul(p.getString(renkAnahtari));
    } catch (_) {
      // saklama kullanılamıyorsa varsayılanla devam
    }
    notifyListeners();
  }

  /// Seçim hemen uygulanır; kaydetme arkadan gelir (kaydedilemese de görünüm değişir).
  Future<void> modSec(ThemeMode mod, {bool siyah = false}) async {
    siyah = siyah && mod == ThemeMode.dark;
    if (mod == _mod && siyah == _siyah) return;
    _mod = mod;
    _siyah = siyah;
    notifyListeners();
    await _kaydet(modAnahtari, siyah ? 'siyah' : _modAdi(mod));
  }

  static String _modAdi(ThemeMode mod) => switch (mod) {
        ThemeMode.system => 'sistem',
        ThemeMode.light => 'acik',
        ThemeMode.dark => 'koyu',
      };

  Future<void> renkSec(TemaRengi renk) async {
    if (renk.kimlik == _renk.kimlik) return;
    _renk = renk;
    notifyListeners();
    await _kaydet(renkAnahtari, renk.kimlik);
  }

  Future<void> _kaydet(String anahtar, String deger) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(anahtar, deger);
    } catch (_) {}
  }

  ThemeData tema(Brightness parlaklik) =>
      temaUret(_renk, parlaklik, amoled: _siyah);
}

/// Bir palet ve parlaklık için tüm uygulama temasını (renk, yazı, şekil, sistem çubukları) üretir.
ThemeData temaUret(TemaRengi palet, Brightness parlaklik, {bool amoled = false}) {
  final r = renkSemasiUret(palet, parlaklik, amoled: amoled);
  final koyu = parlaklik == Brightness.dark;
  final taban = ThemeData(
      useMaterial3: true, colorScheme: r, brightness: parlaklik);
  final t = taban.textTheme.apply(bodyColor: r.onSurface, displayColor: r.onSurface);
  final yazi = t.copyWith(
    headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
    headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
    headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: t.bodyMedium?.copyWith(height: 1.42),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1),
  );
  const tamYuvarlak = StadiumBorder();
  return taban.copyWith(
    visualDensity: VisualDensity.adaptivePlatformDensity,
    scaffoldBackgroundColor: r.surface,
    textTheme: yazi,
    appBarTheme: AppBarTheme(
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: r.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: r.onSurface,
      titleTextStyle: yazi.titleLarge?.copyWith(fontSize: 21),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: koyu ? Brightness.light : Brightness.dark,
        statusBarBrightness: koyu ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: r.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            koyu ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: r.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: r.outlineVariant.withValues(alpha: koyu ? 0.6 : 0.7))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: r.surfaceContainerHigh,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: yazi.labelMedium?.copyWith(color: r.onSurface, fontSize: 13),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: tamYuvarlak)),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: tamYuvarlak)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            shape: tamYuvarlak, side: BorderSide(color: r.outline))),
    textButtonTheme:
        TextButtonThemeData(style: TextButton.styleFrom(shape: tamYuvarlak)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: tamYuvarlak,
        side: BorderSide(color: r.outlineVariant),
        selectedBackgroundColor: r.primaryContainer,
        selectedForegroundColor: r.onPrimaryContainer,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: r.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: r.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
        color: r.outlineVariant.withValues(alpha: 0.6), space: 1),
  );
}
