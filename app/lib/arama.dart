import 'models.dart';

/// Aramanın başlaması için gereken en az karakter sayısı (baştaki / sondaki boşluklar sayılmaz).
const aramaEnAzHarf = 2;

/// Bir aramada döndürülen en çok sonuç sayısı.
const aramaEnCok = 200;

/// Menüde bulunan bir yemek: hangi okulda, hangi gün, hangi öğünde.
class AramaSonucu {
  final Universite okul;
  final String tarih; // 'yyyy-MM-dd'
  final String ogun; // 'breakfast' | 'lunch' | 'dinner' | 'vegetarian'
  final String ad;
  final int? kcal;
  const AramaSonucu(
      {required this.okul,
      required this.tarih,
      required this.ogun,
      required this.ad,
      this.kcal});
}

/// Sorguyu karşılaştırmaya hazırlar: [sadeTr], boşluklar teke iner, kenar boşlukları atılır.
String aramaSorgusu(String sorgu) =>
    sadeTr(sorgu).trim().replaceAll(RegExp(r'\s+'), ' ');

/// Sorgu aramaya yetecek kadar uzun mu ([aramaEnAzHarf])?
bool aramaSorgusuGecerli(String sorgu) =>
    aramaSorgusu(sorgu).length >= aramaEnAzHarf;

/// Verilen okul menülerinde [sorgu]yu arar. Aksanlı / aksansız / büyük harf fark etmez (örn. "corba"
/// "Mercimek Çorbası"nı bulur), kelimenin içinde geçmesi yeterlidir. Yalnızca [bugun] ve sonrası
/// ('yyyy-MM-dd') aranır. Sonuçlar önce tarihe, sonra okul adına (Türkçe sıra), sonra öğün sırasına
/// ve menüdeki sıraya göredir; en çok [aramaEnCok] sonuç döner. Sorgu çok kısaysa liste boştur.
List<AramaSonucu> yemekAra(
    Map<Universite, Menu> menuler, String sorgu, String bugun) {
  final q = aramaSorgusu(sorgu);
  if (q.length < aramaEnAzHarf) return const [];

  // okul adı sırası bir kez hesaplanır (karşılaştırmada her seferinde hesaplanmasın)
  final okullar = menuler.keys.toList()
    ..sort((a, b) => trKarsilastir(a.ad, b.ad));
  final okulSirasi = {for (var i = 0; i < okullar.length; i++) okullar[i]: i};

  final bulunan =
      <(AramaSonucu, int, int)>[]; // sonuç, öğün sırası, menüdeki sıra
  final goruldu = <String>{};
  menuler.forEach((okul, menu) {
    menu.gunler.forEach((tarih, gun) {
      if (tarih.compareTo(bugun) < 0) return;
      gun.forEach((tur, ogun) {
        for (final o in ogun.ogeler) {
          if (!sadeTr(o.ad).contains(q)) continue;
          if (!goruldu.add('${okul.id}|$tarih|$tur|${o.ad}')) continue;
          final sira = ogunSirasi.indexOf(tur);
          bulunan.add((
            AramaSonucu(
                okul: okul, tarih: tarih, ogun: tur, ad: o.ad, kcal: o.kcal),
            sira < 0 ? ogunSirasi.length : sira,
            bulunan.length,
          ));
        }
      });
    });
  });

  bulunan.sort((a, b) {
    final c = a.$1.tarih.compareTo(b.$1.tarih);
    if (c != 0) return c;
    final o = okulSirasi[a.$1.okul]!.compareTo(okulSirasi[b.$1.okul]!);
    if (o != 0) return o;
    final g = a.$2.compareTo(b.$2);
    return g != 0 ? g : a.$3.compareTo(b.$3);
  });
  return [for (final b in bulunan.take(aramaEnCok)) b.$1];
}
