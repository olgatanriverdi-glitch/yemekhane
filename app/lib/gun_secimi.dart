import 'models.dart';

// Ana sayfadaki gün ve öğün seçiminin durumsuz yardımcıları (home.dart'ın küçük kalması ve tek başına
// sınanabilmesi için ayrı dosyada).

/// Seçili günü menünün tarih aralığına oturtur: [tarih] aralığın içindeyse (menüsü olmasa da, örn. hafta
/// sonu) olduğu gibi kalır; aralığın dışındaysa en yakın uca çekilir. Menü boşsa değişmez.
String tarihiSinirla(Menu? menu, String tarih) {
  final t = menu?.tarihler ?? const <String>[];
  if (t.isEmpty) return tarih;
  if (tarih.compareTo(t.first) < 0) return t.first;
  if (tarih.compareTo(t.last) > 0) return t.last;
  return tarih;
}

/// [ogun] o gün boşsa (okul yayınlamamış olabilir) dolu olan ilk öğün döner (kahvaltı, öğle, akşam,
/// vejetaryen sırasıyla). Gün menüde yoksa ya da hiçbir öğün dolu değilse [ogun] değişmez.
/// Yalnızca açılışta, gün ya da okul değişince çağrılır; kullanıcının kendi seçtiği sekmeye dokunulmaz.
String uygunOgun(Menu? menu, String tarih, String ogun) {
  final gun = menu?.gunler[tarih];
  if (gun == null) return ogun;
  if (gun[ogun] != null && !gun[ogun]!.bos) return ogun;
  for (final t in ogunSirasi) {
    if (gun[t] != null && !gun[t]!.bos) return t;
  }
  return ogun;
}

/// Okulun sunduğu öğün türleri, sabit gösterim sırasıyla.
List<String> okulOgunleri(Universite uni) => [
      for (final t in ogunSirasi)
        if (uni.ogunler.contains(t)) t
    ];

/// Ekranda gösterilen öğün: [ogun] okulda yoksa okulun ilk öğünü.
String aktifOgun(Universite uni, String ogun) {
  final turler = okulOgunleri(uni);
  return turler.contains(ogun) ? ogun : turler.first;
}

/// Gün çubuğundaki tarihler: bugünden son menü gününe, menüsüz günler dahil ([gunListesi]). Seçili gün
/// bunun dışındaysa (yemek ayrıntısından geçmiş bir gün açılmışsa) çubuk menünün ilk gününe uzar.
List<String> gunCubugu(Menu menu, String bugun, String tarih) {
  final tarihler = gunListesi(menu, bugun);
  return tarihler.isNotEmpty && !tarihler.contains(tarih)
      ? gunListesi(menu, menu.tarihler.first)
      : tarihler;
}
