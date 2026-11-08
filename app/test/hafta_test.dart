import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/hafta.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/paylas.dart';
import 'package:yemekhane/paylasim.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/hafta.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';

// ---------------------------------------------------------------------------
// Ortak veri
// ---------------------------------------------------------------------------

Universite _uni(
        {String ad = 'Ankara Üniversitesi',
        List<String> ogunler = const ['lunch', 'dinner']}) =>
    Universite(
        id: 'ankara',
        ad: ad,
        kisa: 'AÜ',
        sehir: 'Ankara',
        kaynak: '',
        ogunler: ogunler,
        fiyatlar: [Fiyat('Öğrenci (Öğle Yemeği)', 50)],
        saatler: const {'lunch': ServisSaati('11:00–14:00', false)});

YemekOgesi _y(String ad, [int? kcal, String? anahtar]) =>
    YemekOgesi(ad, kcal, null, anahtar);

Ogun _notlu(String not) => Ogun(const [], null, null, false, not);

/// Menü 28 Ekim (çarşamba) - 12 Kasım (perşembe) arası; üç hafta: 26 Ekim, 2 Kasım ve 9 Kasım haftaları.
///  - 29 Ekim: resmi tatil (öğle ve akşam notlu, yemek yok)
///  - 2 Kasım: öğle 5 yemek (+1), akşam var; 3 Kasım: kalorisiz öğle
///  - 4 Kasım (bugün): favori mantı; 5 Kasım: "Tatil"; 6 Kasım: yalnızca akşam
///  - 31 Ekim, 1 Kasım, 7 Kasım, 8 Kasım (hafta sonları) ile 10 - 11 Kasım için veri yok
Menu _menu() => Menu('ankara', null, {
      '2026-10-28': {
        'lunch': Ogun([_y('Kuru Fasulye', 350)], 350)
      },
      '2026-10-29': {
        'lunch': _notlu('29 Ekim Cumhuriyet Bayramı'),
        'dinner': _notlu('29 Ekim Cumhuriyet Bayramı'),
      },
      '2026-10-30': {
        'lunch': Ogun([_y('Pilav', 300)], 300)
      },
      '2026-11-02': {
        'lunch': Ogun([
          _y('Mercimek Çorbası', 120),
          _y('Tavuk Sote', 400),
          _y('Pirinç Pilavı', 300),
          _y('Cacık', 80),
          _y('Sütlaç', 300),
        ], 1200),
        'dinner': Ogun([_y('Fırın Makarna', 500)], 500),
      },
      '2026-11-03': {
        'lunch':
            Ogun([_y('Ezogelin Çorbası', 110), _y('Tavuk Sote', 400)], null)
      },
      '2026-11-04': {
        'lunch':
            Ogun([_y('Mantı', 450, 'manti'), _y('Cacık', 80, 'cacik')], 530)
      },
      '2026-11-05': {'lunch': _notlu('Tatil'), 'dinner': _notlu('Tatil')},
      '2026-11-06': {
        'dinner': Ogun([_y('Fırın Makarna', 500)], 500)
      },
      '2026-11-09': {
        'lunch': Ogun([_y('Domates Çorbası', 90)], 90)
      },
      '2026-11-12': {
        'lunch': Ogun([_y('Yayla Çorbası', 100)], 100)
      },
    });

/// Çağrıları kaydeden sahte paylaşım servisi; [hata] doluysa fırlatır (paylaşım açılamadı).
class SahtePaylasim implements PaylasimServisi {
  final List<(String, String?)> cagrilar = [];
  Object? hata;

  @override
  Future<void> paylas(String metin, {String? konu}) async {
    cagrilar.add((metin, konu));
    if (hata != null) throw hata!;
  }
}

