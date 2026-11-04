// Günlük menü bildiriminin saf planlaması: ağ, disk ya da eklenti yok, emoji içermez.
import 'models.dart';
import 'widgets/ogun_bilgi.dart' show ogunAdlari;

/// Bildirimin varsayılan saati: 10:30 (gün başından itibaren dakika).
const varsayilanBildirimSaatDk = 10 * 60 + 30;

/// Bir seferde planlanan en çok gün sayısı (bugün dahil).
const bildirimEnCokGun = 7;

/// Gün başından itibaren dakikayı "10:30" yazar.
String bildirimSaatMetni(int dk) =>
    '${(dk ~/ 60).toString().padLeft(2, '0')}:${(dk % 60).toString().padLeft(2, '0')}';

/// Bir günün bildirimi için sabit kimlik: 2 Kasım 2026 -> 20261102. Aynı gün hep aynı kimliği alır; böylece
/// yeniden planlama eski bildirimin yerine geçer, ikincisi eklenmez.
int bildirimKimligi(DateTime gun) =>
    gun.year * 10000 + gun.month * 100 + gun.day;

/// Planlanmış tek bir bildirim.
class PlanliBildirim {
  /// Tarihten türeyen kimlik ([bildirimKimligi]).
  final int kimlik;

  /// Gösterileceği an, Europe/Istanbul duvar saatiyle: [turkiyeSimdi] gibi UTC işaretlidir ama yıl, ay, gün, saat
  /// ve dakika alanları Türkiye saatidir. Cihazın saat dilimine bakılmaz.
  final DateTime zaman;
  final String baslik, metin;
  const PlanliBildirim(
      {required this.kimlik,
      required this.zaman,
      required this.baslik,
      required this.metin});

  /// [zaman]ın gerçek (UTC) anı: Türkiye UTC+3'tür, yaz saati uygulanmaz.
  DateTime get utcAn => zaman.subtract(const Duration(hours: 3));

  @override
  bool operator ==(Object other) =>
      other is PlanliBildirim &&
      other.kimlik == kimlik &&
      other.zaman == zaman &&
      other.baslik == baslik &&
      other.metin == metin;

  @override
  int get hashCode => Object.hash(kimlik, zaman, baslik, metin);

  @override
  String toString() => 'PlanliBildirim($kimlik, $zaman, $baslik, $metin)';
}

/// [menu]de, bugünden ([simdi]'nin günü) başlayan en çok [gunSayisi] (en fazla [bildirimEnCokGun]) günün her
/// biri için [saatDk]'da gösterilecek bildirimleri hazırlar.
///
/// [simdi] Türkiye duvar saatidir ([turkiyeSimdi]). Atlanan günler: saati [simdi]'den önce ya da aynı olan
/// (geçmiş) gün; menüsü olmayan, tatil olan ya da hiçbir öğünde yemek yazmayan gün (hafta sonu servis yoksa
/// menüde o gün de yoktur). Metin: bugünün yemekleri arasında favori ([favoriler], YemekOgesi.anahtar) varsa
/// "Bugün favorin Mantı menüde" öne çıkar; yoksa öğle (yoksa ilk öğün) yemeklerinin kısa listesi (ilk 3 +
/// "+N"). Başlık "AÜ · bugün öğle" biçimindedir. Okulun sunmadığı öğünler yok sayılır.
List<PlanliBildirim> bildirimPlani({
  required Menu menu,
  required Universite uni,
  required int saatDk,
  required DateTime simdi,
  Set<String> favoriler = const {},
  int gunSayisi = bildirimEnCokGun,
}) {
  final dk = saatDk.clamp(0, 24 * 60 - 1);
  // karşılaştırma yalnızca duvar saati alanlarıyla: simdi UTC işaretli de olsa yerel de olsa aynı sonucu verir
  final su = DateTime.utc(simdi.year, simdi.month, simdi.day, simdi.hour,
      simdi.minute, simdi.second);
  final sonuc = <PlanliBildirim>[];
  for (var i = 0; i < gunSayisi.clamp(0, bildirimEnCokGun); i++) {
    final gun = DateTime.utc(simdi.year, simdi.month, simdi.day + i);
    final zaman = DateTime.utc(gun.year, gun.month, gun.day, dk ~/ 60, dk % 60);
    if (!zaman.isAfter(su)) continue;
    final icerik = _icerik(uni, menu.gunler[isoTarih(gun)], favoriler);
    if (icerik == null) continue;
    sonuc.add(PlanliBildirim(
        kimlik: bildirimKimligi(gun),
        zaman: zaman,
        baslik: icerik.baslik,
        metin: icerik.metin));
  }
  return sonuc;
}

/// Bildirimin öğle yemeğine öncelik veren öğün sırası: öğle, kahvaltı, akşam, vejetaryen.
final _bildirimOgunSirasi = ['lunch', ...ogunSirasi.where((t) => t != 'lunch')];

({String baslik, String metin})? _icerik(
    Universite uni, Map<String, Ogun>? gun, Set<String> favoriler) {
  if (gun == null) return null;
  // yemek adı dolu öğünler (öğle önde); okulun sunmadığı öğün yok sayılır
  final dolu = <String, List<YemekOgesi>>{};
  for (final tur in _bildirimOgunSirasi) {
    if (uni.ogunler.isNotEmpty && !uni.ogunler.contains(tur)) continue;
    final ogeler = [
      for (final o in gun[tur]?.ogeler ?? const <YemekOgesi>[])
        if (o.ad.trim().isNotEmpty) o
    ];
    if (ogeler.isNotEmpty) dolu[tur] = ogeler;
  }
  if (dolu.isEmpty) return null;
  // favori yemeği olan ilk öğün (öğle öncelikli) öne çıkar
  if (favoriler.isNotEmpty) {
    for (final e in dolu.entries) {
      final gorulen = <String>{};
      final adlar = [
        for (final o in e.value)
          if (o.anahtar != null &&
              favoriler.contains(o.anahtar) &&
              gorulen.add(o.anahtar!))
            o.ad.trim()
      ];
      if (adlar.isNotEmpty) {
        return (baslik: _baslik(uni, e.key), metin: _favoriMetni(adlar));
      }
    }
  }
  final ilk = dolu.entries.first;
  return (baslik: _baslik(uni, ilk.key), metin: _kisaListe(ilk.value));
}

/// "AÜ · bugün öğle": okulun kısa adı yoksa tam adı.
String _baslik(Universite uni, String tur) {
  final ad = uni.kisa.trim().isEmpty ? uni.ad : uni.kisa.trim();
  return '$ad · bugün ${kucukTr(ogunAdlari[tur] ?? tur)}';
}

String _favoriMetni(List<String> adlar) => switch (adlar.length) {
      1 => 'Bugün favorin ${adlar[0]} menüde',
      2 => 'Bugün favorilerin ${adlar[0]} ve ${adlar[1]} menüde',
      _ =>
        'Bugün favorilerin ${adlar[0]}, ${adlar[1]} ve ${adlar.length - 2} yemek daha menüde',
    };

/// İlk 3 yemek ve geri kalanın sayısı: "Mercimek Çorbası, Pilav, Cacık +2".
String _kisaListe(List<YemekOgesi> ogeler) {
  final adlar = [for (final o in ogeler) o.ad.trim()];
  final ilk = adlar.take(3).join(', ');
  return adlar.length > 3 ? '$ilk +${adlar.length - 3}' : ilk;
}
