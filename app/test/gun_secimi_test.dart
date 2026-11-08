// lib/gun_secimi.dart: ana sayfadaki gün ve öğün seçiminin durumsuz yardımcıları.
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/gun_secimi.dart';
import 'package:yemekhane/models.dart';

Ogun _dolu(String ad) => Ogun([YemekOgesi(ad, 100)], 100);
Ogun _bos() => Ogun([], null);

Universite _uni(List<String> ogunler) => Universite(
    id: 'a',
    ad: 'Ankara Üniversitesi',
    kisa: 'AÜ',
    sehir: 'Ankara',
    kaynak: '',
    ogunler: ogunler,
    fiyatlar: const []);

Menu _menu(Map<String, Map<String, Ogun>> gunler) => Menu('a', null, gunler);

void main() {
  group('tarihiSinirla', () {
    final menu = _menu({
      '2026-11-02': {'lunch': _dolu('A')},
      '2026-11-06': {'lunch': _dolu('B')},
    });

    test('aralığın içindeki gün olduğu gibi kalır (menüsü olmasa da)', () {
      expect(tarihiSinirla(menu, '2026-11-02'), '2026-11-02');
      expect(tarihiSinirla(menu, '2026-11-04'), '2026-11-04'); // menüsüz gün
      expect(tarihiSinirla(menu, '2026-11-06'), '2026-11-06');
    });

    test('aralığın dışındaki gün en yakın uca çekilir', () {
      expect(tarihiSinirla(menu, '2026-10-31'), '2026-11-02');
      expect(tarihiSinirla(menu, '2026-11-09'), '2026-11-06');
    });

    test('menü yoksa ya da boşsa gün değişmez', () {
      expect(tarihiSinirla(null, '2026-11-04'), '2026-11-04');
      expect(tarihiSinirla(_menu({}), '2026-11-04'), '2026-11-04');
    });
  });

  group('uygunOgun', () {
    test('seçili öğün doluysa değişmez', () {
      final menu = _menu({
        '2026-11-02': {'lunch': _dolu('A'), 'dinner': _dolu('B')},
      });
      expect(uygunOgun(menu, '2026-11-02', 'dinner'), 'dinner');
    });

    test(
        'seçili öğün boşsa kahvaltı, öğle, akşam, vejetaryen sırasıyla ilk dolu',
        () {
      final menu = _menu({
        '2026-11-02': {
          'vegetarian': _dolu('V'),
          'dinner': _dolu('D'),
          'lunch': _bos(),
        },
      });
      expect(uygunOgun(menu, '2026-11-02', 'lunch'), 'dinner');
      expect(uygunOgun(menu, '2026-11-02', 'breakfast'), 'dinner');
      final yalnizVeji = _menu({
        '2026-11-02': {'vegetarian': _dolu('V')},
      });
      expect(uygunOgun(yalnizVeji, '2026-11-02', 'lunch'), 'vegetarian');
    });

    test('tatil notlu (yemeksiz) öğün boş sayılır', () {
      final menu = _menu({
        '2026-11-02': {
          'lunch': Ogun([], null, null, false, 'Tatil'),
          'dinner': _dolu('D'),
        },
      });
      expect(uygunOgun(menu, '2026-11-02', 'lunch'), 'dinner');
    });

    test('gün menüde yoksa ya da hiçbir öğün dolu değilse öğün değişmez', () {
      final menu = _menu({
        '2026-11-02': {'lunch': _bos(), 'dinner': _bos()},
      });
      expect(uygunOgun(menu, '2026-11-03', 'dinner'), 'dinner'); // gün yok
      expect(uygunOgun(menu, '2026-11-02', 'dinner'), 'dinner'); // hepsi boş
      expect(uygunOgun(null, '2026-11-02', 'lunch'), 'lunch');
    });
  });

  group('okulOgunleri / aktifOgun', () {
    test('okulun öğünleri sabit gösterim sırasıyla gelir', () {
      expect(okulOgunleri(_uni(['dinner', 'vegetarian', 'lunch'])),
          ['lunch', 'dinner', 'vegetarian']);
      expect(okulOgunleri(_uni(['lunch'])), ['lunch']);
    });

    test('bilinmeyen öğün türü listeye girmez', () {
      expect(okulOgunleri(_uni(['lunch', 'brunch'])), ['lunch']);
    });

    test('seçili öğün okulda yoksa okulun ilk öğünü gösterilir', () {
      final uni = _uni(['lunch', 'dinner']);
      expect(aktifOgun(uni, 'dinner'), 'dinner');
      expect(aktifOgun(uni, 'breakfast'), 'lunch');
      expect(aktifOgun(uni, 'vegetarian'), 'lunch');
    });
  });

  group('gunCubugu', () {
    final menu = _menu({
      '2026-11-02': {'lunch': _dolu('A')},
      '2026-11-05': {'lunch': _dolu('B')},
    });

    test('bugünden son menü gününe, menüsüz günler dahil', () {
      expect(gunCubugu(menu, '2026-11-03', '2026-11-04'),
          ['2026-11-03', '2026-11-04', '2026-11-05']);
    });

    test(
        'seçili gün çubuğun dışındaysa (geçmiş gün) çubuk menünün ilk gününe uzar',
        () {
      expect(gunCubugu(menu, '2026-11-04', '2026-11-02'),
          ['2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05']);
    });

    test('menü boşsa çubuk boştur', () {
      expect(gunCubugu(_menu({}), '2026-11-02', '2026-11-02'), isEmpty);
    });
  });
}
