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
  // Temel marka tonu ve doygunluğu uygulama ikonu ile ortak kalır.
  TemaRengi('safran', 'Safran',
      ton: 28,
      doygunluk: 0.88,
      ikinciTon: 30,
      ucuncuTon: 88,
      yuzeyTon: 34,
      yuzeyDoygunluk: 0.30),
  TemaRengi('domates', 'Domates',
      ton: 7,
      doygunluk: 0.70,
      ikinciTon: 20,
      ucuncuTon: 146,
      yuzeyTon: 18,
      yuzeyDoygunluk: 0.16),
  TemaRengi('gul', 'Gül',
      ton: 342,
      doygunluk: 0.58,
      ikinciTon: 355,
      ucuncuTon: 282,
      yuzeyTon: 342,
      yuzeyDoygunluk: 0.12),
  TemaRengi('lavanta', 'Lavanta',
      ton: 260,
      doygunluk: 0.52,
      ikinciTon: 278,
      ucuncuTon: 333,
      yuzeyTon: 264,
      yuzeyDoygunluk: 0.14),
  TemaRengi('gece', 'Gece Mavisi',
      ton: 224,
      doygunluk: 0.66,
      ikinciTon: 215,
      ucuncuTon: 168,
      yuzeyTon: 224,
      yuzeyDoygunluk: 0.18),
  TemaRengi('deniz', 'Deniz',
      ton: 177,
      doygunluk: 0.67,
      ikinciTon: 194,
      ucuncuTon: 32,
      yuzeyTon: 184,
      yuzeyDoygunluk: 0.14),
  TemaRengi('zeytin', 'Zeytin',
      ton: 91,
      doygunluk: 0.40,
      ikinciTon: 73,
      ucuncuTon: 32,
      yuzeyTon: 86,
      yuzeyDoygunluk: 0.14),
  TemaRengi('grafit', 'Grafit',
      ton: 218,
      doygunluk: 0.08,
      ikinciTon: 218,
      ucuncuTon: 32,
      yuzeyTon: 218,
      yuzeyDoygunluk: 0.04),
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
Color _uzlastir(double h, double s, double l, Color zemin,
    {double enAz = 4.8}) {
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
    final ust = _hsl(h, 0.12, 0.995);
    final kap = _hsl(h, s * 0.72, 0.93);
    // Vurgu, en koyu açık yüzeyde de küçük metin için AA kalsın.
    return _Aile(_uzlastir(h, s, 0.45, ust, enAz: 5.8), ust, kap,
        _uzlastir(h, s * 0.65, 0.23, kap, enAz: 7));
  }
  final ust = _hsl(h, s * 0.45, 0.12);
  final kap = _hsl(h, s * 0.32, 0.22);
  return _Aile(_uzlastir(h, s * 0.82, 0.76, ust, enAz: 7), ust, kap,
      _uzlastir(h, s * 0.5, 0.91, kap, enAz: 7));
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

  // Yalnızca ana zemin paletin tam yüzey tonunu taşır. Diğer yüzeylerde ve
  // metinde azaltılmış doygunluk, özellikle koyu modda renk yığılmasını önler.
  Color yuzey(double l, [double carpan = 0.32]) => _hsl(h, ys * carpan, l);

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
    // Safran'ın açılış yüzeyi web / yerel açılış ekranıyla aynı kalır.
    zemin = yuzey(0.950, 1);
    enAlcak = yuzey(0.998, 0.15);
    alcak = yuzey(0.992, 0.18);
    orta = yuzey(0.970);
    yuksek = yuzey(0.944);
    enYuksek = yuzey(0.920);
    dim = yuzey(0.900);
    bright = yuzey(0.992, 0.18);
    yazi = yuzey(0.125, 0.38);
    yaziVaryant = yuzey(0.350, 0.22);
    cerceve = yuzey(0.490, 0.25);
    cerceveVaryant = yuzey(0.840, 0.30);
    tersYuzey = yuzey(0.160);
    tersYazi = yuzey(0.970, 0.2);
  } else if (amoled) {
    zemin = const Color(0xFF000000);
    enAlcak = const Color(0xFF000000);
    alcak = yuzey(0.070);
    orta = yuzey(0.100);
    yuksek = yuzey(0.135);
    enYuksek = yuzey(0.175);
    dim = const Color(0xFF000000);
    bright = yuzey(0.210);
    yazi = yuzey(0.940, 0.20);
    yaziVaryant = yuzey(0.770, 0.15);
    cerceve = yuzey(0.560, 0.20);
    cerceveVaryant = yuzey(0.260);
    tersYuzey = yuzey(0.920, 0.20);
    tersYazi = yuzey(0.140);
  } else {
    zemin = yuzey(0.085, 1);
    enAlcak = yuzey(0.060);
    alcak = yuzey(0.125);
    orta = yuzey(0.150);
    yuksek = yuzey(0.180);
    enYuksek = yuzey(0.215);
    dim = yuzey(0.065);
    bright = yuzey(0.240);
    yazi = yuzey(0.940, 0.20);
    yaziVaryant = yuzey(0.770, 0.15);
    cerceve = yuzey(0.590, 0.20);
    cerceveVaryant = yuzey(0.310);
    tersYuzey = yuzey(0.920, 0.20);
    tersYazi = yuzey(0.140);
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
    inversePrimary:
        _uzlastir(p.ton, p.doygunluk, acik ? 0.70 : 0.46, tersYuzey),
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

  TemaAyari(
      {ThemeMode mod = ThemeMode.system, TemaRengi? renk, bool siyah = false})
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
ThemeData temaUret(TemaRengi palet, Brightness parlaklik,
    {bool amoled = false}) {
  final r = renkSemasiUret(palet, parlaklik, amoled: amoled);
  final koyu = parlaklik == Brightness.dark;
  final taban = ThemeData(
    useMaterial3: true,
    colorScheme: r,
    brightness: parlaklik,
    fontFamily: 'Manrope',
  );
  final t =
      taban.textTheme.apply(bodyColor: r.onSurface, displayColor: r.onSurface);
  final yazi = t.copyWith(
    headlineLarge: t.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.18),
    headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.20),
    headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.25),
    titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.30),
    titleMedium: t.titleMedium?.copyWith(
        fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.35),
    titleSmall: t.titleSmall
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.35),
    bodyLarge: t.bodyLarge?.copyWith(letterSpacing: 0, height: 1.50),
    bodyMedium: t.bodyMedium?.copyWith(letterSpacing: 0, height: 1.45),
    bodySmall: t.bodySmall?.copyWith(letterSpacing: 0.1, height: 1.45),
    labelLarge: t.labelLarge
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0, height: 1.35),
    labelMedium: t.labelMedium?.copyWith(
        fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.35),
    labelSmall: t.labelSmall?.copyWith(
        fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.35),
  );
  final dugmeSekli =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  final alanSekli =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final alanKenari = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: r.outline));
  const hedef = Size(48, 48);
  const dugmeDolgusu = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

  return taban.copyWith(
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: r.surface,
    textTheme: yazi,
    iconTheme: IconThemeData(color: r.onSurfaceVariant, size: 24),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: r.surface,
      surfaceTintColor: r.surfaceTint,
      foregroundColor: r.onSurface,
      titleTextStyle: yazi.titleLarge?.copyWith(fontSize: 20),
      iconTheme: IconThemeData(color: r.onSurface, size: 24),
      actionsIconTheme: IconThemeData(color: r.onSurface, size: 24),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: r.surfaceTint,
        statusBarIconBrightness: koyu ? Brightness.light : Brightness.dark,
        statusBarBrightness: koyu ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: r.surface,
        systemNavigationBarDividerColor: r.surfaceTint,
        systemNavigationBarIconBrightness:
            koyu ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: r.surfaceContainerLow,
      surfaceTintColor: r.surfaceTint,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: r.outlineVariant.withValues(alpha: koyu ? 0.7 : 0.5))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: r.surfaceContainerHigh,
      selectedColor: r.primaryContainer,
      secondarySelectedColor: r.primaryContainer,
      checkmarkColor: r.onPrimaryContainer,
      disabledColor: r.onSurface.withValues(alpha: 0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      labelStyle:
          yazi.labelMedium?.copyWith(color: r.onSurfaceVariant, fontSize: 13),
      secondaryLabelStyle:
          yazi.labelMedium?.copyWith(color: r.onPrimaryContainer, fontSize: 13),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconColor: r.onSurfaceVariant,
      textColor: r.onSurface,
      selectedColor: r.primary,
      selectedTileColor: r.primaryContainer,
      titleTextStyle: yazi.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      subtitleTextStyle: yazi.bodyMedium?.copyWith(color: r.onSurfaceVariant),
      horizontalTitleGap: 14,
      minVerticalPadding: 10,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: dugmeSekli,
        minimumSize: hedef,
        padding: dugmeDolgusu,
        textStyle: yazi.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: dugmeSekli,
        minimumSize: hedef,
        padding: dugmeDolgusu,
        textStyle: yazi.labelLarge,
        backgroundColor: r.surfaceContainerLow,
        foregroundColor: r.primary,
        surfaceTintColor: r.surfaceTint,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: dugmeSekli,
        minimumSize: hedef,
        padding: dugmeDolgusu,
        textStyle: yazi.labelLarge,
        side: BorderSide(color: r.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: dugmeSekli,
        minimumSize: hedef,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: yazi.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: dugmeSekli, minimumSize: hedef),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: dugmeSekli,
        minimumSize: hedef,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: yazi.labelLarge,
        side: BorderSide(color: r.outlineVariant),
        backgroundColor: r.surfaceContainerLow,
        foregroundColor: r.onSurfaceVariant,
        selectedBackgroundColor: r.primary,
        selectedForegroundColor: r.onPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: r.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: alanKenari,
      enabledBorder: alanKenari,
      focusedBorder: alanKenari.copyWith(
          borderSide: BorderSide(color: r.primary, width: 2)),
      errorBorder: alanKenari.copyWith(borderSide: BorderSide(color: r.error)),
      focusedErrorBorder:
          alanKenari.copyWith(borderSide: BorderSide(color: r.error, width: 2)),
      disabledBorder:
          alanKenari.copyWith(borderSide: BorderSide(color: r.outlineVariant)),
      labelStyle: yazi.bodyLarge?.copyWith(color: r.onSurfaceVariant),
      hintStyle: yazi.bodyLarge?.copyWith(color: r.onSurfaceVariant),
      helperStyle: yazi.bodySmall?.copyWith(color: r.onSurfaceVariant),
      errorStyle: yazi.bodySmall?.copyWith(color: r.error),
      prefixIconColor: r.onSurfaceVariant,
      suffixIconColor: r.onSurfaceVariant,
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(r.surfaceContainerLow),
      surfaceTintColor: WidgetStatePropertyAll(r.surfaceTint),
      shape: WidgetStatePropertyAll(alanSekli),
      side: WidgetStateProperty.resolveWith((s) => BorderSide(
          color: s.contains(WidgetState.focused) ? r.primary : r.outline,
          width: s.contains(WidgetState.focused) ? 2 : 1)),
      textStyle: WidgetStatePropertyAll(yazi.bodyLarge),
      hintStyle: WidgetStatePropertyAll(
          yazi.bodyLarge?.copyWith(color: r.onSurfaceVariant)),
      padding:
          const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      constraints: const BoxConstraints(minHeight: 56),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: r.primary,
      selectionColor: r.primary.withValues(alpha: 0.22),
      selectionHandleColor: r.primary,
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      thumbColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) {
          return r.onSurface.withValues(alpha: 0.38);
        }
        return s.contains(WidgetState.selected) ? r.onPrimary : r.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) {
          return r.onSurface.withValues(alpha: 0.08);
        }
        return s.contains(WidgetState.selected)
            ? r.primary
            : r.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return r.outlineVariant;
        return s.contains(WidgetState.selected) ? r.primary : r.outline;
      }),
      trackOutlineWidth: const WidgetStatePropertyAll(1.5),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: r.primary,
      inactiveTrackColor: r.surfaceContainerHighest,
      thumbColor: r.primary,
      overlayColor: r.primary.withValues(alpha: 0.12),
      valueIndicatorColor: r.inverseSurface,
      valueIndicatorTextStyle:
          yazi.labelMedium?.copyWith(color: r.onInverseSurface),
      trackHeight: 4,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: r.primary,
      linearTrackColor: r.primaryContainer,
      circularTrackColor: r.surfaceContainerHighest,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: r.surfaceContainerLow,
      modalBackgroundColor: r.surfaceContainerLow,
      surfaceTintColor: r.surfaceTint,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: r.outline,
      dragHandleSize: const Size(36, 4),
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: r.outlineVariant.withValues(alpha: 0.6))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: r.surfaceContainerLow,
      surfaceTintColor: r.surfaceTint,
      elevation: 0,
      titleTextStyle: yazi.titleLarge,
      contentTextStyle: yazi.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: r.surfaceContainerLow,
      surfaceTintColor: r.surfaceTint,
      elevation: 3,
      shadowColor: r.shadow.withValues(alpha: 0.15),
      textStyle: yazi.bodyMedium,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: r.outlineVariant)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: r.inverseSurface,
      contentTextStyle: yazi.bodyMedium?.copyWith(color: r.onInverseSurface),
      actionTextColor: r.inversePrimary,
      disabledActionTextColor: r.onInverseSurface.withValues(alpha: 0.38),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: yazi.bodySmall?.copyWith(color: r.onInverseSurface),
      decoration: BoxDecoration(
          color: r.inverseSurface, borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: DividerThemeData(
        color: r.outlineVariant.withValues(alpha: 0.6), space: 1, thickness: 1),
  );
}