/// Panoya yazılan metinleri toplar (SystemChannels.platform sahtesi).
List<String> _panoyuDinle(WidgetTester t) {
  final yazilan = <String>[];
  t.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (c) async {
    if (c.method == 'Clipboard.setData') {
      yazilan.add((c.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return yazilan;
}

// ---------------------------------------------------------------------------
// Haftalık menü sayfasını tek başına açan yardımcılar
// ---------------------------------------------------------------------------

/// "Aç" düğmesinden [HaftaSayfasi]ni açar; sayfa bir tarihle kapanırsa [donenler]e eklenir.
Future<void> _ac(
  WidgetTester t, {
  Menu? menu,
  Universite? uni,
  String tarih = '2026-11-04',
  String bugun = '2026-11-04',
  String ogun = 'lunch',
  FavoriDeposu? favoriler,
  SahtePaylasim? paylasim,
  List<String?>? donenler,
  Size boyut = const Size(400, 900),
  double yaziOlcegi = 1.0,
  bool hareketKapali = false,
  ThemeData? tema,
}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: tema ?? TemaAyari().tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(yaziOlcegi),
            disableAnimations: hareketKapali),
        child: w!),
    home: Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              final d = await Navigator.of(c).push<String>(MaterialPageRoute(
                  builder: (_) => HaftaSayfasi(
                      uni: uni ?? _uni(),
                      menu: menu ?? _menu(),
                      bugun: bugun,
                      tarih: tarih,
                      ogun: ogun,
                      favoriler: favoriler,
                      paylasim: paylasim ?? SahtePaylasim())));
              donenler?.add(d);
            },
            child: const Text('Aç'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('Aç'));
  await t.pumpAndSettle();
}

Finder _kart(String tarih) => find.byKey(ValueKey('hafta-$tarih'));

Finder _kartta(String tarih, Finder f) =>
    find.descendant(of: _kart(tarih), matching: f);

/// Kartın yemek satırının (Text.rich) düz metni; kalp simgeleri sayılmaz.
String _yemekMetni(WidgetTester t, String tarih) {
  final yazi = _kartta(
      tarih, find.byWidgetPredicate((w) => w is Text && w.textSpan != null));
  final span = t.widget<Text>(yazi).textSpan! as TextSpan;
  return span.children!.whereType<TextSpan>().map((s) => s.text ?? '').join();
}

bool _acik(WidgetTester t, IconData ikon) =>
    t.widget<IconButton>(find.widgetWithIcon(IconButton, ikon)).onPressed !=
    null;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('hafta mantığı', () {
    test(
        'haftaBaslangici: hafta pazartesi başlar, ay / yıl / artık yıl geçilir',
        () {
      expect(haftaBaslangici('2026-11-02'), '2026-11-02'); // pazartesi
      expect(haftaBaslangici('2026-11-04'), '2026-11-02');
      expect(haftaBaslangici('2026-11-08'), '2026-11-02'); // pazar
      expect(haftaBaslangici('2026-11-01'), '2026-10-26'); // pazar, ay başı
      expect(haftaBaslangici('2027-01-01'), '2026-12-28'); // cuma, yıl başı
      expect(haftaBaslangici('2028-03-01'), '2028-02-28'); // artık yıl
      expect(haftaBaslangici('bozuk'), 'bozuk');
    });

    test('tarihEkle: ay ve yıl sonları, geriye gidiş, artık gün', () {
      expect(tarihEkle('2026-11-30', 1), '2026-12-01');
      expect(tarihEkle('2026-12-31', 1), '2027-01-01');
      expect(tarihEkle('2026-11-02', -3), '2026-10-30');
      expect(tarihEkle('2028-02-28', 1), '2028-02-29');
      expect(tarihEkle('2026-11-02', 0), '2026-11-02');
      expect(tarihEkle('bozuk', 5), 'bozuk');
    });

    test('haftaTarihleri: pazartesiden pazara 7 gün', () {
      expect(haftaTarihleri('2026-10-26'), [
        '2026-10-26',
        '2026-10-27',
        '2026-10-28',
        '2026-10-29',
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
      ]);
      expect(haftaTarihleri('bozuk'), isEmpty);
    });

    test('haftaAraligi ve gunTarihEtiketi', () {
      expect(haftaAraligi('2026-11-02'), '2 – 8 Kasım');
      expect(haftaAraligi('2026-10-26'), '26 Ekim – 1 Kasım');
      expect(haftaAraligi('2026-12-28'), '28 Aralık – 3 Ocak');
      expect(gunTarihEtiketi('2026-10-02'), 'Cuma 2 Ekim');
      expect(gunTarihEtiketi('bozuk'), 'bozuk');
    });

    test('oncekiHaftaVar / sonrakiHaftaVar menü aralığıyla sınırlıdır', () {
      final m = _menu(); // 28 Ekim - 12 Kasım
      expect(oncekiHaftaVar(m, '2026-10-26'), isFalse);
      expect(oncekiHaftaVar(m, '2026-11-02'), isTrue);
      expect(oncekiHaftaVar(m, '2026-11-09'), isTrue);
      expect(sonrakiHaftaVar(m, '2026-10-26'), isTrue);
      expect(sonrakiHaftaVar(m, '2026-11-02'), isTrue);
      expect(sonrakiHaftaVar(m, '2026-11-09'), isFalse);
      // menü bütünüyle başka haftalardaysa
      expect(oncekiHaftaVar(m, '2026-10-19'), isFalse);
      expect(sonrakiHaftaVar(m, '2026-11-16'), isFalse);
      // boş menüde ikisi de kapalı
      final bos = Menu('x', null, {});
      expect(oncekiHaftaVar(bos, '2026-11-02'), isFalse);
      expect(sonrakiHaftaVar(bos, '2026-11-02'), isFalse);
    });

    test('haftaGunleri: menü, tatil, öğün yok, yayınlanmadı ve hafta sonu', () {
      final g = haftaGunleri(_menu(), '2026-11-02', 'lunch');
      expect(g.map((x) => x.tarih).toList(), [
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
        '2026-11-06',
        '2026-11-07',
        '2026-11-08',
      ]);
      expect(g.map((x) => x.durum).toList(), [
        HaftaDurumu.menu,
        HaftaDurumu.menu,
        HaftaDurumu.menu,
        HaftaDurumu.tatil, // öğle ve akşam notlu boş
        HaftaDurumu.ogunYok, // yalnızca akşam var
        HaftaDurumu.hizmetYok, // cumartesi, veri yok
        HaftaDurumu.hizmetYok, // pazar, veri yok
      ]);
      expect(g[0].yemekler.length, 5);
      expect(g[0].kcal, 1200);
      expect(g[1].kcal, isNull); // kalori bilinmiyor
      expect(g[3].not, 'Tatil');
      expect(g[3].mesaj, 'Tatil');
      expect(g[4].mesaj, 'Bu öğün için menü yok');
      expect(g[5].mesaj, 'Menü yok');
      expect(g.map((x) => x.veriVar).toList(),
          [true, true, true, true, true, false, false]);
    });

    test('haftaGunleri: menü başlamadan önceki hafta içi gün "yayınlanmadı"',
        () {
      final g = haftaGunleri(_menu(), '2026-10-26', 'lunch');
      expect(g[0].durum, HaftaDurumu.yayinlanmadi); // pazartesi
      expect(g[0].mesaj, 'Menü yayınlanmadı');
      expect(g[0].veriVar, isFalse);
      expect(g[3].durum, HaftaDurumu.tatil);
      expect(g[3].mesaj, '29 Ekim Cumhuriyet Bayramı');
      expect(g[5].durum, HaftaDurumu.hizmetYok); // 31 Ekim cumartesi
    });

    test(
        'haftaGunleri: hafta sonu verisi varsa gösterilir; notsuz boş gün "Menü yok"',
        () {
      final m = Menu('x', null, {
        '2026-11-07': {
          'lunch': Ogun([_y('Çorba')], 100)
        },
        '2026-11-03': {'lunch': Ogun(const [], null)},
      });
      final g = haftaGunleri(m, '2026-11-02', 'lunch');
      expect(g[5].durum, HaftaDurumu.menu); // cumartesi yemekli
      expect(g[1].durum, HaftaDurumu.tatil);
      expect(g[1].mesaj, 'Menü yok');
      expect(g[0].durum, HaftaDurumu.yayinlanmadi);
    });

    test('haftaGunleri: sıfır ya da boş notlu kalori / not yok sayılır', () {
      final m = Menu('x', null, {
        '2026-11-02': {
          'lunch': Ogun([_y('Çorba')], 0, null, false, '   ')
        },
      });
      final gun = haftaGunleri(m, '2026-11-02', 'lunch').first;
      expect(gun.kcal, isNull);
      expect(gun.not, isNull);
    });

    test('haftaYemekleri: ilk 4 yemek, kalanın sayısı', () {
      final ogeler = [for (final a in 'ABCDEF'.split('')) _y(a)];
      final r = haftaYemekleri(ogeler, {});
      expect(r.gorunen.map((o) => o.ad).toList(), ['A', 'B', 'C', 'D']);
      expect(r.gizli, 2);
      final az = haftaYemekleri(ogeler.take(4).toList(), {});
      expect(az.gorunen.length, 4);
      expect(az.gizli, 0);
      expect(haftaYemekleri(const [], {}).gorunen, isEmpty);
    });

    test('haftaYemekleri: 4. yemekten sonraki favori gizlenmez', () {
      final ogeler = [
        for (final a in 'ABCDE'.split('')) _y(a),
        _y('F', null, 'f'),
      ];
      final r = haftaYemekleri(ogeler, {'f'});
      expect(r.gorunen.map((o) => o.ad).toList(), ['A', 'B', 'C', 'D', 'F']);
      expect(r.gizli, 1); // yalnızca E gizli
      // anahtarsız yemek favori sayılmaz
      expect(haftaYemekleri(ogeler, {'x'}).gizli, 2);
    });

    test('haftaYemekleri: adı boş öğe sayılmaz', () {
      final r = haftaYemekleri([_y('A'), _y('  '), _y('B')], {});
      expect(r.gorunen.map((o) => o.ad).toList(), ['A', 'B']);
      expect(r.gizli, 0);
    });
  });

  group('haftalık menü sayfası', () {
    testWidgets('haftanın 7 günü kart olarak görünür; bugün rozetli',
        (t) async {
      await _ac(t);
      expect(find.byType(HaftaSayfasi), findsOneWidget);
      expect(find.text('Haftalık menü'), findsOneWidget); // üst çubuk
      expect(find.text('2 – 8 Kasım'), findsOneWidget);
      expect(find.text('Öğle · Ankara Üniversitesi'), findsOneWidget);
      for (final (tarih, baslik) in [
        ('2026-11-02', 'Pazartesi 2 Kasım'),
        ('2026-11-03', 'Salı 3 Kasım'),
        ('2026-11-04', 'Çarşamba 4 Kasım'),
        ('2026-11-05', 'Perşembe 5 Kasım'),
        ('2026-11-06', 'Cuma 6 Kasım'),
        ('2026-11-07', 'Cumartesi 7 Kasım'),
        ('2026-11-08', 'Pazar 8 Kasım'),
      ]) {
        expect(_kartta(tarih, find.text(baslik)), findsOneWidget,
            reason: baslik);
      }
      expect(find.text('Bugün'), findsOneWidget);
      expect(_kartta('2026-11-04', find.text('Bugün')), findsOneWidget);
    });

    testWidgets('yemekler virgüllü (ilk 4 + "+N") ve toplam kalori görünür',
        (t) async {
      await _ac(t);
      expect(_yemekMetni(t, '2026-11-02'),
          'Mercimek Çorbası, Tavuk Sote, Pirinç Pilavı, Cacık +1');
      expect(
          _kartta('2026-11-02', find.text('Toplam 1200 kkal')), findsOneWidget);
      expect(_yemekMetni(t, '2026-11-03'), 'Ezogelin Çorbası, Tavuk Sote');
      expect(_kartta('2026-11-03', find.textContaining('Toplam')),
          findsNothing); // kalori bilinmiyor
      expect(
          _kartta('2026-11-04', find.text('Toplam 530 kkal')), findsOneWidget);
    });

    testWidgets('tatil notu, "Bu öğün için menü yok" ve hafta sonu "Menü yok"',
        (t) async {
      await _ac(t);
      expect(_kartta('2026-11-05', find.text('Tatil')), findsOneWidget);
      expect(_kartta('2026-11-06', find.text('Bu öğün için menü yok')),
          findsOneWidget);
      expect(find.text('Menü yok'), findsNWidgets(2));
      expect(_kartta('2026-11-07', find.text('Menü yok')), findsOneWidget);
      expect(_kartta('2026-11-08', find.text('Menü yok')), findsOneWidget);
    });

    testWidgets('favori yemek kalp ve kalın yazıyla öne çıkar', (t) async {
      final anlam = t.ensureSemantics();
      final favoriler = FavoriDeposu();
      addTearDown(favoriler.dispose);
      await favoriler.ekle('manti', 'Mantı');
      await _ac(t, favoriler: favoriler);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(
          _kartta('2026-11-04', find.byIcon(Icons.favorite)), findsOneWidget);
      final yazi = t.widget<Text>(_kartta('2026-11-04',
          find.byWidgetPredicate((w) => w is Text && w.textSpan != null)));
      final yemekler = (yazi.textSpan! as TextSpan)
          .children!
          .whereType<TextSpan>()
          .where((s) => s.text == 'Mantı' || s.text == 'Cacık')
          .toList();
      expect(yemekler.map((s) => s.text).toList(), ['Mantı', 'Cacık']);
      expect(yemekler[0].style?.fontWeight, FontWeight.w800);
      expect(yemekler[1].style?.fontWeight, isNull); // favori değil
      // ekran okuyucu kartı tek cümlede okur ve favoriyi söyler
      expect(
          find.bySemanticsLabel(RegExp(
              r'^Bugün, Çarşamba 4 Kasım\. Mantı \(favori\), Cacık\. Toplam 530 kkal$')),
          findsOneWidget);
      anlam.dispose(); // test bitmeden kapatılmalı
    });

    testWidgets(
        '4. yemekten sonraki favori de görünür, +N yalnızca gizlenenleri sayar',
        (t) async {
      final favoriler = FavoriDeposu();
      addTearDown(favoriler.dispose);
      await favoriler.ekle('f', 'F');
      final menu = Menu('ankara', null, {
        '2026-11-04': {
          'lunch': Ogun([
            for (final a in 'ABCDE'.split('')) _y(a),
            _y('F', null, 'f'),
          ], null)
        },
      });
      await _ac(t, menu: menu, favoriler: favoriler);
      expect(_yemekMetni(t, '2026-11-04'), 'A, B, C, D, F +1');
      expect(
          _kartta('2026-11-04', find.byIcon(Icons.favorite)), findsOneWidget);
    });

    testWidgets('oklar menü aralığıyla sınırlıdır ve haftayı değiştirir',
        (t) async {
      await _ac(t);
      expect(_acik(t, Icons.chevron_left), isTrue);
      expect(_acik(t, Icons.chevron_right), isTrue);

      await t.tap(find.byTooltip('Sonraki hafta'));
      await t.pumpAndSettle();
      expect(find.text('9 – 15 Kasım'), findsOneWidget);
      expect(_yemekMetni(t, '2026-11-09'), 'Domates Çorbası');
      expect(_yemekMetni(t, '2026-11-12'), 'Yayla Çorbası');
      expect(_kartta('2026-11-10', find.text('Menü yayınlanmadı')),
          findsOneWidget);
      expect(find.text('Bugün'), findsNothing); // bugün bu haftada değil
      expect(
          _acik(t, Icons.chevron_right), isFalse); // menü 12 Kasım'da bitiyor

      await t.tap(find.byTooltip('Önceki hafta'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Önceki hafta'));
      await t.pumpAndSettle();
      expect(find.text('26 Ekim – 1 Kasım'), findsOneWidget);
      expect(_acik(t, Icons.chevron_left), isFalse); // menü 28 Ekim'de başlıyor
      expect(_acik(t, Icons.chevron_right), isTrue);
    });

    testWidgets(
        'menü başlamadan önceki günler, tatil notu ve ay sonu hafta sonu',
        (t) async {
      await _ac(t, tarih: '2026-10-29');
      expect(find.text('26 Ekim – 1 Kasım'), findsOneWidget);
      expect(_kartta('2026-10-26', find.text('Menü yayınlanmadı')),
          findsOneWidget);
      expect(_kartta('2026-10-27', find.text('Menü yayınlanmadı')),
          findsOneWidget);
      expect(_yemekMetni(t, '2026-10-28'), 'Kuru Fasulye');
      expect(_kartta('2026-10-29', find.text('29 Ekim Cumhuriyet Bayramı')),
          findsOneWidget);
      expect(_yemekMetni(t, '2026-10-30'), 'Pilav');
      expect(find.text('Menü yok'), findsNWidgets(2)); // 31 Ekim, 1 Kasım
    });

    testWidgets(
        'başlangıç haftası seçili günün haftasıdır (pazar ve ertesi pazartesi)',
        (t) async {
      await _ac(t, tarih: '2026-11-08');
      expect(find.text('2 – 8 Kasım'), findsOneWidget);
    });

    testWidgets('pazartesi seçiliyken o haftayla açılır', (t) async {
      await _ac(t, tarih: '2026-11-09');
      expect(find.text('9 – 15 Kasım'), findsOneWidget);
    });

    testWidgets('karta dokununca sayfa o günün tarihiyle kapanır', (t) async {
      final donenler = <String?>[];
      await _ac(t, donenler: donenler);
      await t.tap(_kart('2026-11-03'));
      await t.pumpAndSettle();
      expect(donenler, ['2026-11-03']);
      expect(find.byType(HaftaSayfasi), findsNothing);
    });

    testWidgets(
        'menü aralığı dışındaki kart dokunulmaz, aralıktaki boş gün dokunulur',
        (t) async {
      final donenler = <String?>[];
      await _ac(t, tarih: '2026-10-29', donenler: donenler);
      await t.tap(_kart('2026-10-26')); // menü 28 Ekim'de başlıyor
      await t.pumpAndSettle();
      expect(find.byType(HaftaSayfasi), findsOneWidget);
      expect(donenler, isEmpty);
      await t.tap(_kart('2026-10-31')); // aralık içinde, yemeksiz cumartesi
      await t.pumpAndSettle();
      expect(donenler, ['2026-10-31']);
    });

    testWidgets('öğün akşamsa akşam yemekleri gösterilir', (t) async {
      await _ac(t, ogun: 'dinner');
      expect(find.text('Akşam · Ankara Üniversitesi'), findsOneWidget);
      expect(_yemekMetni(t, '2026-11-02'), 'Fırın Makarna');
      expect(_yemekMetni(t, '2026-11-06'), 'Fırın Makarna');
      expect(_kartta('2026-11-03', find.text('Bu öğün için menü yok')),
          findsOneWidget);
      expect(_kartta('2026-11-05', find.text('Tatil')), findsOneWidget);
    });

    testWidgets(
        'hafta sonu yemekli bir menüde hafta sonu kartı yemekleri gösterir',
        (t) async {
      final menu = Menu('ankara', null, {
        '2026-11-02': {
          'lunch': Ogun([_y('Çorba')], 100)
        },
        '2026-11-07': {
          'lunch': Ogun([_y('Cumartesi Çorbası')], 100)
        },
      });
      await _ac(t, menu: menu);
      expect(_yemekMetni(t, '2026-11-07'), 'Cumartesi Çorbası');
      expect(find.text('Menü yok'), findsOneWidget); // yalnızca pazar
    });

    testWidgets('Haftayı paylaş açık haftanın metnini servise verir',
        (t) async {
      final servis = SahtePaylasim();
      await _ac(t, paylasim: servis);
      await t.tap(find.byTooltip('Haftayı paylaş'));
      await t.pumpAndSettle();
      final beklenen = haftaMetni(_uni(), _menu(), '2026-11-02', 'lunch');
      expect(
          servis.cagrilar, [(beklenen, 'Ankara Üniversitesi haftalık menü')]);
      expect(
          beklenen,
          startsWith('Ankara Üniversitesi · 2 – 8 Kasım\n'
              'Öğle (11:00-14:00) · Öğrenci 50 ₺\n\n'
              'Pazartesi 2 Kasım\n'
              '• Mercimek Çorbası\n'));
      expect(find.byType(SnackBar), findsNothing);

      // sonraki haftada o haftanın metni paylaşılır
      await t.tap(find.byTooltip('Sonraki hafta'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Haftayı paylaş'));
      await t.pumpAndSettle();
      expect(servis.cagrilar.length, 2);
      expect(servis.cagrilar.last.$1,
          startsWith('Ankara Üniversitesi · 9 – 15 Kasım\n'));
    });

    testWidgets(
        'paylaşım açılamazsa hafta metni panoya kopyalanır ve bildirim çıkar',
        (t) async {
      final pano = _panoyuDinle(t);
      final servis = SahtePaylasim()..hata = Exception('desteklenmiyor');
      await _ac(t, paylasim: servis);
      await t.tap(find.byTooltip('Haftayı paylaş'));
      await t.pumpAndSettle();
      expect(servis.cagrilar.length, 1);
      expect(pano, [haftaMetni(_uni(), _menu(), '2026-11-02', 'lunch')]);
      expect(find.text('Paylaşım açılamadı, menü panoya kopyalandı'),
          findsOneWidget);
    });

    testWidgets(
        'menüsü olmayan haftada paylaş pasiftir, kartlar açıklama yazar',
        (t) async {
      await _ac(t, tarih: '2026-12-14');
      expect(find.text('14 – 20 Aralık'), findsOneWidget);
      expect(
          t
              .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.share_outlined))
              .onPressed,
          isNull);
      expect(_acik(t, Icons.chevron_left), isTrue); // menü daha önce başlıyor
      expect(_acik(t, Icons.chevron_right), isFalse);
      expect(find.text('Menü yayınlanmadı'), findsNWidgets(5));
      expect(find.text('Menü yok'), findsNWidgets(2));
    });

    testWidgets('hafta değişince eski liste solarak çıkar', (t) async {
      await _ac(t);
      await t.tap(find.byTooltip('Sonraki hafta'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(_kart('2026-11-09'), findsOneWidget); // yeni
      expect(
          _kart('2026-11-02'), findsOneWidget); // eskisi hâlâ solarak çıkıyor
      await t.pumpAndSettle();
      expect(_kart('2026-11-02'), findsNothing);
    });

    testWidgets('hareket kapalıyken eski hafta hemen kalkar', (t) async {
      await _ac(t, hareketKapali: true);
      await t.tap(find.byTooltip('Sonraki hafta'));
      await t.pump();
      await t.pump();
      expect(_kart('2026-11-09'), findsOneWidget);
      expect(_kart('2026-11-02'), findsNothing);
    });

    for (final olcek in [1.0, 1.5]) {
      testWidgets(
          '320x640, yazı ${olcek}x, uzun adlar: taşma yok, oklar ve paylaş 48dp',
          (t) async {
        const uzun =
            'Çok Uzun Adlı Kremalı Mantarlı Közlenmiş Patlıcanlı Tavuk Sote Spesiyal Yemeği';
        final favoriler = FavoriDeposu();
        addTearDown(favoriler.dispose);
        await favoriler.ekle('u1', uzun);
        final menu = Menu('ankara', null, {
          '2026-11-02': {
            'lunch': Ogun([
              _y(uzun, 1234, 'u1'),
              _y('$uzun Ikinci', 100, 'u2'),
              _y('Mercimek Çorbası'),
              _y('Pirinç Pilavı'),
              _y('Cacık'),
            ], 1654)
          },
          '2026-11-03': {
            'lunch': _notlu(
                'Okulun yönetim kurulu kararıyla bu gün yemekhane hizmeti verilmemektedir')
          },
          '2026-11-04': {
            'lunch': Ogun([_y('Mantı', 450, 'manti')], 450)
          },
          '2026-11-09': {
            'lunch': Ogun([_y('Domates Çorbası', 90)], 90)
          },
        });
        await _ac(t,
            menu: menu,
            uni: _uni(
                ad: 'Ankara Hacı Bayram Veli Sağlık Bilimleri ve Teknoloji Üniversitesi'),
            favoriler: favoriler,
            boyut: const Size(320, 640),
            yaziOlcegi: olcek);
        expect(t.takeException(), isNull);
        for (final ikon in [
          Icons.chevron_left,
          Icons.chevron_right,
          Icons.share_outlined
        ]) {
          final boyut = t.getSize(find.widgetWithIcon(IconButton, ikon));
          expect(boyut.width, greaterThanOrEqualTo(48), reason: '$ikon');
          expect(boyut.height, greaterThanOrEqualTo(48), reason: '$ikon');
        }
        // liste tembel kurulur: kartlar sırayla kaydırılarak gezilir; hepsi ekran genişliğinde kalır
        for (final tarih in [
          '2026-11-02',
          '2026-11-03',
          '2026-11-04',
          '2026-11-05',
          '2026-11-06',
          '2026-11-07',
          '2026-11-08',
        ]) {
          await t.scrollUntilVisible(_kart(tarih), 150);
          await t.pumpAndSettle();
          final r = t.getRect(_kart(tarih));
          expect(r.left, greaterThanOrEqualTo(0), reason: tarih);
          expect(r.right, lessThanOrEqualTo(320), reason: tarih);
          expect(t.takeException(), isNull, reason: tarih);
        }
        await t.tap(find.byTooltip('Sonraki hafta'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('9 – 15 Kasım'), findsOneWidget);
      });
    }

    testWidgets('8 palet x açık / koyu / siyah tema: sayfa hatasız çizilir',
        (t) async {
      for (final palet in temaRenkleri) {
        for (final (parlaklik, amoled) in [
          (Brightness.light, false),
          (Brightness.dark, false),
          (Brightness.dark, true),
        ]) {
          await _ac(t,
              tema: temaUret(palet, parlaklik, amoled: amoled),
              boyut: const Size(320, 640));
          expect(t.takeException(), isNull,
              reason: '${palet.kimlik} $parlaklik amoled=$amoled');
          expect(find.text('Bugün'), findsOneWidget);
          // sayfayı kapat, sonraki temaya geç
          await t.pageBack();
          await t.pumpAndSettle();
        }
      }
    });
  });

  group('ana sayfa: Diğer > Haftalık menü', () {
    Future<_SahteDepo> ac(WidgetTester t,
        {SahtePaylasim? servis,
        FavoriDeposu? favoriler,
        Size boyut = const Size(400, 900),
        double yaziOlcegi = 1.0,
        DateTime? simdi}) async {
      final depo = _SahteDepo([_uni()], {'ankara': _menu()}, secili: 'ankara');
      t.view.physicalSize = boyut;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final ayar = TemaAyari();
      await t.pumpWidget(MaterialApp(
        theme: ayar.tema(Brightness.light),
        builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(yaziOlcegi)),
            child: w!),
        home: AnaSayfa(
            temaAyari: ayar,
            depo: depo,
            geriBildirim: YerelDepo(),
            favoriler: favoriler,
            paylasim: servis ?? SahtePaylasim(),
            // 4 Kasım 2026 çarşamba, saat 10:00 (Türkiye duvar saati): öğle seçilir
            simdi: () => simdi ?? DateTime.utc(2026, 11, 4, 10, 0)),
      ));
      await t.pumpAndSettle();
      return depo;
    }

    Future<void> haftayiAc(WidgetTester t) async {
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Haftalık menü'));
      await t.pumpAndSettle();
    }

    testWidgets('seçili günün haftasını ve öğününü açar', (t) async {
      await ac(t);
      await haftayiAc(t);
      expect(find.byType(HaftaSayfasi), findsOneWidget);
      expect(find.text('2 – 8 Kasım'), findsOneWidget);
      expect(find.text('Öğle · Ankara Üniversitesi'), findsOneWidget);
      expect(_kartta('2026-11-04', find.text('Bugün')), findsOneWidget);
    });

    testWidgets('başka haftadaki bir gün seçiliyken o haftayı açar', (t) async {
      await ac(t);
      for (var i = 0; i < 5; i++) {
        await t.tap(find.byTooltip('Sonraki gün')); // 5, 6, 7, 8, 9 Kasım
        await t.pumpAndSettle();
      }
      await haftayiAc(t);
      expect(find.text('9 – 15 Kasım'), findsOneWidget);
      expect(find.text('Bugün'), findsNothing);
    });

    testWidgets('Akşam sekmesi seçiliyken akşam yemeklerini gösterir',
        (t) async {
      await ac(t);
      await t.tap(find.text('Akşam'));
      await t.pumpAndSettle();
      await haftayiAc(t);
      expect(find.text('Akşam · Ankara Üniversitesi'), findsOneWidget);
      expect(_yemekMetni(t, '2026-11-02'), 'Fırın Makarna');
    });

    testWidgets('bir karta dokununca ana sayfa o güne geçer', (t) async {
      await ac(t);
      await haftayiAc(t);
      await t.tap(_kart('2026-11-05')); // perşembe: tatil
      await t.pumpAndSettle();
      expect(find.byType(HaftaSayfasi), findsNothing);
      expect(find.text('Yarın'), findsOneWidget); // 5 Kasım, bugün 4 Kasım
      expect(find.text('Tatil'), findsOneWidget);
      expect(find.text('Bu gün yemekhane hizmeti verilmiyor.'), findsOneWidget);
    });

    testWidgets(
        'geçmiş bir gün kartı da ana sayfayı o güne götürür; gün çubuğu uzar',
        (t) async {
      await ac(t);
      await haftayiAc(t);
      await t.tap(_kart('2026-11-02')); // bugünden önceki pazartesi
      await t.pumpAndSettle();
      expect(find.byType(HaftaSayfasi), findsNothing);
      expect(find.text('Pazartesi'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      // ileri gidilebilir (gün çubuğu menünün ilk gününe uzadı)
      expect(
          t
              .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.chevron_right))
              .onPressed,
          isNotNull);
    });

    testWidgets('favoriler haftalık menüye taşınır', (t) async {
      final favoriler = FavoriDeposu();
      addTearDown(favoriler.dispose);
      await favoriler.ekle('manti', 'Mantı');
      await ac(t, favoriler: favoriler);
      await haftayiAc(t);
      expect(
          _kartta('2026-11-04', find.byIcon(Icons.favorite)), findsOneWidget);
    });

    testWidgets('haftalık menüden paylaşım ana sayfanın servisini kullanır',
        (t) async {
      final servis = SahtePaylasim();
      await ac(t, servis: servis);
      await haftayiAc(t);
      await t.tap(find.byTooltip('Haftayı paylaş'));
      await t.pumpAndSettle();
      expect(servis.cagrilar.single.$1,
          startsWith('Ankara Üniversitesi · 2 – 8 Kasım\n'));
    });

    for (final olcek in [1.0, 1.5]) {
      testWidgets(
          '320x640, yazı ${olcek}x: menü, hafta sayfası ve geri dönüş taşmaz',
          (t) async {
        await ac(t, boyut: const Size(320, 640), yaziOlcegi: olcek);
        await haftayiAc(t);
        expect(t.takeException(), isNull);
        expect(find.byType(HaftaSayfasi), findsOneWidget);
        // büyük yazıda pazartesi kartı uzar; salı kartı ekran dışında kalabilir
        await t.scrollUntilVisible(_kart('2026-11-03'), 150);
        await t.pumpAndSettle(); // kaydırma sonrası yerleşim oturur
        await t.tap(_kart('2026-11-03'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byType(HaftaSayfasi), findsNothing);
        expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      });
    }
  });
}

// ---------------------------------------------------------------------------
// Ana sayfa testleri için sahte veri deposu
// ---------------------------------------------------------------------------

class _SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  String? secili;
  _SahteDepo(this.liste, this.menuVeri, {this.secili});

  @override
  Future<List<Universite>> universiteler() async => liste;
  @override
  Future<Menu> menu(String universiteId) async => menuVeri[universiteId]!;
  @override
  Future<String?> seciliUniversite() async => secili;
  @override
  Future<void> universiteSec(String id) async => secili = id;
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  String? fotoUrl(String universiteId, String? foto) => null;
  @override
  String? yemekFotoUrl(String? img) => null;
}
