// Menü paylaşım metinleri: saf işlevler (ağ, disk ya da eklenti yok), emoji içermez.
import 'hafta.dart';
import 'models.dart';
import 'widgets/ogun_bilgi.dart' show ogunAdlari;

/// Gün başından itibaren dakikayı "11:00" yazar.
String _saat(int dk) =>
    '${(dk ~/ 60).toString().padLeft(2, '0')}:${(dk % 60).toString().padLeft(2, '0')}';

/// "Öğle (11:00-14:00)"; okul saati yayınlamamış, tipik saat kullanılıyorsa "Öğle (genelde 11:00-14:00)".
/// Servis saati yoksa ya da biçimi bozuksa yalnızca öğün adı.
String _ogunBasligi(Universite uni, String tur) {
  final ad = ogunAdlari[tur] ?? tur;
  final s = uni.saat(tur);
  final a = s?.aralik();
  if (s == null || a == null) return ad;
  return '$ad (${s.yaklasik ? 'genelde ' : ''}${_saat(a.$1)}-${_saat(a.$2)})';
}

int? _fiyat(Universite uni, String tur) {
  final f = uni.ogrenciFiyati(tur);
  return f != null && f > 0 ? f : null;
}

/// "Toplam 1468 kkal · Öğrenci 50 ₺"; olmayan parça yazılmaz, ikisi de yoksa null.
String? _altSatir(Universite uni, String tur, int? kcal) {
  final fiyat = _fiyat(uni, tur);
  final parcalar = [
    if (kcal != null && kcal > 0) 'Toplam $kcal kkal',
    if (fiyat != null) 'Öğrenci $fiyat ₺',
  ];
  return parcalar.isEmpty ? null : parcalar.join(' · ');
}

Iterable<String> _yemekSatirlari(List<YemekOgesi> ogeler) => [
      for (final y in ogeler)
        if (y.ad.trim().isNotEmpty) '• ${y.ad.trim()}'
    ];

List<String> _ogunSatirlari(Universite uni, String tur, Ogun o) {
  final alt = _altSatir(uni, tur, o.kcal);
  return [
    _ogunBasligi(uni, tur),
    ..._yemekSatirlari(o.ogeler),
    if (alt != null) alt,
  ];
}

/// Günde hiç yemek yokken yazılacak satırlar (ana ekrandaki "yemek yok" açıklamalarıyla aynı).
List<String> _gunYokSatirlari(String tarih, Map<String, Ogun> gun) {
  if (gun.isEmpty) {
    final haftaSonu = (DateTime.tryParse(tarih)?.weekday ?? 1) >= 6;
    return [
      haftaSonu
          ? 'Hafta sonu yemekhane hizmeti verilmiyor.'
          : 'Okul bu gün için menü yayınlamadı.'
    ];
  }
  final not =
      gun.values.map((o) => temizNot(o.not)).whereType<String>().firstOrNull;
  return [if (not != null) not, 'Bu gün yemekhane hizmeti verilmiyor.'];
}

/// Bu gün / öğün için paylaşılacak bir şey (yemek ya da not) var mı? [ogun] verilmezse günün herhangi
/// bir verisi yeterlidir.
bool paylasilabilir(Map<String, Ogun> gun, {String? ogun}) {
  if (ogun == null) return gun.isNotEmpty;
  final o = gun[ogun];
  return o != null && (!o.bos || temizNot(o.not) != null);
}

/// Bir günün menüsünün paylaşım metni.
///
///     Ankara Üniversitesi · Cuma 2 Ekim
///     Öğle (11:00-14:00)
///     • Mercimek Çorbası
///     • Pirinç Pilavı
///     Toplam 1468 kkal · Öğrenci 50 ₺
///
/// [ogun] verilirse yalnızca o öğün, verilmezse günün yemeği olan bütün öğünleri (kahvaltı, öğle, akşam,
/// vejetaryen sırasıyla, aralarında boş satırla) yazılır. Olmayan bilgi (kalori, fiyat, servis saati)
/// yazılmaz. Gün tatilse tatil notu, menü yayınlanmamışsa ana ekrandaki açıklama yazılır.
String gunMetni(Universite uni, String tarih, Map<String, Ogun> gun,
    {String? ogun}) {
  final satirlar = <String>['${uni.ad} · ${gunTarihEtiketi(tarih)}'];
  if (ogun != null) {
    final o = gun[ogun];
    final not = temizNot(o?.not);
    if (o != null && !o.bos) {
      satirlar.addAll(_ogunSatirlari(uni, ogun, o));
    } else if (not != null) {
      satirlar.addAll([_ogunBasligi(uni, ogun), not]);
    } else if (gun.values.every((x) => x.bos)) {
      satirlar.addAll(_gunYokSatirlari(tarih, gun));
    } else {
      satirlar.addAll([_ogunBasligi(uni, ogun), 'Bu öğün için menü yok.']);
    }
    return satirlar.join('\n');
  }
  final turler = [
    for (final t in ogunSirasi)
      if (gun[t] != null &&
          !gun[t]!.bos &&
          (uni.ogunler.isEmpty || uni.ogunler.contains(t)))
        t
  ];
  if (turler.isEmpty) {
    satirlar.addAll(_gunYokSatirlari(tarih, gun));
  }
  for (var i = 0; i < turler.length; i++) {
    if (i > 0) satirlar.add('');
    satirlar.addAll(_ogunSatirlari(uni, turler[i], gun[turler[i]]!));
  }
  return satirlar.join('\n');
}

/// Bir haftanın ([pazartesi] ile başlayan 7 gün) seçili [ogun] menüsünün paylaşım metni: başlıkta okul ve
/// tarih aralığı, öğün saati ve öğrenci fiyatı bir kez; sonra her gün için gün adı, yemekler ve toplam
/// kalori. Menüsü olmayan günlerde ("Hizmet yok", "Menü yayınlanmadı", tatil notu) açıklaması yazılır.
String haftaMetni(Universite uni, Menu menu, String pazartesi, String ogun) {
  final fiyat = _fiyat(uni, ogun);
  final satirlar = <String>[
    '${uni.ad} · ${haftaAraligi(pazartesi)}',
    '${_ogunBasligi(uni, ogun)}${fiyat != null ? ' · Öğrenci $fiyat ₺' : ''}',
  ];
  for (final g in haftaGunleri(menu, pazartesi, ogun)) {
    satirlar
      ..add('')
      ..add(gunTarihEtiketi(g.tarih));
    if (g.durum == HaftaDurumu.menu) {
      satirlar.addAll(_yemekSatirlari(g.yemekler));
      if (g.kcal != null) satirlar.add('Toplam ${g.kcal} kkal');
    } else {
      satirlar.add(g.mesaj);
    }
  }
  return satirlar.join('\n');
}
