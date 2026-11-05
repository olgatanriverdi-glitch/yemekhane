import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Reklam (Google AdMob) ayarları ve saf kurallar: birim kimliği seçimi, yeni kullanıcı bekleme süresi, görünüm.
// Hiçbir şey platform kanalına dokunmaz; testlerde olduğu gibi çağrılabilir.

/// Derleme sırasında verilen Android yerel reklam birimi: `--dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-.../...`.
const String admobNativeAndroid =
    String.fromEnvironment('ADMOB_NATIVE_ANDROID');

/// Derleme sırasında verilen iOS yerel reklam birimi: `--dart-define=ADMOB_NATIVE_IOS=ca-app-pub-.../...`.
const String admobNativeIos = String.fromEnvironment('ADMOB_NATIVE_IOS');

/// Google'ın herkese açık TEST yerel reklam birimleri (yalnızca debug / profile derlemede kullanılır).
const String testBirimAndroid = 'ca-app-pub-3940256099942544/2247696110';
const String testBirimIos = 'ca-app-pub-3940256099942544/3986624511';

/// Aynı gün ve öğünde reklam isteği atmadan önce beklenen süre (gün / öğün gezerken istek gitmesin).
const Duration reklamBeklemesi = Duration(seconds: 2);

/// Bir oturumda (uygulama açıkken) atılabilecek en çok reklam yüklemesi; sonrası eldekiler yeniden kullanılır.
const int oturumYuklemeSiniri = 10;

/// Bellekte tutulan en çok reklam (gün + öğün başına bir tane); fazlası atılır ve serbest bırakılır.
const int reklamOnbellekSiniri = 3;

/// Yüklenmiş bir reklam bu süreden sonra bayat sayılır (AdMob yerel reklamları bir saat sonra geçersiz kılar).
const Duration reklamOmru = Duration(minutes: 55);

/// Yüklenemeyen bir gün + öğün için bu süre boyunca yeniden denenmez.
const Duration reklamHataBeklemesi = Duration(minutes: 3);

/// İlk açılıştan sonra reklam gösterilmeyen gün sayısı (ilk açılış günü dahil değil): ilk gün + 3 gün reklamsız,
/// reklam dördüncü günden sonra başlar.
const int reklamsizGunSayisi = 3;

/// İlk açılış tarihinin ('yyyy-MM-dd') saklandığı anahtar.
const String ilkAcilisAnahtari = 'reklam_ilk_acilis';

/// Reklam birimi kimliğini seçer; `null` reklamın tamamen kapalı olduğu anlamına gelir.
///
/// - [tanimli] (dart-define ile verilen gerçek kimlik) doluysa her derlemede o kullanılır.
/// - Boşsa: yalnızca debug / profile derlemede ([surum] false) Google'ın test birimi; RELEASE derlemede `null`
///   (SDK başlatılmaz, istek atılmaz). Yani gerçek kimlik verilmeden alınan release'te test reklamı asla çıkmaz.
/// - Web ve Android / iOS dışındaki platformlarda her zaman `null`.
String? reklamBirimiSec(
    {required String androidTanimli,
    required String iosTanimli,
    required bool web,
    required TargetPlatform platform,
    required bool surum}) {
  if (web) return null;
  final String tanimli;
  final String test;
  switch (platform) {
    case TargetPlatform.android:
      tanimli = androidTanimli.trim();
      test = testBirimAndroid;
    case TargetPlatform.iOS:
      tanimli = iosTanimli.trim();
      test = testBirimIos;
    default:
      return null;
  }
  if (tanimli.isNotEmpty) return tanimli;
  return surum ? null : test;
}

/// Bu derleme için reklam birimi (dart-define'lar, çalışma ortamı ve derleme türü ile).
String? gecerliReklamBirimi() => reklamBirimiSec(
    androidTanimli: admobNativeAndroid,
    iosTanimli: admobNativeIos,
    web: kIsWeb,
    platform: defaultTargetPlatform,
    surum: kReleaseMode);

final RegExp _tarihBicimi = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// 'yyyy-MM-dd' metnini gün olarak çözer; bozuk metin, geçersiz gün ya da metin olmayan değer için `null`.
DateTime? _gunCoz(Object? kayit) {
  if (kayit is! String || !_tarihBicimi.hasMatch(kayit)) return null;
  final p = kayit.split('-').map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2]);
  // 2026-02-31 gibi taşan günler reddedilir
  if (d.year != p[0] || d.month != p[1] || d.day != p[2]) return null;
  return d;
}

/// Kayıtlı ilk açılış günü geçerli mi (çözülebilir ve gelecekte değil)?
bool ilkAcilisKaydiGecerli(Object? kayit, DateTime simdi) {
  final g = _gunCoz(kayit);
  if (g == null) return false;
  return !g.isAfter(DateTime.utc(simdi.year, simdi.month, simdi.day));
}

/// Yeni kullanıcıya nezaket süresi bitti mi? [kayit] ilk açılış günü ('yyyy-MM-dd'); [simdi] Türkiye duvar saati.
/// Gün farkı [reklamsizGunSayisi]'ndan büyükse (yani dördüncü günden itibaren) true. Eksik, bozuk ya da gelecekteki
/// kayıt için false (çağıran kaydı yeniden yazar).
bool reklamsizSureBitti(Object? kayit, DateTime simdi) {
  if (!ilkAcilisKaydiGecerli(kayit, simdi)) return false;
  final fark = DateTime.utc(simdi.year, simdi.month, simdi.day)
      .difference(_gunCoz(kayit)!)
      .inDays;
  return fark > reklamsizGunSayisi;
}

/// Reklam kartının renkleri: etkin temanın colorScheme'inden türetilir (palet ve açık / koyu / siyah mod ile uyumlu).
/// Yerel şablon yüklenirken bu değerler kullanıldığından tema değişince reklam yeniden yüklenir; [imza] önbellek
/// anahtarının bir parçasıdır.
@immutable
class ReklamStili {
  final Color arkaPlan, birincilYazi, ikincilYazi, dugme, dugmeYazisi;
  final double kose;
  const ReklamStili(
      {required this.arkaPlan,
      required this.birincilYazi,
      required this.ikincilYazi,
      required this.dugme,
      required this.dugmeYazisi,
      this.kose = 16});

  /// Kart zemini (Card'ın kendi rengi) ve yazı renkleri aktif temadan.
  factory ReklamStili.temadan(ThemeData tema) {
    final r = tema.colorScheme;
    return ReklamStili(
        arkaPlan: tema.cardTheme.color ?? r.surfaceContainerLow,
        birincilYazi: r.onSurface,
        ikincilYazi: r.onSurfaceVariant,
        dugme: r.primary,
        dugmeYazisi: r.onPrimary);
  }

  String get imza =>
      '${arkaPlan.toARGB32()}.${birincilYazi.toARGB32()}.${ikincilYazi.toARGB32()}.${dugme.toARGB32()}.${dugmeYazisi.toARGB32()}.$kose';

  @override
  bool operator ==(Object other) => other is ReklamStili && other.imza == imza;

  @override
  int get hashCode => imza.hashCode;
}
