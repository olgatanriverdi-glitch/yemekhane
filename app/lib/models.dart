class Fiyat {
  final String etiket;
  final int tl;
  Fiyat(this.etiket, this.tl);
  factory Fiyat.fromJson(Map<String, dynamic> j) => Fiyat(j['label'] as String, (j['tl'] as num).toInt());
}

class Universite {
  final String id, ad, kisa, sehir, kaynak;
  final List<String> ogunler;
  final List<Fiyat> fiyatlar;
  Universite({required this.id, required this.ad, required this.kisa, required this.sehir, required this.kaynak, required this.ogunler, required this.fiyatlar});

  factory Universite.fromJson(Map<String, dynamic> j) => Universite(
        id: j['id'] as String,
        ad: j['name'] as String,
        kisa: (j['short'] ?? '') as String,
        sehir: (j['city'] ?? '') as String,
        kaynak: (j['source'] ?? '') as String,
        ogunler: ((j['meals'] ?? const []) as List).map((e) => e as String).toList(),
        fiyatlar: ((j['prices'] ?? const []) as List).map((e) => Fiyat.fromJson(e as Map<String, dynamic>)).toList(),
      );

  /// Öğrenci fiyatı: etiketi "Öğrenci" ile başlayan ve öğün adını içeren kayıt.
  int? ogrenciFiyati(String ogun) {
    final anahtar = ogun == 'lunch' ? 'öğle' : (ogun == 'dinner' ? 'akşam' : '');
    for (final f in fiyatlar) {
      final e = f.etiket.toLowerCase();
      if (e.startsWith('öğrenci') && anahtar.isNotEmpty && e.contains(anahtar)) return f.tl;
    }
    return null;
  }
}

class YemekOgesi {
  final String ad;
  final int? kcal;
  YemekOgesi(this.ad, this.kcal);
  factory YemekOgesi.fromJson(Map<String, dynamic> j) => YemekOgesi(j['name'] as String, (j['kcal'] as num?)?.toInt());
}

class Ogun {
  final List<YemekOgesi> ogeler;
  final int? kcal;
  final String? foto; // 'photos/2026-10-02.jpg' (günün tabldot fotoğrafı, varsa)
  Ogun(this.ogeler, this.kcal, [this.foto]);
  factory Ogun.fromJson(Map<String, dynamic> j) => Ogun(
        ((j['items'] ?? const []) as List).map((e) => YemekOgesi.fromJson(e as Map<String, dynamic>)).toList(),
        (j['kcal'] as num?)?.toInt(),
        j['photo'] as String?,
      );
  bool get bos => ogeler.isEmpty;
}

class Menu {
  final String universiteId;
  final DateTime? guncellendi;
  final Map<String, Map<String, Ogun>> gunler; // 'yyyy-MM-dd' -> öğün türü -> öğün
  Menu(this.universiteId, this.guncellendi, this.gunler);

  factory Menu.fromJson(Map<String, dynamic> j) {
    final gunler = <String, Map<String, Ogun>>{};
    (j['days'] as Map<String, dynamic>).forEach((tarih, v) {
      final ogunler = <String, Ogun>{};
      (v as Map<String, dynamic>).forEach((tur, o) => ogunler[tur] = Ogun.fromJson(o as Map<String, dynamic>));
      gunler[tarih] = ogunler;
    });
    return Menu(j['university'] as String, DateTime.tryParse((j['updated'] ?? '') as String), gunler);
  }

  List<String> get tarihler => (gunler.keys.toList()..sort());
}

String isoTarih(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
