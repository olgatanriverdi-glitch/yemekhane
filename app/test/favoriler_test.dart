import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/favoriler.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/favori_seridi.dart';

const _anahtar = FavoriDeposu.prefsAnahtari;

/// Ağa ve diske gitmeyen sahte veri deposu.
class _SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  _SahteDepo(this.liste, this.menuVeri);

  @override
  Future<List<Universite>> universiteler() async => liste;
  @override
  Future<Menu> menu(String universiteId) async => menuVeri[universiteId]!;
  @override
  Future<String?> seciliUniversite() async => liste.first.id;
  @override
  Future<void> universiteSec(String id) async {}
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  String? fotoUrl(String universiteId, String? foto) => null;
  @override
  String? yemekFotoUrl(String? img) => null;
}

YemekOgesi _y(String ad, String? anahtar, [int? kcal]) =>
    YemekOgesi(ad, kcal, null, anahtar);

Universite _uni() => Universite(
    id: 'ankara',
    ad: 'Ankara Üniversitesi',
    kisa: 'AÜ',
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch', 'dinner'],
    fiyatlar: const []);

/// Pazartesi 2 Kasım 2026 bugündür. 4 Kasım'ın menüsü yok; Mantı Perşembe, kuru fasulye Cuma çıkar.
Menu _menu() => Menu('ankara', null, {
      '2026-11-02': {
        'lunch': Ogun([
          _y('Mercimek Çorbası', 'mercimek', 120),
          _y('Pirinç Pilavı', 'pilav', 300),
          _y('Ayran', null, 60), // anahtarsız: kalp yok
        ], 480),
        'dinner': Ogun([_y('Fırın Makarna', 'makarna', 500)], 500),
      },
      '2026-11-03': {
        'lunch': Ogun([
          _y('Ezogelin Çorbası', 'ezogelin', 110),
          _y('Pirinç Pilavı', 'pilav', 300),
        ], 410),
      },
      '2026-11-05': {
        'lunch': Ogun([_y('Mantı', 'manti', 450)], 450)
      },
      '2026-11-06': {
        'lunch': Ogun(
            [_y('Kuru Fasulye', 'fasulye', 350), _y('Ayran', null, 60)], 410)
      },
    });

const _uzunAd =
    'Çok Uzun Adlı Kremalı Mantarlı Közlenmiş Patlıcanlı Tavuk Sote Spesiyal Yemeği';

Menu _uzunMenu() => Menu('ankara', null, {
      '2026-11-02': {
        'lunch': Ogun([
          _y(_uzunAd, 'uzun1', 1234),
          _y('Mercimek Çorbası', 'mercimek', 120),
          _y('Pirinç Pilavı', 'pilav', 300),
        ], 1654),
      },
      '2026-11-03': {
        'lunch': Ogun([_y('Mantı', 'manti', 450)], 450)
      },
    });

DateTime _simdi() => DateTime.utc(2026, 11, 2, 10, 0);

void _favoriKaydi(Map<String, String> favoriler) =>
    SharedPreferences.setMockInitialValues({_anahtar: jsonEncode(favoriler)});

Future<FavoriDeposu> _ac(WidgetTester t,
    {Menu? menu,
    Size boyut = const Size(400, 900),
    double yaziOlcegi = 1.0}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari();
  final favoriler = FavoriDeposu();
  await t.pumpWidget(MaterialApp(
    theme: ayar.tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c)
            .copyWith(textScaler: TextScaler.linear(yaziOlcegi)),
        child: w!),
    home: AnaSayfa(
        temaAyari: ayar,
        depo: _SahteDepo([_uni()], {'ankara': menu ?? _menu()}),
        geriBildirim: YerelDepo(),
        favoriler: favoriler,
        simdi: _simdi),
  ));
  await t.pumpAndSettle();
  return favoriler;
}

Future<Map<String, dynamic>> _kayitliFavoriler() async {
  final p = await SharedPreferences.getInstance();
  return jsonDecode(p.getString(_anahtar) ?? '{}') as Map<String, dynamic>;
}

