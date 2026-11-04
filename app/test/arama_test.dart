import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/arama.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/yemek_ara.dart';
import 'package:yemekhane/tema.dart';

Universite _u(String id, String ad, String kisa, String sehir,
        [List<String> ogunler = const ['lunch', 'dinner']]) =>
    Universite(
        id: id,
        ad: ad,
        kisa: kisa,
        sehir: sehir,
        kaynak: '',
        ogunler: ogunler,
        fiyatlar: const []);

/// tarih -> öğün -> yemek adları. Her yemeğe 100 kkal verilir.
Menu _menu(String uni, Map<String, Map<String, List<String>>> gunler) =>
    Menu(uni, null, {
      for (final g in gunler.entries)
        g.key: {
          for (final o in g.value.entries)
            o.key: Ogun([for (final ad in o.value) YemekOgesi(ad, 100)], null)
        }
    });

/// Ağa ve diske gitmeyen sahte depo: istekleri sayar, okul bazında hata atar ya da bekletir.
class _Depo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> veri;
  final Set<String> hataIdler = {};
  final Map<String, Completer<void>> kapilar = {};
  final List<String> istekler = [];
  String? secili;
  _Depo(this.liste, this.veri, {this.secili});

  @override
  Future<List<Universite>> universiteler() async => liste;

  @override
  Future<Menu> menu(String universiteId) async {
    istekler.add(universiteId);
    final kapi = kapilar[universiteId];
    if (kapi != null) await kapi.future;
    if (hataIdler.contains(universiteId)) throw Exception('ağ yok');
    return veri[universiteId]!;
  }

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

const _bugun = '2026-11-02'; // Pazartesi

final _ankara = _u('ankara', 'Ankara Üniversitesi', 'AÜ', 'Ankara');
final _gazi = _u('gazi', 'Gazi Üniversitesi', 'GÜ', 'Ankara');
final _odtu = _u('odtu', 'Orta Doğu Teknik Üniversitesi', 'ODTÜ', 'Ankara');
final _istanbul = _u('istanbul', 'İstanbul Üniversitesi', 'İÜ', 'İstanbul');
final _karabuk = _u('karabuk', 'Karabük Üniversitesi', 'KBÜ', 'Karabük');

_Depo _depo({String? secili}) => _Depo([
      _ankara,
      _gazi,
      _odtu,
      _istanbul,
      _karabuk
    ], {
      'ankara': _menu('ankara', {
        '2026-11-02': {
          'lunch': ['Mercimek Çorbası', 'Pirinç Pilavı'],
          'dinner': ['Fırın Makarna'],
        },
        '2026-11-03': {
          'lunch': ['Ezogelin Çorbası', 'Pirinç Pilavı'],
        },
        '2026-11-06': {
          'lunch': ['Mantı'],
        },
      }),
      'gazi': _menu('gazi', {
        '2026-11-02': {
          'lunch': ['Mercimek Çorbası'],
        },
        '2026-11-04': {
          'dinner': ['Gazi Etli Nohut'],
        },
      }),
      'odtu': _menu('odtu', {
        '2026-11-02': {
          'lunch': ['Domates Çorbası'],
        },
      }),
      'istanbul': _menu('istanbul', {
        '2026-11-03': {
          'lunch': ['Mantı'],
        },
      }),
      'karabuk': _menu('karabuk', {
        '2026-11-02': {
          'lunch': ['Karabük Çorbası'],
        },
      }),
    }, secili: secili);

List<AramaSonucu> _donen = [];

