import 'reklam_ayari.dart';

/// Reklam yerleşimlerinin kimlikleri (uzaktan ayarda ve anahtarlarda kullanılır).
const String yerlesimAna = 'ana';
const String yerlesimHafta = 'hafta';
const String yerlesimArama = 'arama';
const String yerlesimDetay = 'detay';
const List<String> reklamYerlesimleri = [
  yerlesimAna,
  yerlesimHafta,
  yerlesimArama,
  yerlesimDetay
];

/// Geçerli reklam içerik dereceleri ve varsayılan (en sıkı olan).
const List<String> reklamIcerikDereceleri = ['G', 'PG', 'T'];
const String varsayilanIcerikDerecesi = 'G';

/// Uzaktan reklam ayarı (`ayarlar.json` içindeki "reklam" nesnesi): uygulama güncellemesi yayınlamadan reklamları
/// kapatıp açmaya, yerleşim seçmeye yarar. Bozuk, eksik ya da türü yanlış her alan varsayılana düşer; bu sınıf
/// asla hata atmaz.
class UzakReklamAyari {
  final bool aktif;

  /// İlk açılıştan sonra reklamsız geçen gün sayısı (0..30).
  final int lutufGun;

  /// Oturumda en çok reklam yükleme sayısı (0..200).
  final int oturumSiniri;
  final Map<String, bool> yerlesimler;

  /// Ana ekranda uzun ekranda görselli (medium) reklam kullanılsın mı?
  final bool anaBuyuk;

  /// "Reklamsız gün" (ödüllü reklam) özelliği açık mı?
  final bool odullu;

  /// İstenen reklamların en yüksek içerik derecesi: 'G' (herkes, PEGI 3 hedefi; varsayılan), 'PG' ya da 'T'.
  /// Play Console'daki gerçek içerik derecelendirmesi (IARC) farklı çıkarsa uygulama güncellemesi olmadan değiştirilir.
  final String maxIcerik;
  const UzakReklamAyari(
      {this.aktif = true,
      this.lutufGun = reklamsizGunSayisi,
      this.oturumSiniri = oturumYuklemeSiniri,
      this.yerlesimler = const {},
      this.anaBuyuk = true,
      this.odullu = true,
      this.maxIcerik = varsayilanIcerikDerecesi});

  /// Güvenli varsayılan: her şey açık, 2 gün lütuf, oturumda 20 yükleme.
  static const UzakReklamAyari varsayilan = UzakReklamAyari();

  /// [yer] yerleşimi açık mı? Belirtilmemişse açık.
  bool yerlesimAcik(String yer) => yerlesimler[yer] ?? true;

  static bool _mantik(Object? v, bool varsayilan) => v is bool ? v : varsayilan;

  static String _derece(Object? v) {
    if (v is String) {
      final b = v.trim().toUpperCase();
      if (reklamIcerikDereceleri.contains(b)) return b;
    }
    return varsayilanIcerikDerecesi;
  }

  static int _tamsayi(Object? v, int varsayilan, int en, int cok) {
    if (v is int && v >= en && v <= cok) return v;
    // 2.0 gibi tam sayı değerli ondalıklar da kabul edilir
    if (v is double && v == v.truncateToDouble() && v >= en && v <= cok) {
      return v.toInt();
    }
    return varsayilan;
  }

  /// `ayarlar.json` kökünden ya da doğrudan "reklam" nesnesinden ayrıştırır. Kök haritada "reklam" anahtarı varsa
  /// onu kullanır; hiçbiri uygun değilse [varsayilan].
  factory UzakReklamAyari.fromJson(Object? j) {
    try {
      final kok = j is Map ? j : null;
      if (kok == null) return varsayilan;
      final r = kok.containsKey('reklam') ? kok['reklam'] : kok;
      if (r is! Map) return varsayilan;
      final ham = r['yerlesimler'];
      final yer = <String, bool>{};
      if (ham is Map) {
        for (final k in reklamYerlesimleri) {
          final v = ham[k];
          if (v is bool) yer[k] = v;
        }
      }
      return UzakReklamAyari(
          aktif: _mantik(r['aktif'], true),
          lutufGun: _tamsayi(r['lutufGun'], reklamsizGunSayisi, 0, 30),
          oturumSiniri:
              _tamsayi(r['oturumSiniri'], oturumYuklemeSiniri, 0, 200),
          yerlesimler: Map.unmodifiable(yer),
          anaBuyuk: _mantik(r['anaBuyuk'], true),
          odullu: _mantik(r['odullu'], true),
          maxIcerik: _derece(r['maxIcerik']));
    } catch (_) {
      return varsayilan;
    }
  }
}