Menu _tekGunMenu(Map<String, Map<String, Ogun>> gunler) =>
    Menu('x', null, gunler);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FavoriDeposu', () {
    test('boş başlar; yüklenince yuklendi olur', () async {
      final d = FavoriDeposu();
      expect(d.yuklendi, isFalse);
      expect(d.sayi, 0);
      expect(d.liste, isEmpty);
      await d.yukle();
      expect(d.yuklendi, isTrue);
      expect(d.liste, isEmpty);
    });

    test('ekle / varMi / liste (en yeni başta) / çıkar ve JSON biçimi',
        () async {
      final d = FavoriDeposu();
      expect(await d.ekle('manti', 'Mantı'), isTrue);
      expect(await d.ekle('pilav', 'Pirinç Pilavı'), isTrue);
      expect(d.varMi('manti'), isTrue);
      expect(d.varMi('yok'), isFalse);
      expect(d.sayi, 2);
      expect(d.anahtarlar, {'manti', 'pilav'});
      expect(d.liste.map((f) => f.anahtar), ['pilav', 'manti']);
      expect(d.liste.map((f) => f.ad), ['Pirinç Pilavı', 'Mantı']);
      expect(await _kayitliFavoriler(),
          {'manti': 'Mantı', 'pilav': 'Pirinç Pilavı'});

      await d.cikar('manti');
      expect(d.varMi('manti'), isFalse);
      expect(d.sayi, 1);
      expect(await _kayitliFavoriler(), {'pilav': 'Pirinç Pilavı'});
      await d.cikar('manti'); // olmayanı çıkarmak zararsız
      expect(d.sayi, 1);
    });

    test('aynı yemek iki kez eklenmez; değiştir ekler / çıkarır', () async {
      final d = FavoriDeposu();
      expect(await d.ekle('manti', 'Mantı'), isTrue);
      expect(await d.ekle('manti', 'Mantı'), isTrue);
      expect(d.sayi, 1);
      expect(await d.degistir('manti', 'Mantı'), isTrue);
      expect(d.varMi('manti'), isFalse);
      expect(await d.degistir('manti', 'Mantı'), isTrue);
      expect(d.varMi('manti'), isTrue);
    });

    test('kayıtlı favoriler yeni örnekte okunur (okuldan bağımsız)', () async {
      _favoriKaydi({'manti': 'Mantı', 'pilav': 'Pirinç Pilavı'});
      final d = FavoriDeposu();
      await d.yukle();
      expect(d.anahtarlar, {'manti', 'pilav'});
      expect(d.liste.first.ad, 'Pirinç Pilavı'); // son kayıt en yeni sayılır
    });

    test('bozuk JSON -> boş liste, sonra yine eklenebilir', () async {
      for (final bozuk in ['bozuk{{', '[1,2]', '"x"', '5', 'null', '']) {
        SharedPreferences.setMockInitialValues({_anahtar: bozuk});
        final d = FavoriDeposu();
        await d.yukle();
        expect(d.liste, isEmpty, reason: 'ham: $bozuk');
        expect(await d.ekle('a', 'A'), isTrue);
        expect(await _kayitliFavoriler(), {'a': 'A'}, reason: 'ham: $bozuk');
      }
    });

    test('bozuk tek öğe diğerlerini düşürmez', () async {
      SharedPreferences.setMockInitialValues({
        _anahtar: '{"a":"A","b":5,"c":"","":"x","d":null,"e":"E","f":["x"]}'
      });
      final d = FavoriDeposu();
      await d.yukle();
      expect(d.anahtarlar, {'a', 'e'});
    });

    test(
        'en çok 200 favori: sonrası eklenmez, mevcut olan ve çıkarılan sonra ekler',
        () async {
      final d = FavoriDeposu();
      for (var i = 0; i < FavoriDeposu.enCok; i++) {
        expect(await d.ekle('k$i', 'Yemek $i'), isTrue);
      }
      expect(d.sayi, 200);
      expect(await d.ekle('fazla', 'Fazla'), isFalse);
      expect(d.varMi('fazla'), isFalse);
      expect(d.sayi, 200);
      expect(await d.degistir('fazla', 'Fazla'), isFalse);
      expect(await d.ekle('k5', 'Yemek 5'), isTrue); // zaten var
      expect(d.sayi, 200);

      await d.cikar('k0');
      expect(await d.ekle('fazla', 'Fazla'), isTrue);
      expect(d.sayi, 200);
      expect((await _kayitliFavoriler()).length, 200);
    });

    test('kayıtta 200\'den fazla varsa en yeni 200 kalır', () async {
      _favoriKaydi({for (var i = 0; i < 230; i++) 'k$i': 'Yemek $i'});
      final d = FavoriDeposu();
      await d.yukle();
      expect(d.sayi, 200);
      expect(d.varMi('k29'), isFalse);
      expect(d.varMi('k30'), isTrue);
      expect(d.varMi('k229'), isTrue);
    });

    test('değişince dinleyenler haberdar olur, işe yaramayan çağrıda olmaz',
        () async {
      final d = FavoriDeposu();
      var sayac = 0;
      d.addListener(() => sayac++);
      await d.yukle();
      expect(sayac, 1); // yükleme
      await d.ekle('a', 'A');
      expect(sayac, 2);
      await d.ekle('a', 'A'); // zaten var
      expect(sayac, 2);
      await d.cikar('b'); // yok
      expect(sayac, 2);
      await d.cikar('a');
      expect(sayac, 3);
    });

    test('yükleme bitmeden eklenen, kayıtlı favorileri ezmez', () async {
      _favoriKaydi({'a': 'A'});
      final d = FavoriDeposu();
      final ekleme = d.ekle('x', 'X'); // yukle() çağrılmadı
      await ekleme;
      expect(d.anahtarlar, {'a', 'x'});
      expect(await _kayitliFavoriler(), {'a': 'A', 'x': 'X'});
    });

    test('dispose sonrası biten yükleme hata vermez', () async {
      _favoriKaydi({'a': 'A'});
      final d = FavoriDeposu();
      final yukleme = d.yukle();
      d.dispose();
      await yukleme; // notifyListeners çağrılmaz
    });
  });

  group('favoriEslesmeleri', () {
    Ogun ogun(List<String> anahtarlar) =>
        Ogun([for (final k in anahtarlar) _y('Yemek $k', k)], null);

    test('bugünden başlayıp gunSayisi gün; 7. gün dahil, 8. gün dışarıda', () {
      final menu = _tekGunMenu({
        for (var g = 1; g <= 10; g++)
          '2026-11-${g.toString().padLeft(2, '0')}': {
            'lunch': ogun(['a'])
          },
      });
      final e = favoriEslesmeleri(menu, '2026-11-02', {'a'});
      expect(e.map((x) => x.tarih), [
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
        '2026-11-06',
        '2026-11-07',
        '2026-11-08',
      ]);
      expect(
          favoriEslesmeleri(menu, '2026-11-02', {'a'}, gunSayisi: 2)
              .map((x) => x.tarih),
          ['2026-11-02', '2026-11-03']);
      expect(
          favoriEslesmeleri(menu, '2026-11-02', {'a'}, gunSayisi: 0), isEmpty);
      expect(
          favoriEslesmeleri(menu, '2026-11-02', {'a'}, gunSayisi: 366).length,
          9); // 2..10 Kasım
    });

    test('geçmiş günler sayılmaz, bugün sayılır', () {
      final menu = _tekGunMenu({
        '2026-11-01': {
          'lunch': ogun(['a'])
        },
        '2026-11-02': {
          'lunch': ogun(['a'])
        },
      });
      final e = favoriEslesmeleri(menu, '2026-11-02', {'a'});
      expect(e.map((x) => x.tarih), ['2026-11-02']);
    });

    test('ay sonu: 30 Ekim -> 31 Ekim, 1 ve 5 Kasım dahil, 6 Kasım dışarıda',
        () {
      final menu = _tekGunMenu({
        '2026-10-31': {
          'lunch': ogun(['a'])
        },
        '2026-11-01': {
          'lunch': ogun(['a'])
        },
        '2026-11-05': {
          'dinner': ogun(['a'])
        },
        '2026-11-06': {
          'lunch': ogun(['a'])
        },
      });
      final e = favoriEslesmeleri(menu, '2026-10-30', {'a'});
      expect(e.map((x) => x.tarih), ['2026-10-31', '2026-11-01', '2026-11-05']);
    });

    test('yıl sonu ve şubat sonu doğru geçilir', () {
      final yil = _tekGunMenu({
        '2026-12-31': {
          'lunch': ogun(['a'])
        },
        '2027-01-01': {
          'lunch': ogun(['a'])
        },
        '2027-01-05': {
          'lunch': ogun(['a'])
        },
        '2027-01-06': {
          'lunch': ogun(['a'])
        },
      });
      expect(favoriEslesmeleri(yil, '2026-12-30', {'a'}).map((x) => x.tarih),
          ['2026-12-31', '2027-01-01', '2027-01-05']);

      final artik = _tekGunMenu({
        '2028-02-29': {
          'lunch': ogun(['a'])
        },
        '2028-03-01': {
          'lunch': ogun(['a'])
        },
      });
      expect(favoriEslesmeleri(artik, '2028-02-28', {'a'}).map((x) => x.tarih),
          ['2028-02-29', '2028-03-01']);

      final artikDegil = _tekGunMenu({
        '2027-03-01': {
          'lunch': ogun(['a'])
        },
      });
      expect(
          favoriEslesmeleri(artikDegil, '2027-02-28', {'a'})
              .map((x) => x.tarih),
          ['2027-03-01']);
    });

    test('menüsü olmayan gün atlanır, menü hiç yoksa boş döner', () {
      final menu = _tekGunMenu({
        '2026-11-02': {
          'lunch': ogun(['a'])
        },
        '2026-11-05': {
          'lunch': ogun(['a'])
        },
      });
      expect(favoriEslesmeleri(menu, '2026-11-02', {'a'}).length, 2);
      expect(favoriEslesmeleri(_tekGunMenu({}), '2026-11-02', {'a'}), isEmpty);
    });

    test('öğün sırası kahvaltı, öğle, akşam, vejetaryen; önce tarih', () {
      final menu = _tekGunMenu({
        '2026-11-03': {
          'vegetarian': ogun(['a']),
          'dinner': ogun(['a']),
          'lunch': ogun(['a']),
          'breakfast': ogun(['a']),
        },
        '2026-11-02': {
          'dinner': ogun(['a']),
          'lunch': ogun(['a']),
        },
      });
      final e = favoriEslesmeleri(menu, '2026-11-02', {'a'});
      expect(e.map((x) => '${x.tarih} ${x.ogun}'), [
        '2026-11-02 lunch',
        '2026-11-02 dinner',
        '2026-11-03 breakfast',
        '2026-11-03 lunch',
        '2026-11-03 dinner',
        '2026-11-03 vegetarian',
      ]);
    });

    test('bugün ve yarın birlikte; ad ve anahtar eşleşmeden gelir', () {
      final menu = _tekGunMenu({
        '2026-11-02': {
          'lunch': Ogun([_y('Mantı', 'manti'), _y('Ayran', null)], null)
        },
        '2026-11-03': {
          'lunch': Ogun([_y('Mantı', 'manti'), _y('Pilav', 'pilav')], null)
        },
      });
      final e = favoriEslesmeleri(menu, '2026-11-02', {'manti'});
      expect(e.length, 2);
      expect(e[0].tarih, '2026-11-02');
      expect(e[1].tarih, '2026-11-03');
      expect(e[0].ad, 'Mantı');
      expect(e[0].anahtar, 'manti');
      expect(e[0].ogun, 'lunch');
    });

    test('anahtarsız öğe, boş anahtar kümesi ve bozuk tarih eşleşme vermez',
        () {
      final menu = _tekGunMenu({
        '2026-11-02': {
          'lunch': Ogun([_y('Ayran', null), _y('Mantı', 'manti')], null)
        },
      });
      expect(favoriEslesmeleri(menu, '2026-11-02', <String>{}), isEmpty);
      expect(favoriEslesmeleri(menu, '2026-11-02', {'yok'}), isEmpty);
      expect(favoriEslesmeleri(menu, 'bozuk', {'manti'}), isEmpty);
    });

    test('aynı öğünde tekrar eden yemek tek sayılır; farklı öğünlerde ikişer',
        () {
      final menu = _tekGunMenu({
        '2026-11-02': {
          'lunch': Ogun([_y('Mantı', 'manti'), _y('Mantı', 'manti')], null),
          'dinner': Ogun([_y('Mantı', 'manti')], null),
        },
      });
      final e = favoriEslesmeleri(menu, '2026-11-02', {'manti'});
      expect(e.map((x) => x.ogun), ['lunch', 'dinner']);
    });
  });

  group('günlük etiket ve şerit metni', () {
    test('favoriGunEtiketi', () {
      expect(favoriGunEtiketi('2026-11-02', '2026-11-02'), 'Bugün');
      expect(favoriGunEtiketi('2026-11-03', '2026-11-02'), 'Yarın');
      expect(favoriGunEtiketi('2026-11-06', '2026-11-02'), 'Cuma');
      expect(favoriGunEtiketi('2026-11-06', '2026-11-02', tamTarih: true),
          'Cuma 6 Kasım');
      // ay sonu: 31 Ekim'in ertesi 1 Kasım
      expect(favoriGunEtiketi('2026-11-01', '2026-10-31'), 'Yarın');
      expect(favoriGunEtiketi('2026-11-01', '2026-10-31', tamTarih: true),
          'Yarın');
      expect(favoriGunEtiketi('2026-11-02', '2026-10-31', tamTarih: true),
          'Pazartesi 2 Kasım');
      expect(favoriGunEtiketi('bozuk', '2026-11-02'), 'bozuk');
    });

    FavoriEslesme e(String tarih, String ogun, String ad) =>
        FavoriEslesme(tarih: tarih, ogun: ogun, ad: ad, anahtar: ad);

    test('bugün varsa yalnızca bugünküler hedeftir', () {
      final hepsi = [
        e('2026-11-02', 'lunch', 'Mantı'),
        e('2026-11-04', 'lunch', 'Pilav'),
      ];
      expect(seritHedefleri(hepsi, '2026-11-02').map((x) => x.ad), ['Mantı']);
      expect(seritHedefleri(hepsi, '2026-11-01').length, 2);
      expect(seritHedefleri([], '2026-11-02'), isEmpty);
    });

    test('tek eşleşme: bugün / ileri tarih / yarın', () {
      expect(
          favoriSeridiMetni([e('2026-11-02', 'lunch', 'Mantı')], '2026-11-02'),
          'Bugün menüde: Mantı (öğle)');
      expect(
          favoriSeridiMetni([e('2026-11-06', 'lunch', 'Mantı')], '2026-11-02'),
          'Favorin Mantı: Cuma (öğle)');
      expect(
          favoriSeridiMetni([e('2026-11-03', 'dinner', 'Mantı')], '2026-11-02'),
          'Favorin Mantı: Yarın (akşam)');
    });

    test('2+ eşleşmede ilk iki ve +N', () {
      final bugun = [
        e('2026-11-02', 'lunch', 'Mantı'),
        e('2026-11-02', 'dinner', 'Pilav'),
        e('2026-11-02', 'dinner', 'Ayran'),
        e('2026-11-02', 'vegetarian', 'Salata'),
      ];
      expect(favoriSeridiMetni(bugun.take(2).toList(), '2026-11-02'),
          'Bugün menüde: Mantı (öğle), Pilav (akşam)');
      expect(favoriSeridiMetni(bugun, '2026-11-02'),
          'Bugün menüde: Mantı (öğle), Pilav (akşam) +2');

      final sonra = [
        e('2026-11-03', 'lunch', 'Ezogelin'),
        e('2026-11-05', 'breakfast', 'Mantı'),
        e('2026-11-06', 'lunch', 'Mantı'),
      ];
      expect(favoriSeridiMetni(sonra.take(2).toList(), '2026-11-02'),
          'Favorilerin: Ezogelin (Yarın, öğle), Mantı (Perşembe, kahvaltı)');
      expect(favoriSeridiMetni(sonra, '2026-11-02'),
          'Favorilerin: Ezogelin (Yarın, öğle), Mantı (Perşembe, kahvaltı) +1');
    });

    test('çok uzun ad kısaltılır, +N korunur', () {
      final metin = favoriSeridiMetni([
        e('2026-11-02', 'lunch', _uzunAd),
        e('2026-11-02', 'lunch', 'Mantı'),
        e('2026-11-02', 'dinner', 'Pilav'),
      ], '2026-11-02');
      expect(metin, contains('…'));
      expect(metin, endsWith('+1'));
      expect(metin.length, lessThan(100));
    });

    test('sonrakiHedef: ilk, sıradaki ve sonda başa dönüş', () {
      final h = [
        e('2026-11-02', 'lunch', 'A'),
        e('2026-11-02', 'lunch', 'B'), // aynı konum
        e('2026-11-02', 'dinner', 'C'),
        e('2026-11-04', 'lunch', 'D'),
      ];
      // eşleşmede değilsek ilki
      expect(sonrakiHedef(h, '2026-11-03', 'lunch').ad, 'A');
      // aynı konumdaki iki yemekte takılmadan bir sonraki konuma
      expect(sonrakiHedef(h, '2026-11-02', 'lunch').ad, 'C');
      expect(sonrakiHedef(h, '2026-11-02', 'dinner').ad, 'D');
      expect(sonrakiHedef(h, '2026-11-04', 'lunch').ad, 'A'); // başa dön
    });
  });

  group('kalp düğmesi ve şerit (AnaSayfa)', () {
    testWidgets('yalnızca anahtarı olan yemeklerde kalp çıkar', (t) async {
      await _ac(t);
      // öğle: Mercimek ve Pilav anahtarlı, Ayran anahtarsız
      expect(find.text('Ayran'), findsOneWidget);
      expect(find.byTooltip('Favorilere ekle'), findsNWidgets(2));
      expect(find.byTooltip('Favorilerden çıkar'), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(3)); // +AppBar
    });

    testWidgets('OgunKarti favoriler verilmezse kalp göstermez', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OgunKarti(
              ogun: Ogun([_y('Mantı', 'manti')], null),
              yemekFoto: (_) => null,
              geriBildirim: YerelDepo(),
              slot: 's',
              uniId: 'x'),
        ),
      ));
      await t.pump();
      expect(find.byTooltip('Favorilere ekle'), findsNothing);
      expect(find.byTooltip('Favorilerden çıkar'), findsNothing);
    });

    testWidgets(
        'kalbe dokununca dolar, şerit çıkar, kayıt yazılır; tekrar boşalır',
        (t) async {
      final f = await _ac(t);
      expect(
          find.textContaining('menüde'), findsNothing); // favori yok: şerit yok

      await t.tap(find.byTooltip('Favorilere ekle').first);
      await t.pumpAndSettle();
      expect(f.varMi('mercimek'), isTrue);
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
      expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsWidgets);
      expect(
          find.text('Bugün menüde: Mercimek Çorbası (öğle)'), findsOneWidget);
      expect(await _kayitliFavoriler(), {'mercimek': 'Mercimek Çorbası'});

      await t.tap(find.byTooltip('Favorilerden çıkar'));
      await t.pumpAndSettle();
      expect(f.varMi('mercimek'), isFalse);
      expect(find.byTooltip('Favorilere ekle'), findsNWidgets(2));
      expect(find.textContaining('menüde'), findsNothing);
      expect(await _kayitliFavoriler(), isEmpty);
    });

    testWidgets('kayıtlı favori başka günde çıkıyorsa "Favorin ..." şeridi',
        (t) async {
      _favoriKaydi({'manti': 'Mantı'});
      await _ac(t);
      expect(find.text('Favorin Mantı: Perşembe (öğle)'), findsOneWidget);
      expect(find.textContaining('Bugün menüde'), findsNothing);
    });

    testWidgets('şeride dokununca o gün ve öğüne geçer', (t) async {
      _favoriKaydi({'manti': 'Mantı'});
      await _ac(t);
      expect(find.text('Mercimek Çorbası'), findsOneWidget); // bugün öğle
      await t.tap(find.text('Favorin Mantı: Perşembe (öğle)'));
      await t.pumpAndSettle();
      expect(find.text('Mantı'), findsOneWidget); // yemek satırı
      expect(find.text('Perşembe'), findsOneWidget); // gün başlığı
      expect(find.text('Mercimek Çorbası'), findsNothing);
    });

    testWidgets('akşam favorisine dokununca Akşam sekmesine geçer', (t) async {
      _favoriKaydi({'makarna': 'Fırın Makarna'});
      await _ac(t);
      expect(find.text('Bugün menüde: Fırın Makarna (akşam)'), findsOneWidget);
      expect(find.text('Fırın Makarna'), findsNothing); // öğle seçili
      await t.tap(find.textContaining('Bugün menüde'));
      await t.pumpAndSettle();
      expect(find.text('Fırın Makarna'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsNothing);
    });

    testWidgets('2+ eşleşme: ilk 2 ve +N; tekrar dokunmak sıradakine götürür',
        (t) async {
      _favoriKaydi({
        'mercimek': 'Mercimek Çorbası',
        'pilav': 'Pirinç Pilavı',
        'makarna': 'Fırın Makarna'
      });
      await _ac(t);
      const metin =
          'Bugün menüde: Mercimek Çorbası (öğle), Pirinç Pilavı (öğle) +1';
      expect(find.text(metin), findsOneWidget);

      await t.tap(find.text(metin)); // bugün öğle zaten seçili: sıradaki akşam
      await t.pumpAndSettle();
      expect(find.text('Fırın Makarna'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsNothing);

      await t.tap(find.text(metin)); // sonda: başa döner
      await t.pumpAndSettle();
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(find.text('Fırın Makarna'), findsNothing);
    });

    testWidgets('bugün eşleşme yokken çoklu ileri tarih metni', (t) async {
      _favoriKaydi({
        'ezogelin': 'Ezogelin Çorbası',
        'manti': 'Mantı',
        'fasulye': 'Kuru Fasulye'
      });
      await _ac(t);
      expect(
          find.text(
              'Favorilerin: Ezogelin Çorbası (Yarın, öğle), Mantı (Perşembe, öğle) +1'),
          findsOneWidget);
    });

    testWidgets('limit dolunca yeni favori eklenmez, bildirim çıkar',
        (t) async {
      _favoriKaydi({for (var i = 0; i < 200; i++) 'k$i': 'Yemek $i'});
      final f = await _ac(t);
      expect(f.sayi, 200);
      await t.tap(find.byTooltip('Favorilere ekle').first);
      await t.pumpAndSettle();
      expect(f.varMi('mercimek'), isFalse);
      expect(f.sayi, 200);
      expect(
          find.text('En fazla 200 favori ekleyebilirsin. Önce birini çıkar.'),
          findsOneWidget);
      expect(find.byTooltip('Favorilere ekle'), findsNWidgets(2));
    });

    testWidgets('enjekte edilen depo sayfa kapanınca atılmaz', (t) async {
      final f = await _ac(t);
      await t.pumpWidget(const SizedBox());
      await f.ekle('a', 'A'); // atılmış olsaydı bildirim hata verirdi
      expect(f.varMi('a'), isTrue);
    });
  });

  group('Favoriler ekranı', () {
    testWidgets('favori yokken yönlendirme yazısı çıkar', (t) async {
      await _ac(t);
      await t.tap(find.byTooltip('Favoriler'));
      await t.pumpAndSettle();
      expect(find.byType(FavorilerSayfasi), findsOneWidget);
      expect(find.text('Favoriler'), findsOneWidget); // başlık
      expect(
          find.text(
              'Yemeklerin yanındaki kalbe dokunarak favori ekleyebilirsin.'),
          findsOneWidget);
    });

    testWidgets('liste: ad, okuldaki sıradaki tarih; menüde olmayan için not',
        (t) async {
      _favoriKaydi({
        'manti': 'Mantı',
        'mercimek': 'Mercimek Çorbası',
        'ezogelin': 'Ezogelin Çorbası',
        'yok': 'Hiç Çıkmayan',
      });
      await _ac(t);
      await t.tap(find.byTooltip('Favoriler'));
      await t.pumpAndSettle();
      expect(find.text('Tarihler Ankara Üniversitesi menüsüne göre'),
          findsOneWidget);
      expect(find.text('Mantı'), findsOneWidget);
      expect(find.text('Sıradaki: Perşembe 5 Kasım (öğle)'), findsOneWidget);
      expect(find.text('Sıradaki: Bugün (öğle)'), findsOneWidget);
      expect(find.text('Sıradaki: Yarın (öğle)'), findsOneWidget);
      expect(find.text('Yayınlanan menüde görünmüyor'), findsOneWidget);
      expect(find.byTooltip('Favorilerden çıkar'), findsNWidgets(4));
      // en yeni (son kaydedilen) başta
      final ilk = t.getTopLeft(find.text('Hiç Çıkmayan')).dy;
      final son = t.getTopLeft(find.text('Mantı')).dy;
      expect(ilk, lessThan(son));
    });

    testWidgets(
        'kaldırınca listeden gider, Geri al geri getirir; ana sayfa da güncellenir',
        (t) async {
      _favoriKaydi({'manti': 'Mantı', 'yok': 'Hiç Çıkmayan'});
      final f = await _ac(t);
      expect(find.text('Favorin Mantı: Perşembe (öğle)'), findsOneWidget);

      await t.tap(find.byTooltip('Favoriler'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Favorilerden çıkar').first); // Hiç Çıkmayan
      await t.pumpAndSettle();
      expect(find.text('Hiç Çıkmayan'), findsNothing);
      expect(f.varMi('yok'), isFalse);
      expect(find.text('Hiç Çıkmayan favorilerden çıkarıldı'), findsOneWidget);

      await t.tap(find.text('Geri al'));
      await t.pumpAndSettle();
      expect(f.varMi('yok'), isTrue);
      expect(find.text('Hiç Çıkmayan'), findsOneWidget);

      // Mantı'yı da kaldır, sayfadan dön: şerit kaybolur
      await t.tap(find.byTooltip('Favorilerden çıkar').last);
      await t.pumpAndSettle();
      expect(f.varMi('manti'), isFalse);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(FavorilerSayfasi), findsNothing);
      expect(find.textContaining('Favorin'), findsNothing);
      expect(await _kayitliFavoriler(), {'yok': 'Hiç Çıkmayan'});
    });

    testWidgets('son favoriyi kaldırınca boş durum yazısı çıkar', (t) async {
      _favoriKaydi({'manti': 'Mantı'});
      await _ac(t);
      await t.tap(find.byTooltip('Favoriler'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Favorilerden çıkar'));
      await t.pumpAndSettle();
      expect(
          find.text(
              'Yemeklerin yanındaki kalbe dokunarak favori ekleyebilirsin.'),
          findsOneWidget);
    });

    testWidgets('okul / menü yokken tarih satırı gösterilmez', (t) async {
      _favoriKaydi({'manti': 'Mantı'});
      final f = FavoriDeposu()..yukle();
      await t.pumpWidget(MaterialApp(
          home: FavorilerSayfasi(favoriler: f, bugun: '2026-11-02')));
      await t.pumpAndSettle();
      expect(find.text('Mantı'), findsOneWidget);
      expect(find.textContaining('Sıradaki'), findsNothing);
      expect(find.textContaining('Tarihler'), findsNothing);
      expect(find.textContaining('menüde görünmüyor'), findsNothing);
    });
  });

  group('taşma', () {
    testWidgets(
        '320x640, yazı 1.5x: uzun adlı favoriler, kalpler ve şerit taşmaz',
        (t) async {
      _favoriKaydi({
        'uzun1': _uzunAd,
        'mercimek': 'Mercimek Çorbası',
        'pilav': 'Pirinç Pilavı',
        'manti': 'Mantı',
      });
      await _ac(t,
          menu: _uzunMenu(), boyut: const Size(320, 640), yaziOlcegi: 1.5);
      expect(t.takeException(), isNull);
      expect(
          find.textContaining('Bugün menüde: Çok Uzun Adlı'), findsOneWidget);
      // kalpler: dokunma hedefi >= 48dp
      final kalpler = find.widgetWithIcon(IconButton, Icons.favorite);
      expect(kalpler, findsWidgets);
      for (final k in kalpler.evaluate()) {
        final boyut = t.getSize(find.byWidget(k.widget));
        expect(boyut.width, greaterThanOrEqualTo(48));
        expect(boyut.height, greaterThanOrEqualTo(48));
      }
      // şeride dokunmak ve günü değiştirmek de taşırmaz
      await t.tap(find.textContaining('Bugün menüde'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.textContaining('Favorin'),
          findsNothing); // yarın: şerit bugünküleri gösterir
    });

    testWidgets(
        '320x640, yazı 1.5x: kalbe dokununca satır ve kalori hapı taşmaz',
        (t) async {
      await _ac(t, boyut: const Size(320, 640), yaziOlcegi: 1.5);
      expect(t.takeException(), isNull);
      final kalp = find.byTooltip('Favorilere ekle').first;
      await t
          .ensureVisible(kalp); // 1.5x'te ilk satır ekranın altında kalabilir
      await t.pumpAndSettle();
      await t.tap(kalp);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
    });

    testWidgets('320x640, yazı 1.5x: Favoriler ekranı uzun adla taşmaz',
        (t) async {
      _favoriKaydi({'uzun1': _uzunAd, 'manti': 'Mantı', 'yok': 'Hiç Çıkmayan'});
      await _ac(t,
          menu: _uzunMenu(), boyut: const Size(320, 640), yaziOlcegi: 1.5);
      await t.tap(find.byTooltip('Favoriler'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(FavorilerSayfasi), findsOneWidget);
      for (final dugme
          in find.widgetWithIcon(IconButton, Icons.delete_outline).evaluate()) {
        final boyut = t.getSize(find.byWidget(dugme.widget));
        expect(boyut.width, greaterThanOrEqualTo(48));
        expect(boyut.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('320x640, yazı 1.5x: boş Favoriler ekranı taşmaz', (t) async {
      await _ac(t, boyut: const Size(320, 640), yaziOlcegi: 1.5);
      await t.tap(find.byTooltip('Favoriler'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });
}