/// Arama sayfasını bir düğmeyle açar; sayfanın pop ile döndürdüğü değer [_donen]e eklenir.
Future<void> _sayfaAc(WidgetTester t, _Depo depo,
    {Universite? uni,
    Size boyut = const Size(400, 800),
    double yaziOlcegi = 1.0,
    bool bekle = true}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _donen = [];
  final u = uni ?? _ankara;
  await t.pumpWidget(MaterialApp(
    theme: TemaAyari().tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c)
            .copyWith(textScaler: TextScaler.linear(yaziOlcegi)),
        child: w!),
    home: Builder(
        builder: (c) => Scaffold(
            body: Center(
                child: FilledButton(
                    onPressed: () async {
                      final s = await Navigator.of(c).push<AramaSonucu>(
                          MaterialPageRoute(
                              builder: (_) => YemekAraSayfasi(
                                  depo: depo,
                                  uniler: depo.liste,
                                  uni: u,
                                  menu: depo.veri[u.id],
                                  bugun: _bugun)));
                      if (s != null) _donen.add(s);
                    },
                    child: const Text('Aç'))))),
  ));
  await t.tap(find.text('Aç'));
  if (bekle) await t.pumpAndSettle();
}

Future<void> _yaz(WidgetTester t, String s) async {
  await t.enterText(find.byType(TextField), s);
  await t.pump(const Duration(milliseconds: 300)); // 250 ms bekleme sonrası
  await t.pumpAndSettle();
}

