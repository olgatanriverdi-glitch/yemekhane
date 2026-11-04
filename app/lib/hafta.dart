import 'config.dart';
import 'models.dart';

/// Haftalık görünümde bir gün kartının durumu.
enum HaftaDurumu {
  /// Seçili öğünde yemek var.
  menu,

  /// O gün hiçbir öğünde yemek yok (tatil): okul yemek vermiyor.
  tatil,

  /// O gün başka öğünler var ama seçili öğün yok.
  ogunYok,

  /// Menü verisi yok ve gün hafta sonu: hizmet verilmiyor.
  hizmetYok,

  /// Menü verisi yok ve gün hafta içi: okul menüyü yayınlamamış.
  yayinlanmadi,
}

/// Haftalık görünümde (ve haftalık paylaşım metninde) bir günün seçili öğün için özeti.
class HaftaGunu {
  final String tarih; // 'yyyy-MM-dd'
  final HaftaDurumu durum;

  /// Yalnızca [HaftaDurumu.menu]: öğünün yemekleri (menüdeki sırayla).
  final List<YemekOgesi> yemekler;

  /// Yalnızca [HaftaDurumu.menu]: öğünün toplam kalorisi (bilinmiyorsa null).
  final int? kcal;

  /// Tatil / öğün notu ("Tatil", "29 Ekim Cumhuriyet Bayramı"); yoksa null.
  final String? not;
  const HaftaGunu(this.tarih, this.durum,
      {this.yemekler = const [], this.kcal, this.not});

  /// Okuldan o gün için herhangi bir veri (menü, tatil notu...) gelmiş mi?
  bool get veriVar =>
      durum != HaftaDurumu.hizmetYok && durum != HaftaDurumu.yayinlanmadi;

  /// Menü yokken kartta ve paylaşım metninde yazan kısa açıklama (menü varsa boş).
  String get mesaj => switch (durum) {
        HaftaDurumu.menu => '',
        HaftaDurumu.tatil => not ?? 'Hizmet yok',
        HaftaDurumu.ogunYok => not ?? 'Bu öğün için menü yok',
        HaftaDurumu.hizmetYok => 'Hizmet yok',
        HaftaDurumu.yayinlanmadi => 'Menü yayınlanmadı',
      };
}

/// Not metnini kırpar; boş / yalnızca boşluktan oluşan not yok sayılır (null).
String? temizNot(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

/// 'yyyy-MM-dd' tarihe [gun] gün ekler (negatif de olabilir); ay / yıl sonları takvime göre geçilir.
/// Tarih bozuksa olduğu gibi döner.
String tarihEkle(String tarih, int gun) {
  final d = DateTime.tryParse(tarih);
  if (d == null) return tarih;
  return isoTarih(DateTime.utc(d.year, d.month, d.day + gun));
}

/// [tarih]in içinde bulunduğu haftanın pazartesisi (hafta pazartesi başlar). Pazartesi kendisidir.
String haftaBaslangici(String tarih) {
  final d = DateTime.tryParse(tarih);
  if (d == null) return tarih;
  return isoTarih(DateTime.utc(d.year, d.month, d.day - (d.weekday - 1)));
}

/// [pazartesi] ile başlayan haftanın 7 günü.
List<String> haftaTarihleri(String pazartesi) =>
    DateTime.tryParse(pazartesi) == null
        ? const []
        : [for (var i = 0; i < 7; i++) tarihEkle(pazartesi, i)];

/// "Cuma 2 Ekim" (gün adı, gün, ay).
String gunTarihEtiketi(String tarih) {
  final d = DateTime.tryParse(tarih);
  if (d == null) return tarih;
  return '${gunAdlari[d.weekday - 1]} ${d.day} ${ayAdlari[d.month - 1]}';
}

/// Haftanın tarih aralığı: aynı ayda "2 – 8 Kasım", ay aşıyorsa "26 Ekim – 1 Kasım".
String haftaAraligi(String pazartesi) {
  final b = DateTime.tryParse(pazartesi);
  if (b == null) return pazartesi;
  final s = DateTime.utc(b.year, b.month, b.day + 6);
  final bas =
      b.month == s.month ? '${b.day}' : '${b.day} ${ayAdlari[b.month - 1]}';
  return '$bas – ${s.day} ${ayAdlari[s.month - 1]}';
}

/// [pazartesi] haftasından önce menüde bir gün var mı? (Önceki hafta oku buna bakar.)
bool oncekiHaftaVar(Menu menu, String pazartesi) {
  final t = menu.tarihler;
  return t.isNotEmpty && t.first.compareTo(pazartesi) < 0;
}

/// [pazartesi] haftasından sonra menüde bir gün var mı? (Sonraki hafta oku buna bakar.)
bool sonrakiHaftaVar(Menu menu, String pazartesi) {
  final t = menu.tarihler;
  return t.isNotEmpty && t.last.compareTo(tarihEkle(pazartesi, 6)) > 0;
}

HaftaGunu _gunOzeti(Menu menu, String tarih, String ogun) {
  final d = DateTime.parse(tarih);
  final gun = menu.gunler[tarih];
  if (gun == null || gun.isEmpty) {
    return HaftaGunu(tarih,
        d.weekday >= 6 ? HaftaDurumu.hizmetYok : HaftaDurumu.yayinlanmadi);
  }
  final o = gun[ogun];
  if (o != null && !o.bos) {
    return HaftaGunu(tarih, HaftaDurumu.menu,
        yemekler: o.ogeler,
        kcal: o.kcal != null && o.kcal! > 0 ? o.kcal : null,
        not: temizNot(o.not));
  }
  // ana ekrandaki gibi: hiçbir öğünde yemek yoksa herhangi bir öğünün notu, yoksa yalnızca seçili öğünün notu
  if (gun.values.every((x) => x.bos)) {
    final not =
        gun.values.map((x) => temizNot(x.not)).whereType<String>().firstOrNull;
    return HaftaGunu(tarih, HaftaDurumu.tatil, not: not);
  }
  return HaftaGunu(tarih, HaftaDurumu.ogunYok, not: temizNot(o?.not));
}

/// [pazartesi] haftasının 7 günü için seçili [ogun] özeti (menüsü olmayan günler dahil).
List<HaftaGunu> haftaGunleri(Menu menu, String pazartesi, String ogun) => [
      for (final t in haftaTarihleri(pazartesi)) _gunOzeti(menu, t, ogun),
    ];

/// Kartta gösterilecek yemekler ve gizli kalanların sayısı: ilk [sinir] yemek; favoriler [sinir]den sonra
/// olsa da gösterilir (kalbin görünmeden "+N"de kaybolmaması için). Adı boş öğeler sayılmaz.
({List<YemekOgesi> gorunen, int gizli}) haftaYemekleri(
    List<YemekOgesi> ogeler, Set<String> favoriler,
    {int sinir = 4}) {
  final adli = [
    for (final o in ogeler)
      if (o.ad.trim().isNotEmpty) o
  ];
  final gorunen = [
    for (var i = 0; i < adli.length; i++)
      if (i < sinir ||
          (adli[i].anahtar != null && favoriler.contains(adli[i].anahtar)))
        adli[i]
  ];
  return (gorunen: gorunen, gizli: adli.length - gorunen.length);
}
