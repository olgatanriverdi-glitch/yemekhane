class Fiyat {
  final String etiket;
  final int tl;
  Fiyat(this.etiket, this.tl);
  factory Fiyat.fromJson(Map<String, dynamic> j) =>
      Fiyat(j['label'] as String, (j['tl'] as num).toInt());
}

/// Servis saati: [t] '11:30–14:00'; [yaklasik] true ise okul yayınlamamış, tipik saattir ("Genelde …").
class ServisSaati {
  final String t;
  final bool yaklasik;
  const ServisSaati(this.t, this.yaklasik);
}

class Universite {
  final String id, ad, kisa, sehir, kaynak;
  final List<String> ogunler;
  final List<Fiyat> fiyatlar;
  final Map<String, ServisSaati> saatler;
  Universite(
      {required this.id,
      required this.ad,
      required this.kisa,
      required this.sehir,
      required this.kaynak,
      required this.ogunler,
      required this.fiyatlar,
      this.saatler = const {}});

  factory Universite.fromJson(Map<String, dynamic> j) => Universite(
        id: j['id'] as String,
        ad: j['name'] as String,
        kisa: (j['short'] ?? '') as String,
        sehir: (j['city'] ?? '') as String,
        kaynak: (j['source'] ?? '') as String,
        ogunler:
            ((j['meals'] ?? const []) as List).map((e) => e as String).toList(),
        fiyatlar: ((j['prices'] ?? const []) as List)
            .map((e) => Fiyat.fromJson(e as Map<String, dynamic>))
            .toList(),
        saatler: {
          for (final e in ((j['hours'] ?? const {}) as Map).entries)
            e.key as String: ServisSaati((e.value as Map)['t'] as String,
                ((e.value as Map)['approx'] ?? false) as bool)
        },
      );

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
        ((j['items'] ?? const []) as List)
            .map((e) => YemekOgesi.fromJson(e as Map<String, dynamic>))
            .toList(),
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
    (j['days'] as Map<String, dynamic>).forEach((tarih, v) {
      final ogunler = <String, Ogun>{};
      (v as Map<String, dynamic>).forEach(
          (tur, o) => ogunler[tur] = Ogun.fromJson(o as Map<String, dynamic>));
      gunler[tarih] = ogunler;
    });
    return Menu(j['university'] as String,
        DateTime.tryParse((j['updated'] ?? '') as String)?.toLocal(), gunler);
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

String isoTarih(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Türkçe'ye uygun küçük harfe çevirme (İ -> i, I -> ı).
String kucukTr(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Türkçe'ye uygun büyük harfe çevirme (i -> İ, ı -> I).
String buyukTr(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

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

const _yanYemek = [
  'çorba',
  'ayran',
  'salata',
  'yoğurt',
  'cacık',
  'turşu',
  'meyve',
  'komposto',
  'tatlı',
  'baklava',
  'sütlaç',
  'puding',
  'kek',
  'helva',
  'tulumba',
  'revani',
  'kadayıf',
  'şekerpare',
  'muhallebi',
  'kazandibi',
  'pasta',
  'ekmek',
  'içecek',
  'meşrubat',
  'dondurma',
  'haydari',
  'piyaz',
  'tarator',
  'ezme',
  'kısır',
  'pilav',
  'makarna',
  'erişte',
  'spagetti',
  'kuskus',
  'bulgur',
];

/// Öğünün "ana yemeği": çorba olmayan etli/tavuklu/balıklı yemekler arasından (yoksa çorba, pilav, salata, tatlı gibi yan yemekler
/// dışındakiler arasından) kalorisi en yüksek olan. Kalori yoksa ilk aday. Öğün boşsa null.
YemekOgesi? anaYemek(Ogun o) {
  final liste = o.ogeler;
  if (liste.isEmpty) return null;
  final etli = liste
      .where((e) => !etsizMi(e.ad) && !kucukTr(e.ad).contains('çorba'))
      .toList();
  var havuz = etli;
  if (havuz.isEmpty) {
    havuz = liste.where((e) {
      final k = kucukTr(e.ad);
      return !_yanYemek.any(k.contains);
    }).toList();
  }
  if (havuz.isEmpty) havuz = liste;
  return havuz.reduce((a, b) => (b.kcal ?? -1) > (a.kcal ?? -1) ? b : a);
}

const _trAlfabe = 'abcçdefgğhıijklmnoöprsştuüvyz';

/// Türkçe alfabe sırasına göre karşılaştırma (ç, ğ, ı, ö, ş, ü doğru yerde).
int trKarsilastir(String a, String b) {
  int sira(String ch) {
    final i = _trAlfabe.indexOf(ch);
    return i >= 0 ? i : 100 + ch.codeUnitAt(0);
  }

  final x = kucukTr(a), y = kucukTr(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    final fark = sira(x[i]) - sira(y[i]);
    if (fark != 0) return fark;
  }
  return x.length - y.length;
}

/// Üniversite listesini şehre göre gruplar: şehirler ve her şehrin okulları Türkçe alfabe sırasında; şehri olmayanlar "Diğer" altında sona gider.
List<MapEntry<String, List<Universite>>> sehreGoreGrupla(
    List<Universite> uniler) {
  final gruplar = <String, List<Universite>>{};
  for (final u in uniler) {
    gruplar.putIfAbsent(u.sehir.isEmpty ? 'Diğer' : u.sehir, () => []).add(u);
  }
  final sehirler = gruplar.keys.toList()
    ..sort((a, b) {
      if (a == 'Diğer') return 1;
      if (b == 'Diğer') return -1;
      return trKarsilastir(a, b);
    });
  return [
    for (final s in sehirler)
      MapEntry(s, gruplar[s]!..sort((a, b) => trKarsilastir(a.ad, b.ad)))
  ];
}