/// Sonuç satırları: "yemek | okul · öğün" (başlıklar "# Bugün" olarak araya girer).
List<String> _satirlar(WidgetTester t) {
  final sonuc = <String>[];
  for (final l in t.widgetList<ListTile>(find.byType(ListTile))) {
    sonuc.add('${(l.title as Text).data} | ${(l.subtitle as Text).data}');
  }
  return sonuc;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sadeTr', () {
    test('aksan ve büyük harf farkını siler', () {
      expect(sadeTr('ÇIĞ KÖFTE ŞİŞ ÜZÜM İZMİR IRMIK'),
          'cig kofte sis uzum izmir irmik');
      expect(sadeTr('Mercimek Çorbası'), 'mercimek corbasi');
      expect(sadeTr('mercimek corbasi'), 'mercimek corbasi');
      expect(sadeTr('Kâğıt Kebabı'), 'kagit kebabi');
      expect(sadeTr(''), '');
    });

    test('kucukTr ile uyumlu: büyük I -> ı -> i, büyük İ -> i', () {
      expect(sadeTr('ISPARTA'), 'isparta');
      expect(sadeTr('İSTANBUL'), 'istanbul');
      expect(sadeTr('Işık'), 'isik');
    });
  });

  group('yemekAra', () {
    final menuler = {
      _ankara: _menu('ankara', {
        '2026-11-01': {
          'lunch': ['Eski Çorba']
        },
        '2026-11-02': {
          'lunch': ['Mercimek Çorbası', 'Pirinç Pilavı'],
          'dinner': ['Fırın Makarna'],
        },
        '2026-11-03': {
          'lunch': ['Ezogelin Çorbası'],
        },
      }),
    };

    test('sorgu en az 2 harf olmalı', () {
      expect(yemekAra(menuler, '', _bugun), isEmpty);
      expect(yemekAra(menuler, 'c', _bugun), isEmpty);
      expect(yemekAra(menuler, '  c  ', _bugun), isEmpty);
      expect(yemekAra(menuler, 'co', _bugun), isNotEmpty);
      expect(aramaSorgusuGecerli(' a '), isFalse);
      expect(aramaSorgusuGecerli(' ab '), isTrue);
    });

    test('aksanlı, aksansız ve büyük harfli sorgu aynı sonucu verir', () {
      for (final q in ['çorba', 'corba', 'ÇORBA', 'CORBA', 'Çorba ']) {
        final r = yemekAra(menuler, q, _bugun);
        expect(r.map((s) => s.ad), ['Mercimek Çorbası', 'Ezogelin Çorbası'],
            reason: q);
      }
    });

    test('kelime içi eşleşme yeterli; sonuç alanları dolu', () {
      final r = yemekAra(menuler, 'ercim', _bugun);
      expect(r, hasLength(1));
      expect(r.single.ad, 'Mercimek Çorbası');
      expect(r.single.okul, _ankara);
      expect(r.single.tarih, '2026-11-02');
      expect(r.single.ogun, 'lunch');
      expect(r.single.kcal, 100);
    });

    test('yemeğin kcal değeri sonuca taşınır', () {
      final r = yemekAra({
        _ankara: Menu('ankara', null, {
          '2026-11-02': {
            'lunch': Ogun([YemekOgesi('Mantı', 612)], null)
          }
        })
      }, 'manti', _bugun);
      expect(r.single.kcal, 612);
    });

    test('bugünden önceki günler çıkmaz; bugün dahildir', () {
      final r = yemekAra(menuler, 'corba', _bugun);
      expect(r.map((s) => s.tarih), ['2026-11-02', '2026-11-03']);
      expect(r.map((s) => s.ad), isNot(contains('Eski Çorba')));
      expect(yemekAra(menuler, 'corba', '2026-11-03').map((s) => s.tarih),
          ['2026-11-03']);
      expect(yemekAra(menuler, 'corba', '2026-11-04'), isEmpty);
    });

    test('önce tarih, sonra okul adı (Türkçe sıra), sonra öğün sırası', () {
      final isparta =
          _u('isparta', 'Isparta Uygulamalı Bilimler', 'ISUBÜ', 'Isparta');
      final istanbul =
          _u('istanbul', 'İstanbul Üniversitesi', 'İÜ', 'İstanbul');
      final cukurova = _u('cukurova', 'Çukurova Üniversitesi', 'ÇÜ', 'Adana');
      final cumhuriyet =
          _u('cumhuriyet', 'Cumhuriyet Üniversitesi', 'CÜ', 'Sivas');
      final dokuz = _u('dokuz', 'Dokuz Eylül Üniversitesi', 'DEÜ', 'İzmir');
      // öğünler bilerek ters sırada eklenir; tarihler de karışık
      Menu m(String id) => _menu(id, {
            '2026-11-04': {
              'dinner': ['Pilav'],
              'breakfast': ['Pilav'],
              'vegetarian': ['Pilav'],
              'lunch': ['Pilav'],
            },
            '2026-11-03': {
              'lunch': ['Pilav']
            },
          });
      final r = yemekAra({
        dokuz: m('dokuz'),
        istanbul: m('istanbul'),
        cukurova: m('cukurova'),
        isparta: m('isparta'),
        cumhuriyet: m('cumhuriyet'),
      }, 'pilav', _bugun);
      final tr = [
        'Cumhuriyet', // c < ç < d
        'Çukurova',
        'Dokuz',
        'Isparta', // ı < i
        'İstanbul',
      ];
      expect(r.take(5).map((s) => s.tarih).toSet(), {'2026-11-03'});
      expect(r.take(5).map((s) => s.okul.ad.split(' ').first), tr);
      // 4 Kasım: her okulda kahvaltı, öğle, akşam, vejetaryen sırası
      final dort = r.skip(5).toList();
      expect(dort.first.okul.ad.split(' ').first, 'Cumhuriyet');
      expect(dort.take(4).map((s) => s.ogun),
          ['breakfast', 'lunch', 'dinner', 'vegetarian']);
      expect(dort.skip(4).first.okul.ad.split(' ').first, 'Çukurova');
    });

    test('aynı öğünde aynı yemek iki kez yazılmışsa tek satır olur', () {
      final r = yemekAra({
        _ankara: _menu('ankara', {
          '2026-11-02': {
            'lunch': ['Mantı', 'Mantı'],
            'dinner': ['Mantı'],
          }
        })
      }, 'manti', _bugun);
      expect(r.map((s) => s.ogun), ['lunch', 'dinner']);
    });

    test('tatil / boş öğünler ve eşleşmeyenler sonuç vermez', () {
      final r = yemekAra({
        _ankara: Menu('ankara', null, {
          '2026-11-02': {'lunch': Ogun([], null, null, false, 'Tatil')}
        })
      }, 'tatil', _bugun);
      expect(r, isEmpty);
      expect(yemekAra(menuler, 'zzz', _bugun), isEmpty);
      expect(yemekAra({}, 'corba', _bugun), isEmpty);
    });

    test('en çok 200 sonuç döner, en erken tarihliler korunur', () {
      final gunler = <String, Map<String, List<String>>>{};
      for (var i = 0; i < 150; i++) {
        final tarih = isoTarih(DateTime.utc(2026, 11, 2 + i));
        gunler[tarih] = {
          'lunch': ['Tavuk Sote'],
          'dinner': ['Tavuk Şiş'],
        };
      }
      final r = yemekAra({_ankara: _menu('ankara', gunler)}, 'tavuk', _bugun);
      expect(r, hasLength(aramaEnCok));
      expect(aramaEnCok, 200);
      expect(r.first.tarih, '2026-11-02');
      expect(r.last.tarih, isoTarih(DateTime.utc(2026, 11, 2 + 99)));
      expect(r.last.ogun, 'dinner');
    });
  });

  group('Depo.menuler', () {
    test('paralel yükler; tek hata diğerlerini düşürmez, sıra korunur',
        () async {
      final depo = _depo()..hataIdler.add('gazi');
      final bitenler = <String>[];
      final r = await depo.menuler(
          ['ankara', 'gazi', 'yok_okul', 'odtu', 'ankara'],
          biten: (id, m) => bitenler.add('$id:${m != null}'));
      expect(r.keys, ['ankara', 'gazi', 'yok_okul', 'odtu']);
      expect(r['ankara'], isNotNull);
      expect(r['gazi'], isNull); // hata attı
      expect(r['yok_okul'], isNull); // sahte depoda yok
      expect(r['odtu'], isNotNull);
      expect(bitenler, hasLength(4));
      expect(bitenler, containsAll(['ankara:true', 'gazi:false', 'odtu:true']));
      expect(depo.istekler.where((i) => i == 'ankara'), hasLength(1));
    });

    test('hepsi birlikte başlar: kapılar açılana kadar hiçbiri bitmez',
        () async {
      final depo = _depo();
      depo.kapilar['gazi'] = Completer<void>();
      depo.kapilar['odtu'] = Completer<void>();
      var bitti = false;
      final f = depo.menuler(['gazi', 'odtu']).then((_) => bitti = true);
      await Future<void>.delayed(Duration.zero);
      expect(depo.istekler, ['gazi', 'odtu']); // ikisi de hemen istendi
      expect(bitti, isFalse);
      depo.kapilar['odtu']!.complete();
      depo.kapilar['gazi']!.complete();
      await f;
      expect(bitti, isTrue);
    });

    test('boş liste boş sonuç verir; dinleyici hatası yüklemeyi bozmaz',
        () async {
      expect(await _depo().menuler([]), isEmpty);
      final r = await _depo().menuler(['ankara', 'gazi'],
          biten: (id, m) => throw StateError('dinleyici hatası'));
      expect(r.values.every((m) => m != null), isTrue);
    });

    testWidgets('gerçek Depo: uygulamayla gelen menü okunur, olmayan okul null',
        (t) async {
      final r = await t.runAsync(() => Depo().menuler(['ankara', 'yok_okul']));
      expect(r!['ankara'], isNotNull);
      expect(r['ankara']!.gunler, isNotEmpty);
      expect(r['yok_okul'], isNull);
    });
  });

  group('arama sayfası', () {
    testWidgets('açılışta yalnızca şehirdeki okullar istenir, yönerge görünür',
        (t) async {
      final depo = _depo();
      await _sayfaAc(t, depo);
      expect(find.text('Şehir: Ankara'), findsOneWidget);
      expect(find.text('Tüm okullar'), findsOneWidget);
      expect(find.text('Aramak için yemek adını yaz'), findsOneWidget);
      // seçili okulun menüsü zaten elde: yeniden istenmez; Ankara'daki diğer iki okul istenir
      expect(depo.istekler.toSet(), {'gazi', 'odtu'});
      final alan = t.widget<TextField>(find.byType(TextField));
      expect(alan.autofocus, isTrue);
    });

    testWidgets('şehirde arama: aksansız yazı, tarih başlıkları, okul ve öğün',
        (t) async {
      await _sayfaAc(t, _depo());
      await _yaz(t, 'corba');
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Yarın'), findsOneWidget);
      expect(_satirlar(t), [
        'Mercimek Çorbası | AÜ · Öğle',
        'Mercimek Çorbası | GÜ · Öğle',
        'Domates Çorbası | ODTÜ · Öğle',
        'Ezogelin Çorbası | AÜ · Öğle',
      ]);
      // başka şehirlerdeki okullar bu kapsamda yok
      expect(find.text('Karabük Çorbası'), findsNothing);
    });

    testWidgets('gün başlığı gün adı ve tarihi içerir ("Cuma 6 Kasım")',
        (t) async {
      await _sayfaAc(t, _depo());
      await _yaz(t, 'MANTI');
      expect(find.text('Cuma 6 Kasım'), findsOneWidget);
      expect(_satirlar(t),
          ['Mantı | AÜ · Öğle']); // İstanbul'daki mantı kapsam dışı
    });

    testWidgets('akşam öğünü satırda "Akşam" olarak yazılır', (t) async {
      await _sayfaAc(t, _depo());
      await _yaz(t, 'nohut');
      expect(find.text('Çarşamba 4 Kasım'), findsOneWidget);
      expect(_satirlar(t), ['Gazi Etli Nohut | GÜ · Akşam']);
    });

    testWidgets('1 harf yazınca sonuç yok, yönerge kalır', (t) async {
      await _sayfaAc(t, _depo());
      await _yaz(t, 'c');
      expect(find.text('Aramak için yemek adını yaz'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('eşleşme yoksa "Sonuç bulunamadı"', (t) async {
      await _sayfaAc(t, _depo());
      await _yaz(t, 'zzzz');
      expect(find.text('Sonuç bulunamadı'), findsOneWidget);
    });

    testWidgets('yazarken 250 ms beklenir (debounce), sonra aranır', (t) async {
      await _sayfaAc(t, _depo());
      await t.enterText(find.byType(TextField), 'corba');
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(ListTile), findsNothing);
      await t.enterText(find.byType(TextField), 'mercimek');
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(ListTile), findsNothing); // sayaç yeniden başladı
      await t.pump(const Duration(milliseconds: 100));
      expect(_satirlar(t), [
        'Mercimek Çorbası | AÜ · Öğle',
        'Mercimek Çorbası | GÜ · Öğle',
      ]);
    });

    testWidgets('Temizle yazıyı siler ve yönergeye döner', (t) async {
      await _sayfaAc(t, _depo());
      expect(find.byTooltip('Temizle'), findsNothing);
      await _yaz(t, 'corba');
      await t.tap(find.byTooltip('Temizle'));
      await t.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(find.text('Aramak için yemek adını yaz'), findsOneWidget);
    });

    testWidgets(
        '"Tüm okullar" seçilince kalan okullar yüklenir, sonuçlar genişler',
        (t) async {
      final depo = _depo();
      await _sayfaAc(t, depo);
      await _yaz(t, 'manti');
      expect(_satirlar(t), ['Mantı | AÜ · Öğle']);
      expect(depo.istekler.toSet(), {'gazi', 'odtu'}); // 38 okulun hepsi değil

      await t.tap(find.text('Tüm okullar'));
      await t.pumpAndSettle();
      expect(depo.istekler.toSet(), {'gazi', 'odtu', 'istanbul', 'karabuk'});
      expect(_satirlar(t), ['Mantı | İÜ · Öğle', 'Mantı | AÜ · Öğle']);
      expect(find.text('Yarın'), findsOneWidget);
      expect(find.text('Cuma 6 Kasım'), findsOneWidget);

      // şehre dönmek yeniden yüklemez
      final onceki = depo.istekler.length;
      await t.tap(find.text('Şehir: Ankara'));
      await t.pumpAndSettle();
      expect(depo.istekler.length, onceki);
      expect(_satirlar(t), ['Mantı | AÜ · Öğle']);
    });

    testWidgets('şehirde tek okul varsa otomatik tüm okullar aranır',
        (t) async {
      final depo = _depo();
      await _sayfaAc(t, depo, uni: _karabuk);
      expect(depo.istekler.toSet(), {'ankara', 'gazi', 'odtu', 'istanbul'});
      expect(
          t
              .widget<ChoiceChip>(
                  find.widgetWithText(ChoiceChip, 'Tüm okullar'))
              .selected,
          isTrue);
      await _yaz(t, 'corba');
      expect(_satirlar(t), contains('Karabük Çorbası | KBÜ · Öğle'));
      expect(_satirlar(t), contains('Mercimek Çorbası | AÜ · Öğle'));
    });

    testWidgets(
        'yüklenirken "N/M okul yüklendi" görünür, sonuçlar geldikçe eklenir',
        (t) async {
      final depo = _depo();
      depo.kapilar['gazi'] = Completer<void>();
      depo.kapilar['odtu'] = Completer<void>();
      await _sayfaAc(t, depo);
      expect(find.text('1/3 okul yüklendi'), findsOneWidget);
      await _yaz(t, 'corba');
      // yalnızca Ankara Üniversitesi elde: kısmi sonuç
      expect(_satirlar(t), [
        'Mercimek Çorbası | AÜ · Öğle',
        'Ezogelin Çorbası | AÜ · Öğle',
      ]);

      depo.kapilar['gazi']!.complete();
      await t.pumpAndSettle();
      expect(find.text('2/3 okul yüklendi'), findsOneWidget);
      expect(_satirlar(t), contains('Mercimek Çorbası | GÜ · Öğle'));

      depo.kapilar['odtu']!.complete();
      await t.pumpAndSettle();
      expect(find.textContaining('okul yüklendi'), findsNothing);
      expect(_satirlar(t), contains('Domates Çorbası | ODTÜ · Öğle'));
    });

    testWidgets('yüklenirken ve sonuç yokken "Sonuç bulunamadı" gösterilmez',
        (t) async {
      final depo = _depo();
      depo.kapilar['gazi'] = Completer<void>();
      depo.kapilar['odtu'] = Completer<void>();
      await _sayfaAc(t, depo);
      await _yaz(t, 'domates'); // yalnızca ODTÜ'de var, henüz gelmedi
      expect(find.text('Sonuç bulunamadı'), findsNothing);
      expect(find.text('Menüler yükleniyor'), findsOneWidget);
      depo.kapilar['gazi']!.complete();
      depo.kapilar['odtu']!.complete();
      await t.pumpAndSettle();
      expect(_satirlar(t), ['Domates Çorbası | ODTÜ · Öğle']);
    });

    testWidgets(
        'kısmi hata: "2 okulun menüsü alınamadı", kalanlar aranır, tekrar dene',
        (t) async {
      final depo = _depo()..hataIdler.addAll({'gazi', 'odtu'});
      await _sayfaAc(t, depo);
      expect(find.text('2 okulun menüsü alınamadı'), findsOneWidget);
      await _yaz(t, 'corba');
      expect(_satirlar(t), [
        'Mercimek Çorbası | AÜ · Öğle',
        'Ezogelin Çorbası | AÜ · Öğle',
      ]);

      depo.hataIdler.remove('odtu');
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(find.text('1 okulun menüsü alınamadı'), findsOneWidget);
      expect(_satirlar(t), contains('Domates Çorbası | ODTÜ · Öğle'));

      depo.hataIdler.clear();
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(find.textContaining('alınamadı'), findsNothing);
      expect(find.text('Tekrar dene'), findsNothing);
      expect(_satirlar(t), contains('Mercimek Çorbası | GÜ · Öğle'));
    });

    testWidgets('hiçbir okul alınamazsa "Menüler alınamadı" yazar', (t) async {
      final depo = _depo()..hataIdler.addAll({'gazi', 'odtu'});
      depo.veri.remove('ankara'); // seçili okulun menüsü de yok
      await _sayfaAc(t, depo);
      await _yaz(t, 'corba');
      expect(find.text('3 okulun menüsü alınamadı'), findsOneWidget);
      expect(find.text('Menüler alınamadı'), findsOneWidget);
      expect(find.text('Sonuç bulunamadı'), findsNothing);
    });

    testWidgets('satıra dokununca (okul, tarih, öğün) ile kapanır', (t) async {
      await _sayfaAc(t, _depo());
      await _yaz(t, 'nohut');
      await t.tap(find.text('Gazi Etli Nohut'));
      await t.pumpAndSettle();
      expect(find.byType(YemekAraSayfasi), findsNothing);
      expect(_donen, hasLength(1));
      expect(_donen.single.okul.id, 'gazi');
      expect(_donen.single.tarih, '2026-11-04');
      expect(_donen.single.ogun, 'dinner');
      expect(_donen.single.ad, 'Gazi Etli Nohut');
    });

    testWidgets('geri dönülürse sonuç döndürülmez', (t) async {
      await _sayfaAc(t, _depo());
      await _yaz(t, 'nohut');
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(YemekAraSayfasi), findsNothing);
      expect(_donen, isEmpty);
    });

    for (final olcek in [1.0, 1.5]) {
      testWidgets(
          '320x640, yazı ${olcek}x: uzun adlarla taşma yok, satırlar >= 48dp',
          (t) async {
        final depo = _depo()..hataIdler.add('odtu');
        depo.veri['ankara']!.gunler['2026-11-02']!['lunch'] = Ogun([
          YemekOgesi(
              'Fırında Baharatlı Tavuk Baget Yanında Soğanlı Pilav ve Közlenmiş Sebze Garnitürü',
              null),
          YemekOgesi('Tavuk Sote', null),
        ], null);
        final uzun = _u(
            'uzun',
            'Ankara Hacı Bayram Veli Sağlık Bilimleri ve Teknoloji Üniversitesi',
            '',
            'Ankara');
        depo.liste.add(uzun);
        depo.veri['uzun'] = _menu('uzun', {
          '2026-11-02': {
            'lunch': ['Tavuk Haşlama']
          }
        });
        await _sayfaAc(t, depo, boyut: const Size(320, 640), yaziOlcegi: olcek);
        expect(t.takeException(), isNull);
        await _yaz(t, 'tavuk');
        expect(t.takeException(), isNull);
        expect(find.text('Tavuk Haşlama'), findsOneWidget);
        expect(find.textContaining('Ankara Hacı Bayram Veli'),
            findsOneWidget); // kısa ad yok: tam ad
        for (final satir in find.byType(ListTile).evaluate()) {
          expect(t.getSize(find.byWidget(satir.widget)).height,
              greaterThanOrEqualTo(48));
        }
        for (final dugme in [
          find.byType(ChoiceChip).first,
          find.byTooltip('Temizle'),
        ]) {
          expect(t.getSize(dugme).height, greaterThanOrEqualTo(40));
        }
        await t.tap(find.text('Tüm okullar'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }

    testWidgets(
        '320x640, yazı 1.5x, klavye açık (300 dp): hata satırı ve sonuçlarla taşma yok',
        (t) async {
      final depo = _depo()..hataIdler.addAll({'gazi', 'odtu'});
      await _sayfaAc(t, depo, boyut: const Size(320, 640), yaziOlcegi: 1.5);
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('2 okulun menüsü alınamadı'), findsOneWidget);
      await _yaz(t, 'corba');
      expect(t.takeException(), isNull);
      // sonuçlar kaydırılabilir alanda: en sondaki satıra inilebilir
      await t.scrollUntilVisible(find.text('Ezogelin Çorbası'), 100,
          scrollable: find.descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable)));
      expect(t.takeException(), isNull);
    });
  });

  group('ana sayfa entegrasyonu', () {
    Future<void> ac(WidgetTester t, _Depo depo,
        {Size boyut = const Size(400, 900), double yaziOlcegi = 1.0}) async {
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
            simdi: () => DateTime.utc(2026, 11, 2, 10, 0)),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('üst çubukta "Yemek ara" simgesi var, dokununca arama açılır',
        (t) async {
      await ac(t, _depo(secili: 'ankara'));
      expect(find.byTooltip('Yemek ara'), findsOneWidget);
      await t.tap(find.byTooltip('Yemek ara'));
      await t.pumpAndSettle();
      expect(find.byType(YemekAraSayfasi), findsOneWidget);
      expect(find.text('Şehir: Ankara'), findsOneWidget);
    });

    testWidgets('aynı okuldaki sonuç o güne ve öğüne geçirir', (t) async {
      await ac(t, _depo(secili: 'ankara'));
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      await t.tap(find.byTooltip('Yemek ara'));
      await t.pumpAndSettle();
      await _yaz(t, 'ezogelin');
      await t.tap(find.text('Ezogelin Çorbası'));
      await t.pumpAndSettle();
      expect(find.byType(YemekAraSayfasi), findsNothing);
      expect(find.text('Yarın'), findsOneWidget);
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsNothing);

      // akşam öğününe aynı okulda dönüş
      await t.tap(find.byTooltip('Yemek ara'));
      await t.pumpAndSettle();
      await _yaz(t, 'makarna');
      await t.tap(find.text('Fırın Makarna'));
      await t.pumpAndSettle();
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Fırın Makarna'), findsOneWidget);
    });

    testWidgets('başka okuldaki sonuç o okula, gün ve öğüne geçirir',
        (t) async {
      final depo = _depo(secili: 'ankara');
      await ac(t, depo);
      await t.tap(find.byTooltip('Yemek ara'));
      await t.pumpAndSettle();
      await _yaz(t, 'nohut');
      await t.tap(find.text('Gazi Etli Nohut'));
      await t.pumpAndSettle();
      expect(find.byType(YemekAraSayfasi), findsNothing);
      expect(find.text('Gazi Üniversitesi'), findsOneWidget); // AppBar başlığı
      expect(find.text('Gazi Etli Nohut'), findsOneWidget);
      expect(find.text('Çarşamba'), findsOneWidget); // 4 Kasım
      expect(find.text('Akşam'), findsOneWidget);
      expect(depo.secili, 'gazi');
      // Akşam sekmesi seçili
      final dugme = t.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>));
      expect(dugme.selected, {'dinner'});
    });

    testWidgets('karşılama ekranında (okul seçilmemiş) arama simgesi pasif',
        (t) async {
      await ac(t, _depo());
      final dugme =
          t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.search));
      expect(dugme.onPressed, isNull);
      expect(find.byTooltip('Yemek ara'), findsOneWidget);
    });

    for (final olcek in [1.0, 1.5]) {
      testWidgets(
          '320x640, yazı ${olcek}x, uzun okul adı: arama simgesi taşmaz, 48dp, başlıkla çakışmaz',
          (t) async {
        final depo = _Depo([
          _u(
              'ankara',
              'Ankara Hacı Bayram Veli Sağlık Bilimleri ve Teknoloji Üniversitesi',
              'AHBV',
              'Ankara'),
        ], {
          'ankara': _menu('ankara', {
            '2026-11-02': {
              'lunch': ['Mercimek Çorbası']
            }
          })
        }, secili: 'ankara');
        await ac(t, depo, boyut: const Size(320, 640), yaziOlcegi: olcek);
        expect(t.takeException(), isNull);
        final ara = find.widgetWithIcon(IconButton, Icons.search);
        final boyut = t.getSize(ara);
        expect(boyut.width, greaterThanOrEqualTo(48));
        expect(boyut.height, greaterThanOrEqualTo(48));
        expect(t.getRect(find.byIcon(Icons.arrow_drop_down)).right,
            lessThanOrEqualTo(t.getRect(ara).left));
        // üç simge de ekranda
        for (final ipucu in ['Favoriler', 'Diğer']) {
          expect(
              t.getRect(find.byTooltip(ipucu)).right, lessThanOrEqualTo(320));
        }
        await t.tap(ara);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byType(YemekAraSayfasi), findsOneWidget);
      });
    }
  });
}
