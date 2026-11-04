class Fiyat {
  final String etiket;
  final int tl;
  Fiyat(this.etiket, this.tl);
  factory Fiyat.fromJson(Map<String, dynamic> j) =>
      jsonDene(j) ?? (throw FormatException('Geçersiz fiyat kaydı', j));

  /// Okul listesindeki bir fiyat kaydı. Kayıt harita değilse, etiketi metin ya da tutarı (sonlu) sayı değilse
  /// null döner: bozuk fiyat atlanır, okul düşmez ([Universite.fromJson]).
  static Fiyat? jsonDene(Object? j) {
    if (j is! Map) return null;
    final etiket = j['label'], tl = j['tl'];
    if (etiket is! String || tl is! num || !tl.isFinite) return null;
    return Fiyat(etiket, tl.toInt());
  }
}

/// Servis saati: [t] '11:30–14:00'; [yaklasik] true ise okul yayınlamamış, tipik saattir ("Genelde …").
class ServisSaati {
  final String t;
  final bool yaklasik;
  const ServisSaati(this.t, this.yaklasik);

  /// Okul listesindeki bir servis saati kaydı ({t: '11:30–14:00', approx: true}). Kayıt harita değilse ya da `t`
  /// metin değilse null döner: bozuk saat atlanır, okul düşmez ([Universite.fromJson]). `approx` yalnızca
  /// `true` ise yaklaşık sayılır.
  static ServisSaati? jsonDene(Object? j) {
    if (j is! Map) return null;
    final t = j['t'];
    return t is String ? ServisSaati(t, j['approx'] == true) : null;
  }

  static final _aralikDeseni =
      RegExp(r'^(\d{1,2}):(\d{2})\s*[–—-]\s*(\d{1,2}):(\d{2})$');

  /// '11:30–14:00' (en dash ya da '-') -> (baslangicDk, bitisDk): gün başından itibaren dakika.
  /// Biçim bozuksa, saat / dakika aralık dışıysa ya da bitiş başlangıçtan sonra değilse null.
  (int, int)? aralik() {
    final m = _aralikDeseni.firstMatch(t.trim());
    if (m == null) return null;
    final sa = int.parse(m[1]!), sd = int.parse(m[2]!);
    final ba = int.parse(m[3]!), bd = int.parse(m[4]!);
    if (sa > 23 || sd > 59 || ba > 24 || bd > 59) return null;
    if (ba == 24 && bd != 0) return null;
    final bas = sa * 60 + sd, bit = ba * 60 + bd;
    return bit > bas ? (bas, bit) : null;
  }
}

/// Bir öğünün servis saatine göre o anki aşaması.
enum OgunAsama { baslamadi, devam, bitti }

class OgunDurumu {
  final OgunAsama asama;

  /// [OgunAsama.baslamadi]: başlamasına, [OgunAsama.devam]: bitmesine kalan dakika; bitti: 0.
  final int kalanDk;
  const OgunDurumu(this.asama, this.kalanDk);
}

/// [simdi] (Türkiye duvar saati; saniyeler yok sayılır) servis saatinin neresinde? Başlangıç dakikası
/// "devam", bitiş dakikası "bitti" sayılır. Saat biçimi bozuksa null.
OgunDurumu? ogunDurumu(ServisSaati s, DateTime simdi) {
  final a = s.aralik();
  if (a == null) return null;
  final dk = simdi.hour * 60 + simdi.minute;
  if (dk < a.$1) return OgunDurumu(OgunAsama.baslamadi, a.$1 - dk);
  if (dk < a.$2) return OgunDurumu(OgunAsama.devam, a.$2 - dk);
  return const OgunDurumu(OgunAsama.bitti, 0);
}

class Universite {
  final String id, ad, kisa, sehir, kaynak;
  final List<String> ogunler;
  final List<Fiyat> fiyatlar;
  final Map<String, ServisSaati> saatler;
  final bool
      eskimis; // build.py: korunan eski kayıt, menü 14 günden eski ("Menü güncel değil")
  Universite(
      {required this.id,
      required this.ad,
      required this.kisa,
      required this.sehir,
      required this.kaynak,
      required this.ogunler,
      required this.fiyatlar,
      this.saatler = const {},
      this.eskimis = false});

  /// index.json'daki bir okul kaydından. Bozuk fiyat ve servis saati girdileri atlanır, okul düşmez. Kimlik ya da
  /// ad metin değilse (kayıt kullanılamaz) hata fırlatır; listeyi okuyan [Depo.universiteler] o kaydı atlar.
  factory Universite.fromJson(Map<String, dynamic> j) {
    final fiyatlar = j['prices'], saatler = j['hours'];
    return Universite(
      id: j['id'] as String,
      ad: j['name'] as String,
      kisa: (j['short'] ?? '') as String,
      sehir: (j['city'] ?? '') as String,
      kaynak: (j['source'] ?? '') as String,
      ogunler:
          ((j['meals'] ?? const []) as List).map((e) => e as String).toList(),
      fiyatlar: [
        if (fiyatlar is List)
          for (final e in fiyatlar)
            if (Fiyat.jsonDene(e) case final f?) f
      ],
      saatler: {
        if (saatler is Map)
          for (final e in saatler.entries)
            if (e.key is String)
              if (ServisSaati.jsonDene(e.value) case final s?)
                e.key as String: s
      },
      eskimis: (j['stale'] ?? false) as bool,
    );
  }

  /// Öğünün servis saati; vejetaryen menünün kendi saati yoksa öğle saatini kullanır.
  ServisSaati? saat(String ogun) =>
      saatler[ogun] ?? (ogun == 'vegetarian' ? saatler['lunch'] : null);

  /// Öğrenci fiyatı: etiketi "Öğrenci" ile başlayan ve öğün adını içeren kayıt.
  int? ogrenciFiyati(String ogun) {
    final anahtar =
        ogun == 'lunch' ? 'öğle' : (ogun == 'dinner' ? 'akşam' : '');
    for (final f in fiyatlar) {
      final e = f.etiket.toLowerCase();
      if (e.startsWith('öğrenci') &&
          anahtar.isNotEmpty &&
          e.contains(anahtar)) {
        return f.tl;
      }
    }
    return null;
  }
}

class YemekOgesi {
  final String ad;
  final int? kcal;
  final String? img; // 'dishes/<anahtar>.jpg' (yemeğe ait küçük örnek fotoğraf)
  final String?
      anahtar; // yemek adından türeyen kalıcı kimlik (yemek bazlı puanlama için)
  YemekOgesi(this.ad, this.kcal, [this.img, this.anahtar]);
  factory YemekOgesi.fromJson(Map<String, dynamic> j) => YemekOgesi(
      j['name'] as String,
      (j['kcal'] as num?)?.toInt(),
      j['img'] as String?,
      j['key'] as String?);
}

/// Wikimedia Commons dosya adından ('Kuru köfte ve pilav.jpg') [genislik] piksel genişliğindeki sürümün adresi.
/// Adres Commons'ta gerçek dosyaya yönlendirir; boşluklar alt çizgiye çevrilir, özel karakterler kodlanır.
String yuksekCozunurlukUrl(String baslik, {int genislik = 960}) =>
    'https://commons.wikimedia.org/wiki/Special:FilePath/'
    '${Uri.encodeComponent(baslik.replaceAll(' ', '_'))}?width=$genislik';

/// Commons dosya sayfasının adresi ('File:' sayfası): bilgi kaydında sayfa adresi yoksa dosya adından üretilir.
String commonsSayfaUrl(String baslik) =>
    'https://commons.wikimedia.org/wiki/File:${Uri.encodeComponent(baslik.replaceAll(' ', '_'))}';

/// Yemeğin örnek fotoğrafının Wikimedia Commons bilgisi (data/dishes/index.json): yüksek çözünürlüklü sürümü bulmak
/// ve yazarı / lisansı belirtmek (atıf) için. Yemek anahtarına ([YemekOgesi.anahtar]) göre aranır.
class YemekBilgisi {
  /// Commons dosya adı, ör. 'Kuru köfte ve pilav.jpg' ('File:' öneki yok).
  final String baslik;

  /// Fotoğrafın yazarı ve lisansı (ör. 'E4024', 'CC BY-SA 4.0'); kayıtta yoksa ya da boşsa null.
  final String? yazar, lisans;

  /// Commons dosya sayfasının adresi (panoya kopyalanır). Kayıtta yoksa [baslik]tan üretilir.
  final String sayfa;
  const YemekBilgisi(
      {required this.baslik, this.yazar, this.lisans, required this.sayfa});

  /// index.json'daki bir kayıttan. Kayıt bozuksa ya da dosya adı yoksa null döner: tek kötü kayıt ne diğer
  /// yemekleri ne de ekranı bozar. Metinler kırpılır; boş metin yok sayılır.
  static YemekBilgisi? fromJson(Object? j) {
    if (j is! Map) return null;
    String? metin(Object? v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    final baslik = metin(j['baslik']);
    if (baslik == null) return null;
    final sayfa = metin(j['sayfa']);
    return YemekBilgisi(
        baslik: baslik,
        yazar: metin(j['yazar']),
        lisans: metin(j['lisans']),
        // yalnızca https adresleri panoya gider; bozuk bir değer yerine dosya adından üretilir
        sayfa: sayfa != null && sayfa.startsWith('https://')
            ? sayfa
            : commonsSayfaUrl(baslik));
  }

  /// Yüksek çözünürlüklü sürümün adresi ([yuksekCozunurlukUrl]).
  String get yuksekCozunurlukAdresi => yuksekCozunurlukUrl(baslik);

  /// "Fotoğraf: E4024 · CC BY-SA 4.0 · Wikimedia Commons". Yazar ya da lisans yoksa null: atıf satırı gösterilmez.
  String? get atif => yazar == null || lisans == null
      ? null
      : 'Fotoğraf: $yazar · $lisans · Wikimedia Commons';
}

class Ogun {
  final List<YemekOgesi> ogeler;
  final int? kcal;
  final String?
      foto; // 'photos/lib/<anahtar>.jpg' (menünün tabldot fotoğrafı, varsa)
  final bool
      fotoYaklasik; // true: aynı menü değil, aynı ana yemekli benzer bir menünün fotoğrafı
  final String?
      not; // örn. "Tatil", "29 Ekim Cumhuriyet Bayramı": yemek verilmeyen gün notu
  Ogun(this.ogeler, this.kcal,
      [this.foto, this.fotoYaklasik = false, this.not]);
  factory Ogun.fromJson(Map<String, dynamic> j) => Ogun(
        [
          // bozuk öğe tüm öğünü düşürmesin: atlanır
          for (final e in ((j['items'] ?? const []) as List))
            if (e is Map<String, dynamic> && e['name'] is String)
              YemekOgesi.fromJson(e)
        ],
        (j['kcal'] as num?)?.toInt(),
        j['photo'] as String?,
        (j['photoApprox'] ?? false) as bool,
        j['note'] as String?,
      );
  bool get bos => ogeler.isEmpty;
}

class Menu {
  final String universiteId;
  final DateTime? guncellendi;
  final Map<String, Map<String, Ogun>>
      gunler; // 'yyyy-MM-dd' -> öğün türü -> öğün
  Menu(this.universiteId, this.guncellendi, this.gunler);

  factory Menu.fromJson(Map<String, dynamic> j) {
    final gunler = <String, Map<String, Ogun>>{};
    final gunHam = j['days'];
    if (gunHam is Map) {
      gunHam.forEach((tarih, v) {
        // bozuk gün / öğün atlanır, kalan menü yine gösterilir
        if (tarih is! String || DateTime.tryParse(tarih) == null) return;
        if (v is! Map) return;
        final ogunler = <String, Ogun>{};
        v.forEach((tur, o) {
          if (tur is! String || o is! Map<String, dynamic>) return;
          try {
            ogunler[tur] = Ogun.fromJson(o);
          } catch (_) {}
        });
        gunler[tarih] = ogunler;
      });
    }
    return Menu(j['university'] as String,
        DateTime.tryParse('${j['updated'] ?? ''}')?.toLocal(), gunler);
  }

  List<String> get tarihler => (gunler.keys.toList()..sort());
}

/// Gün çubuğu için tarih listesi: bugünden (menü başlamamışsa ilk günden) son menü gününe kadar,
/// menüsü olmayan günler (hafta sonu, tatil) dahil kesintisiz. Menü bittiyse son 7 gün gösterilir.
List<String> gunListesi(Menu menu, String bugun) {
  final t = menu.tarihler;
  if (t.isEmpty) return [];
  final son = DateTime.parse(t.last);
  var bas = DateTime.parse(bugun.compareTo(t.first) < 0 ? t.first : bugun);
  if (bas.isAfter(son)) bas = son.subtract(const Duration(days: 6));
  final sonuc = <String>[];
  for (var d = bas; !d.isAfter(son); d = DateTime(d.year, d.month, d.day + 1)) {
    sonuc.add(isoTarih(d));
  }
  return sonuc;
}

/// Menüde bir favori yemeğin geçtiği gün ve öğün.
class FavoriEslesme {
  final String tarih; // 'yyyy-MM-dd'
  final String ogun; // 'breakfast' | 'lunch' | 'dinner' | 'vegetarian'
  final String ad;
  final String anahtar;
  const FavoriEslesme(
      {required this.tarih,
      required this.ogun,
      required this.ad,
      required this.anahtar});
}

/// Öğün türlerinin gösterim sırası.
const ogunSirasi = ['breakfast', 'lunch', 'dinner', 'vegetarian'];

/// [bugun] ve sonraki [gunSayisi] - 1 gün içinde, menüde geçen favori yemekler: önce tarih, sonra öğün sırası
/// (kahvaltı, öğle, akşam, vejetaryen). Menüsü olmayan günler atlanır; ay / yıl sonları takvime göre geçilir.
List<FavoriEslesme> favoriEslesmeleri(
    Menu menu, String bugun, Set<String> anahtarlar,
    {int gunSayisi = 7}) {
  final b = DateTime.tryParse(bugun);
  if (b == null || anahtarlar.isEmpty || gunSayisi <= 0) return const [];
  final sonuc = <FavoriEslesme>[];
  for (var i = 0; i < gunSayisi; i++) {
    final tarih = isoTarih(DateTime.utc(b.year, b.month, b.day + i));
    final gun = menu.gunler[tarih];
    if (gun == null) continue;
    for (final tur in ogunSirasi) {
      final gorulen = <String>{};
      for (final o in gun[tur]?.ogeler ?? const <YemekOgesi>[]) {
        final k = o.anahtar;
        if (k != null && anahtarlar.contains(k) && gorulen.add(k)) {
          sonuc.add(
              FavoriEslesme(tarih: tarih, ogun: tur, ad: o.ad, anahtar: k));
        }
      }
    }
  }
  return sonuc;
}

/// Bir yemeğin menüde göründüğü gün ve öğün (yemek ayrıntı sayfasındaki "Bu yemek ne zaman var" satırı).
class YemekGorunumu {
  final String tarih; // 'yyyy-MM-dd'
  final String ogun; // 'breakfast' | 'lunch' | 'dinner' | 'vegetarian'
  const YemekGorunumu({required this.tarih, required this.ogun});
}

/// [anahtar]lı yemeğin [menu]de geçtiği bütün (tarih, öğün) görünümleri: önce tarih (eskiden yeniye),
/// aynı günde öğün sırasıyla (kahvaltı, öğle, akşam, vejetaryen). Bir öğünde aynı yemek birden çok kez
/// geçse de tek sayılır. Geçmiş günler de dahildir; boş anahtar ya da menüde olmayan yemek boş liste verir.
List<YemekGorunumu> yemekTarihleri(Menu menu, String anahtar) {
  if (anahtar.isEmpty) return const [];
  final sonuc = <YemekGorunumu>[];
  for (final tarih in menu.tarihler) {
    final gun = menu.gunler[tarih];
    if (gun == null) continue;
    for (final tur in ogunSirasi) {
      if (gun[tur]?.ogeler.any((o) => o.anahtar == anahtar) ?? false) {
        sonuc.add(YemekGorunumu(tarih: tarih, ogun: tur));
      }
    }
  }
  return sonuc;
}

/// Okulun açılışta gösterilecek öğünü: kahvaltı, öğle, akşam sırasıyla bitişi [simdi]'den sonra olan ilk öğün;
/// hepsi bittiyse sonuncusu. Saati olmayan öğle 15:00'te, akşam gün sonunda biter (eski "15:00" kuralı);
/// saati olmayan kahvaltı atlanır. Vejetaryen kendiliğinden seçilmez. Hiç aday yoksa 15:00 kuralı.
String akilliOgun(Universite uni, DateTime simdi) {
  final dk = simdi.hour * 60 + simdi.minute;
  String? sonuncu;
  for (final t in const ['breakfast', 'lunch', 'dinner']) {
    if (!uni.ogunler.contains(t)) continue;
    final bitis = uni.saat(t)?.aralik()?.$2 ??
        (t == 'lunch' ? 15 * 60 : (t == 'dinner' ? 24 * 60 : null));
    if (bitis == null) continue;
    sonuncu = t;
    if (bitis > dk) return t;
  }
  return sonuncu ?? (simdi.hour >= 15 ? 'dinner' : 'lunch');
}

/// Türkiye saati (UTC+3): cihazın saat dilimi ne olursa olsun "bugün" ve 15:00 öğün kararı aynı kalır.
/// Dönen değerin yalnızca tarih/saat alanları kullanılmalı (UTC işaretli, ama duvar saati Türkiye'dir).
DateTime turkiyeSimdi() => DateTime.now().toUtc().add(const Duration(hours: 3));

String isoTarih(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Türkçe'ye uygun küçük harfe çevirme (İ -> i, I -> ı).
String kucukTr(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

const _trSira = 'abcçdefgğhıijklmnoöprsştuüvyz';

/// Türkçe alfabe sırasına göre karşılaştırma (ç, ğ, ı, ö, ş, ü kendi yerinde); büyük / küçük harf fark etmez.
/// Alfabede olmayan karakterler (rakam, boşluk, q, w, x...) harflerden sonra kod sırasıyla gelir; ortak
/// başlangıçta kısa olan önce sıralanır. Okul adı gibi metinleri `List.sort` içinde sıralamak için.
int trKarsilastir(String a, String b) {
  final x = kucukTr(a), y = kucukTr(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    final p = _trSira.indexOf(x[i]), q = _trSira.indexOf(y[i]);
    final c = (p < 0 ? 100 + x.codeUnitAt(i) : p)
        .compareTo(q < 0 ? 100 + y.codeUnitAt(i) : q);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

const _sadeHarita = {
  'ç': 'c',
  'ğ': 'g',
  'ı': 'i',
  'ö': 'o',
  'ş': 's',
  'ü': 'u',
  'â': 'a',
  'î': 'i',
  'û': 'u',
};

/// Aksan ve büyük / küçük harf duyarsız karşılaştırma için: [kucukTr] sonra ç->c ğ->g ı->i ö->o ş->s ü->u
/// (â î û ve birleşik nokta işareti de sadeleşir). "ÇORBA", "çorba" ve "corba" aynı olur.
String sadeTr(String s) {
  final k = kucukTr(s);
  final b = StringBuffer();
  for (var i = 0; i < k.length; i++) {
    final c = k[i];
    if (c == '\u0307') continue; // İ'nin birleşik nokta işareti
    b.write(_sadeHarita[c] ?? c);
  }
  return b.toString();
}

const _etAnahtar = [
  'et ',
  ' et',
  'etli',
  'tavuk',
  'piliç',
  'köfte',
  'kıyma',
  'kebap',
  'döner',
  'bifte',
  'biftek',
  'balık',
  'sucuk',
  'salam',
  'sosis',
  'dana',
  'kuzu',
  'hindi',
  'ciğer',
  'mantı',
  'şnitzel',
  'tantuni',
  'iskender',
  'kavurma',
  'baget',
  'but ',
  'but/',
  'incik',
  'şiş',
  'tavuk',
  'bacak',
  'kanat',
  'taleks',
  'topkapı',
  'bonfile',
  'pirzola',
  'hamburger',
  'nugget',
  'karkas',
  'tas kebabı',
  'güveç',
];

/// Ad, bilinen et / tavuk / balık anahtar kelimelerinden birini içermiyorsa "etsiz" sayılır (tahmini).
bool etsizMi(String ad) {
  final k = ' ${kucukTr(ad)} ';
  for (final a in _etAnahtar) {
    if (k.contains(a)) return false;
  }
  return true;
}
