import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/paylas.dart';
import 'package:yemekhane/paylasim.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';

// ---------------------------------------------------------------------------
// Ortak veri
// ---------------------------------------------------------------------------

Universite _uni({
  List<String> ogunler = const ['lunch', 'dinner'],
  Map<String, ServisSaati>? saatler,
  List<Fiyat>? fiyatlar,
  String ad = 'Ankara Üniversitesi',
}) =>
    Universite(
        id: 'ankara',
        ad: ad,
        kisa: 'AÜ',
        sehir: 'Ankara',
        kaynak: '',
        ogunler: ogunler,
        fiyatlar: fiyatlar ??
            [
              Fiyat('Öğrenci (Öğle Yemeği)', 50),
              Fiyat('Öğrenci (Akşam Yemeği)', 100),
            ],
        saatler: saatler ??
            const {
              'lunch': ServisSaati('11:00–14:00', false),
              'dinner': ServisSaati('17:00–19:00', false),
            });

YemekOgesi _y(String ad, [int? kcal]) => YemekOgesi(ad, kcal);

Ogun _tatil(String not) => Ogun(const [], null, null, false, not);

/// Panoya yazılan metinleri toplar (SystemChannels.platform sahtesi). [hata] true ise pano da çalışmaz.
List<String> _panoyuDinle(WidgetTester t, {bool hata = false}) {
  final yazilan = <String>[];
  t.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (c) async {
    if (c.method == 'Clipboard.setData') {
      if (hata) throw PlatformException(code: 'pano-yok');
      yazilan.add((c.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return yazilan;
}

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

Future<ScaffoldMessengerState> _bildirim(WidgetTester t) async {
  await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
  return ScaffoldMessenger.of(t.element(find.byType(Scaffold)));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('gunMetni: tek öğün', () {
    test('okul, gün, servis saati, yemekler, toplam kalori ve öğrenci fiyatı',
        () {
      final gun = {
        'lunch': Ogun(
            [_y('Mercimek Çorbası'), _y('Tavuk Sote'), _y('Pirinç Pilavı')],
            1468),
      };
      expect(
          gunMetni(_uni(), '2026-10-02', gun, ogun: 'lunch'),
          [
            'Ankara Üniversitesi · Cuma 2 Ekim',
            'Öğle (11:00-14:00)',
            '• Mercimek Çorbası',
            '• Tavuk Sote',
            '• Pirinç Pilavı',
            'Toplam 1468 kkal · Öğrenci 50 ₺',
          ].join('\n'));
    });

    test('akşam öğünü akşam fiyatını ve saatini kullanır', () {
      final gun = {
        'dinner': Ogun([_y('Fırın Makarna')], 500),
      };
      expect(
          gunMetni(_uni(), '2026-11-02', gun, ogun: 'dinner'),
          [
            'Ankara Üniversitesi · Pazartesi 2 Kasım',
            'Akşam (17:00-19:00)',
            '• Fırın Makarna',
            'Toplam 500 kkal · Öğrenci 100 ₺',
          ].join('\n'));
    });

    test('okul saati yayınlamamış (yaklaşık) ise "genelde" yazılır', () {
      final uni = _uni(saatler: const {
        'lunch': ServisSaati('11:30–14:00', true),
      });
      final gun = {
        'lunch': Ogun([_y('Ayran')], null)
      };
      expect(gunMetni(uni, '2026-11-02', gun, ogun: 'lunch'),
          contains('Öğle (genelde 11:30-14:00)'));
    });

    test(
        'saat biçimi: tire ya da uzun tire, tek haneli saat sıfırla tamamlanır',
        () {
      final gun = {
        'lunch': Ogun([_y('Ayran')], null)
      };
      String baslik(String t) => gunMetni(
              _uni(saatler: {'lunch': ServisSaati(t, false)}),
              '2026-11-02',
              gun,
              ogun: 'lunch')
          .split('\n')[1];
      expect(baslik('11:30-14:00'), 'Öğle (11:30-14:00)');
      expect(baslik('11:30–14:00'), 'Öğle (11:30-14:00)');
      expect(baslik('7:30–9:00'), 'Öğle (07:30-09:00)');
    });

    test('olmayan bilgi yazılmaz: kalori yok, fiyat yok, saat yok', () {
      final gun = {
        'lunch': Ogun([_y('Ayran')], null)
      };
      // yalnızca fiyat
      expect(
          gunMetni(_uni(), '2026-11-02', gun, ogun: 'lunch').split('\n').last,
          'Öğrenci 50 ₺');
      // yalnızca kalori
      final kaloriliGun = {
        'lunch': Ogun([_y('Ayran')], 90)
      };
      final yalnizKalori = _uni(fiyatlar: []);
      expect(gunMetni(yalnizKalori, '2026-11-02', kaloriliGun, ogun: 'lunch'),
          endsWith('\nToplam 90 kkal'));
      // hiçbiri: saat, kalori ve fiyat satırı yok
      final bos = gunMetni(_uni(fiyatlar: [], saatler: {}), '2026-11-02', gun,
          ogun: 'lunch');
      expect(bos, 'Ankara Üniversitesi · Pazartesi 2 Kasım\nÖğle\n• Ayran');
      expect(bos, isNot(contains('kkal')));
      expect(bos, isNot(contains('₺')));
      // sıfır kalori bilgi sayılmaz
      final sifir = {
        'lunch': Ogun([_y('Ayran')], 0)
      };
      expect(gunMetni(_uni(fiyatlar: []), '2026-11-02', sifir, ogun: 'lunch'),
          isNot(contains('kkal')));
    });

    test('bozuk servis saati yazılmaz, yalnızca öğün adı kalır', () {
      final uni = _uni(saatler: const {
        'lunch': ServisSaati('öğleden sonra', false),
      });
      final gun = {
        'lunch': Ogun([_y('Ayran')], null)
      };
      expect(gunMetni(uni, '2026-11-02', gun, ogun: 'lunch').split('\n')[1],
          'Öğle');
    });

    test('vejetaryen: saat öğleden gelir, fiyat yazılmaz', () {
      final uni = _uni(ogunler: ['lunch', 'vegetarian']);
      final gun = {
        'vegetarian': Ogun([_y('Nohut Yemeği')], 300),
      };
      expect(
          gunMetni(uni, '2026-11-02', gun, ogun: 'vegetarian'),
          [
            'Ankara Üniversitesi · Pazartesi 2 Kasım',
            'Vejetaryen (11:00-14:00)',
            '• Nohut Yemeği',
            'Toplam 300 kkal',
          ].join('\n'));
    });

    test('uzun yemek adı kısaltılmaz, boş adlı öğe atlanır, ad kırpılır', () {
      const uzun =
          'Çok Uzun Adlı Kremalı Mantarlı Közlenmiş Patlıcanlı Tavuk Sote Spesiyal Yemeği';
      final gun = {
        'lunch': Ogun([_y(uzun, 1234), _y('   '), _y('  Ayran ')], null)
      };
      final metin = gunMetni(_uni(), '2026-11-02', gun, ogun: 'lunch');
      expect(metin, contains('• $uzun\n'));
      expect(metin, contains('• Ayran'));
      expect(metin, isNot(contains('•  ')));
      expect(metin.split('\n').where((s) => s.startsWith('•')).length, 2);
    });

    test('seçili öğün boş ve notlu: öğün adı ve not yazılır', () {
      final gun = {
        'lunch': _tatil('29 Ekim Cumhuriyet Bayramı'),
        'dinner': _tatil('29 Ekim Cumhuriyet Bayramı'),
      };
      expect(
          gunMetni(_uni(), '2026-10-29', gun, ogun: 'lunch'),
          [
            'Ankara Üniversitesi · Perşembe 29 Ekim',
            'Öğle (11:00-14:00)',
            '29 Ekim Cumhuriyet Bayramı',
          ].join('\n'));
    });

    test('seçili öğün yok ama gün dolu: "Bu öğün için menü yok."', () {
      final gun = {
        'dinner': Ogun([_y('Fırın Makarna')], 500),
      };
      expect(
          gunMetni(_uni(), '2026-11-02', gun, ogun: 'lunch'),
          [
            'Ankara Üniversitesi · Pazartesi 2 Kasım',
            'Öğle (11:00-14:00)',
            'Bu öğün için menü yok.',
          ].join('\n'));
    });

    test('seçili öğün yok ve gün tamamen boş: gün açıklaması', () {
      expect(gunMetni(_uni(), '2026-11-03', {}, ogun: 'lunch'),
          'Ankara Üniversitesi · Salı 3 Kasım\nOkul bu gün için menü yayınlamadı.');
    });
  });

  group('gunMetni: günün tamamı', () {
    test(
        'öğünler sabit sırada, aralarında boş satır; boş öğün ve okulda olmayan öğün yazılmaz',
        () {
      final gun = {
        'dinner': Ogun([_y('Fırın Makarna')], 500), // eklenme sırası ters
        'lunch': Ogun([_y('Mercimek Çorbası')], 420),
        'breakfast': Ogun([_y('Peynir')], 200), // okulun öğünlerinde yok
        'vegetarian': Ogun(const [], null), // boş
      };
      expect(
          gunMetni(_uni(), '2026-11-02', gun),
          [
            'Ankara Üniversitesi · Pazartesi 2 Kasım',
            'Öğle (11:00-14:00)',
            '• Mercimek Çorbası',
            'Toplam 420 kkal · Öğrenci 50 ₺',
            '',
            'Akşam (17:00-19:00)',
            '• Fırın Makarna',
            'Toplam 500 kkal · Öğrenci 100 ₺',
          ].join('\n'));
    });

    test('tatil: not ve hizmet verilmediği yazılır', () {
      final gun = {
        'lunch': _tatil('29 Ekim Cumhuriyet Bayramı'),
        'dinner': _tatil('29 Ekim Cumhuriyet Bayramı'),
      };
      expect(
          gunMetni(_uni(), '2026-10-29', gun),
          [
            'Ankara Üniversitesi · Perşembe 29 Ekim',
            '29 Ekim Cumhuriyet Bayramı',
            'Bu gün yemekhane hizmeti verilmiyor.',
          ].join('\n'));
    });

    test('notsuz boş gün: yalnızca hizmet verilmediği yazılır', () {
      final gun = {'lunch': Ogun(const [], null)};
      expect(
          gunMetni(_uni(), '2026-11-03', gun),
          'Ankara Üniversitesi · Salı 3 Kasım\n'
          'Bu gün yemekhane hizmeti verilmiyor.');
    });

    test('menü yayınlanmamış gün ve hafta sonu açıklamaları', () {
      expect(gunMetni(_uni(), '2026-11-03', {}),
          'Ankara Üniversitesi · Salı 3 Kasım\nOkul bu gün için menü yayınlamadı.');
      expect(gunMetni(_uni(), '2026-11-07', {}),
          'Ankara Üniversitesi · Cumartesi 7 Kasım\nHafta sonu yemekhane hizmeti verilmiyor.');
    });

    test('okulun öğün listesi boşsa (bilinmiyor) gündeki bütün öğünler yazılır',
        () {
      final gun = {
        'lunch': Ogun([_y('Ayran')], null)
      };
      expect(
          gunMetni(_uni(ogunler: []), '2026-11-02', gun), contains('• Ayran'));
    });

    test('hiçbir metinde emoji ya da simge karakteri yoktur', () {
      final uni = _uni();
      final menu = Menu('ankara', null, {
        '2026-11-02': {
          'lunch': Ogun([_y('Mercimek Çorbası', 120)], 420),
          'dinner': Ogun([_y('Makarna')], 500),
        },
        '2026-11-04': {'lunch': _tatil('Tatil')},
      });
      final metinler = [
        gunMetni(uni, '2026-11-02', menu.gunler['2026-11-02']!),
        gunMetni(uni, '2026-11-02', menu.gunler['2026-11-02']!, ogun: 'lunch'),
        gunMetni(uni, '2026-11-04', menu.gunler['2026-11-04']!),
        gunMetni(uni, '2026-11-03', {}),
        haftaMetni(uni, menu, '2026-11-02', 'lunch'),
      ];
      final emoji = RegExp(
          r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}]',
          unicode: true);
      for (final m in metinler) {
        expect(emoji.hasMatch(m), isFalse, reason: m);
      }
    });
  });

  group('paylasilabilir', () {
    test('öğün: yemek ya da not varsa evet, yoksa hayır', () {
      final gun = {
        'lunch': Ogun([_y('Ayran')], null),
        'dinner': _tatil('Tatil'),
        'breakfast': Ogun(const [], null),
      };
      expect(paylasilabilir(gun, ogun: 'lunch'), isTrue);
      expect(paylasilabilir(gun, ogun: 'dinner'), isTrue);
      expect(paylasilabilir(gun, ogun: 'breakfast'), isFalse);
      expect(paylasilabilir(gun, ogun: 'vegetarian'), isFalse);
    });

    test('gün: herhangi bir veri varsa evet, hiç yoksa hayır', () {
      expect(paylasilabilir({}), isFalse);
      expect(paylasilabilir({'lunch': Ogun(const [], null)}), isTrue);
    });
  });

  group('haftaMetni', () {
    final menu = Menu('ankara', null, {
      '2026-11-02': {
        'lunch': Ogun([_y('Mercimek Çorbası'), _y('Pirinç Pilavı')], 420)
      },
      '2026-11-03': {
        'lunch': Ogun([_y('Ezogelin Çorbası')], null)
      },
      '2026-11-04': {'lunch': _tatil('Tatil'), 'dinner': _tatil('Tatil')},
      '2026-11-05': {
        'dinner': Ogun([_y('Fırın Makarna')], 500)
      },
    });

    test(
        'okul ve aralık bir kez, her gün için yemekler; eksik günler açıklanır',
        () {
      expect(
          haftaMetni(_uni(), menu, '2026-11-02', 'lunch'),
          [
            'Ankara Üniversitesi · 2 – 8 Kasım',
            'Öğle (11:00-14:00) · Öğrenci 50 ₺',
            '',
            'Pazartesi 2 Kasım',
            '• Mercimek Çorbası',
            '• Pirinç Pilavı',
            'Toplam 420 kkal',
            '',
            'Salı 3 Kasım',
            '• Ezogelin Çorbası',
            '',
            'Çarşamba 4 Kasım',
            'Tatil',
            '',
            'Perşembe 5 Kasım',
            'Bu öğün için menü yok',
            '',
            'Cuma 6 Kasım',
            'Menü yayınlanmadı',
            '',
            'Cumartesi 7 Kasım',
            'Hizmet yok',
            '',
            'Pazar 8 Kasım',
            'Hizmet yok',
          ].join('\n'));
    });

    test('ay aşan hafta başlığı, fiyatsız ve saatsiz öğün (vejetaryen)', () {
      final m = Menu('ankara', null, {
        '2026-10-30': {
          'vegetarian': Ogun([_y('Nohut Yemeği')], 300)
        },
      });
      final metin = haftaMetni(_uni(saatler: {}, ogunler: ['vegetarian']), m,
          '2026-10-26', 'vegetarian');
      expect(metin.split('\n').take(2).toList(), [
        'Ankara Üniversitesi · 26 Ekim – 1 Kasım',
        'Vejetaryen',
      ]);
      expect(metin, contains('Cuma 30 Ekim\n• Nohut Yemeği\nToplam 300 kkal'));
      expect(metin, isNot(contains('₺')));
    });
  });

  group('metniPaylas / metniKopyala', () {
    testWidgets(
        'paylaşım açılırsa servis çağrılır, pano ve bildirim kullanılmaz',
        (t) async {
      final pano = _panoyuDinle(t);
      final bildirim = await _bildirim(t);
      final servis = SahtePaylasim();
      await metniPaylas(bildirim, servis, 'Merhaba menü', konu: 'Konu');
      await t.pump();
      expect(servis.cagrilar, [('Merhaba menü', 'Konu')]);
      expect(pano, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'paylaşım hata verirse metin panoya kopyalanır ve bildirim çıkar',
        (t) async {
      final pano = _panoyuDinle(t);
      final bildirim = await _bildirim(t);
      final servis = SahtePaylasim()..hata = Exception('desteklenmiyor');
      await metniPaylas(bildirim, servis, 'Merhaba menü');
      await t.pump();
      expect(servis.cagrilar.length, 1);
      expect(pano, ['Merhaba menü']);
      expect(find.text('Paylaşım açılamadı, menü panoya kopyalandı'),
          findsOneWidget);
    });

    testWidgets('pano da çalışmazsa "Panoya kopyalanamadı" bildirimi çıkar',
        (t) async {
      _panoyuDinle(t, hata: true);
      final bildirim = await _bildirim(t);
      final servis = SahtePaylasim()..hata = Exception('desteklenmiyor');
      await metniPaylas(bildirim, servis, 'Merhaba menü');
      await t.pump();
      expect(find.text('Panoya kopyalanamadı'), findsOneWidget);
    });

    testWidgets('metniKopyala başarıda verilen bildirimi gösterir', (t) async {
      final pano = _panoyuDinle(t);
      final bildirim = await _bildirim(t);
      await metniKopyala(bildirim, 'Metin');
      await t.pump();
      expect(pano, ['Metin']);
      expect(find.text('Menü panoya kopyalandı'), findsOneWidget);
    });

    testWidgets('gerçek servis share_plus kanalına metin ve konuyu gönderir',
        (t) async {
      const kanal = MethodChannel('dev.fluttercommunity.plus/share');
      final cagrilar = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(kanal,
          (c) async {
        cagrilar.add(c);
        return 'dev.fluttercommunity.plus/share/success';
      });
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null));
      await const SharePlusServisi().paylas('Merhaba menü', konu: 'Konu');
      expect(cagrilar.single.method, 'share');
      final arguman = cagrilar.single.arguments as Map;
      expect(arguman['text'], 'Merhaba menü');
      expect(arguman['subject'], 'Konu');
    });

    testWidgets(
        'desteksiz platform (kanalda uygulama yok): gerçek servis atar, metin panoya gider',
        (t) async {
      // eklentinin uygulanmadığı platform: kanal MissingPluginException verir
      // (testte kanala hiç işleyici bağlamamak yanıtsız kalıp takıldığı için bu biçimde taklit edilir)
      const kanal = MethodChannel('dev.fluttercommunity.plus/share');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(kanal,
          (c) async {
        throw MissingPluginException('${c.method} uygulanmadı');
      });
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null));
      final pano = _panoyuDinle(t);
      final bildirim = await _bildirim(t);
      await metniPaylas(bildirim, const SharePlusServisi(), 'Merhaba menü');
      await t.pump();
      expect(pano, ['Merhaba menü']);
      expect(find.text('Paylaşım açılamadı, menü panoya kopyalandı'),
          findsOneWidget);
    });
  });

  group('ana sayfa: Diğer > Paylaş', () {
    Future<void> ac(WidgetTester t, _SahteDepo depo, SahtePaylasim servis,
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
            paylasim: servis,
            simdi: () => DateTime.utc(2026, 11, 2, 10, 0)),
      ));
      await t.pumpAndSettle();
    }

    Future<void> paylasSayfasiniAc(WidgetTester t) async {
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Paylaş'));
      await t.pumpAndSettle();
    }

    const ogleMetni = 'Ankara Üniversitesi · Pazartesi 2 Kasım\n'
        'Öğle (11:00-14:00)\n'
        '• Mercimek Çorbası\n'
        '• Pirinç Pilavı\n'
        'Toplam 420 kkal · Öğrenci 50 ₺';
    const aksamMetni = 'Ankara Üniversitesi · Pazartesi 2 Kasım\n'
        'Akşam (17:00-19:00)\n'
        '• Fırın Makarna\n'
        'Toplam 500 kkal · Öğrenci 100 ₺';
    const gunMetniBeklenen = '$ogleMetni\n\n'
        'Akşam (17:00-19:00)\n'
        '• Fırın Makarna\n'
        'Toplam 500 kkal · Öğrenci 100 ₺';

    testWidgets(
        'Diğer menüsünde Haftalık menü ve Paylaş vardır, ikisi de açıktır',
        (t) async {
      await ac(t, _depo(), SahtePaylasim());
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      for (final ad in [
        'Haftalık menü',
        'Paylaş',
        'Tema',
        'Yenile',
        'Ayarlar'
      ]) {
        expect(find.text(ad), findsOneWidget, reason: ad);
      }
      for (final ad in ['Haftalık menü', 'Paylaş']) {
        final oge = t.widget<PopupMenuItem<VoidCallback>>(
            find.widgetWithText(PopupMenuItem<VoidCallback>, ad));
        expect(oge.enabled, isTrue, reason: ad);
      }
    });

    testWidgets('alt sayfada üç satır ve açıklamaları görünür', (t) async {
      await ac(t, _depo(), SahtePaylasim());
      await paylasSayfasiniAc(t);
      expect(find.text('Bu öğünü paylaş'), findsOneWidget);
      expect(find.text('Günün menüsünü paylaş'), findsOneWidget);
      expect(find.text('Panoya kopyala'), findsOneWidget);
      expect(find.text('Öğle · Pazartesi 2 Kasım'), findsOneWidget);
      expect(find.text('Tüm öğünler · Pazartesi 2 Kasım'), findsOneWidget);
      expect(find.text('Öğle menüsünün metnini kopyalar'), findsOneWidget);
    });

    testWidgets('"Bu öğünü paylaş" seçili öğünün metnini servise verir',
        (t) async {
      final servis = SahtePaylasim();
      await ac(t, _depo(), servis);
      await paylasSayfasiniAc(t);
      await t.tap(find.text('Bu öğünü paylaş'));
      await t.pumpAndSettle();
      expect(servis.cagrilar, [(ogleMetni, 'Ankara Üniversitesi menüsü')]);
      expect(find.text('Bu öğünü paylaş'), findsNothing); // alt sayfa kapandı
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Akşam sekmesindeyken akşam öğünü paylaşılır', (t) async {
      final servis = SahtePaylasim();
      await ac(t, _depo(), servis);
      await t.tap(find.text('Akşam'));
      await t.pumpAndSettle();
      await paylasSayfasiniAc(t);
      expect(find.text('Akşam · Pazartesi 2 Kasım'), findsOneWidget);
      await t.tap(find.text('Bu öğünü paylaş'));
      await t.pumpAndSettle();
      expect(servis.cagrilar.single.$1, aksamMetni);
    });

    testWidgets('"Günün menüsünü paylaş" bütün öğünleri servise verir',
        (t) async {
      final servis = SahtePaylasim();
      await ac(t, _depo(), servis);
      await paylasSayfasiniAc(t);
      await t.tap(find.text('Günün menüsünü paylaş'));
      await t.pumpAndSettle();
      expect(servis.cagrilar.single.$1, gunMetniBeklenen);
    });

    testWidgets('"Panoya kopyala" öğünün metnini panoya yazar ve bildirir',
        (t) async {
      final pano = _panoyuDinle(t);
      final servis = SahtePaylasim();
      await ac(t, _depo(), servis);
      await paylasSayfasiniAc(t);
      await t.tap(find.text('Panoya kopyala'));
      await t.pumpAndSettle();
      expect(pano, [ogleMetni]);
      expect(servis.cagrilar, isEmpty);
      expect(find.text('Menü panoya kopyalandı'), findsOneWidget);
    });

    testWidgets('paylaşım hata verirse panoya kopyalanır ve bildirim çıkar',
        (t) async {
      final pano = _panoyuDinle(t);
      final servis = SahtePaylasim()..hata = Exception('desteklenmiyor');
      await ac(t, _depo(), servis);
      await paylasSayfasiniAc(t);
      await t.tap(find.text('Bu öğünü paylaş'));
      await t.pumpAndSettle();
      expect(servis.cagrilar.length, 1);
      expect(pano, [ogleMetni]);
      expect(find.text('Paylaşım açılamadı, menü panoya kopyalandı'),
          findsOneWidget);
    });

    testWidgets('menüsü olmayan günde üç satır da pasiftir', (t) async {
      final depo = _depo();
      await ac(t, depo, SahtePaylasim());
      await t.tap(find.byTooltip('Sonraki gün')); // 3 Kasım: menü yok
      await t.pumpAndSettle();
      await paylasSayfasiniAc(t);
      for (final ad in [
        'Bu öğünü paylaş',
        'Günün menüsünü paylaş',
        'Panoya kopyala'
      ]) {
        final satir = t.widget<ListTile>(find.widgetWithText(ListTile, ad));
        expect(satir.enabled, isFalse, reason: ad);
        expect(satir.onTap, isNull, reason: ad);
      }
      expect(find.text('Bu öğün için paylaşılacak menü yok'), findsOneWidget);
      expect(find.text('Bu gün için paylaşılacak menü yok'), findsOneWidget);
      expect(find.text('Kopyalanacak menü yok'), findsOneWidget);
    });

    testWidgets(
        'seçili öğün boşken öğün satırı pasif, gün satırı açık, kopyala günü kopyalar',
        (t) async {
      final pano = _panoyuDinle(t);
      final depo = _depo();
      // 2 Kasım'da akşam yemeği yok; öğle var
      depo.menuVeri['ankara']!.gunler['2026-11-02']!.remove('dinner');
      await ac(t, depo, SahtePaylasim());
      await t.tap(find.text('Akşam'));
      await t.pumpAndSettle();
      await paylasSayfasiniAc(t);
      expect(
          t
              .widget<ListTile>(
                  find.widgetWithText(ListTile, 'Bu öğünü paylaş'))
              .enabled,
          isFalse);
      expect(
          t
              .widget<ListTile>(
                  find.widgetWithText(ListTile, 'Günün menüsünü paylaş'))
              .enabled,
          isTrue);
      expect(find.text('Günün menüsünün metnini kopyalar'), findsOneWidget);
      await t.tap(find.text('Panoya kopyala'));
      await t.pumpAndSettle();
      expect(
          pano.single,
          startsWith('Ankara Üniversitesi · Pazartesi 2 Kasım\n'
              'Öğle (11:00-14:00)'));
    });

    testWidgets(
        'okul seçilmemişken (karşılama) Haftalık menü ve Paylaş pasiftir',
        (t) async {
      await ac(t, _depo(secili: null), SahtePaylasim());
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      for (final ad in ['Haftalık menü', 'Paylaş']) {
        final oge = t.widget<PopupMenuItem<VoidCallback>>(
            find.widgetWithText(PopupMenuItem<VoidCallback>, ad));
        expect(oge.enabled, isFalse, reason: ad);
      }
      final yenile = t.widget<PopupMenuItem<VoidCallback>>(
          find.widgetWithText(PopupMenuItem<VoidCallback>, 'Yenile'));
      expect(yenile.enabled, isTrue); // eskisi gibi
    });

    testWidgets('menü yüklenirken Haftalık menü ve Paylaş pasiftir', (t) async {
      final depo = _depo()..kapi = Completer<void>();
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final ayar = TemaAyari();
      await t.pumpWidget(MaterialApp(
        theme: ayar.tema(Brightness.light),
        home: AnaSayfa(
            temaAyari: ayar,
            depo: depo,
            geriBildirim: YerelDepo(),
            paylasim: SahtePaylasim(),
            simdi: () => DateTime.utc(2026, 11, 2, 10, 0)),
      ));
      await t.pump();
      await t.tap(find.byTooltip('Diğer'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      for (final ad in ['Haftalık menü', 'Paylaş']) {
        final oge = t.widget<PopupMenuItem<VoidCallback>>(
            find.widgetWithText(PopupMenuItem<VoidCallback>, ad));
        expect(oge.enabled, isFalse, reason: ad);
      }
      await t.tapAt(const Offset(5, 5));
      await t.pump(const Duration(milliseconds: 400));
      depo.kapi!.complete();
      await t.pumpAndSettle();
    });

    for (final olcek in [1.0, 1.5]) {
      testWidgets('320x640, yazı ${olcek}x: Diğer menüsü ve alt sayfa taşmaz',
          (t) async {
        final servis = SahtePaylasim();
        await ac(t, _depo(), servis,
            boyut: const Size(320, 640), yaziOlcegi: olcek);
        await t.tap(find.byTooltip('Diğer'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.tap(find.text('Paylaş'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        for (final ad in [
          'Bu öğünü paylaş',
          'Günün menüsünü paylaş',
          'Panoya kopyala'
        ]) {
          final satir = find.widgetWithText(ListTile, ad);
          expect(satir, findsOneWidget, reason: ad);
          expect(t.getSize(satir).height, greaterThanOrEqualTo(48));
          expect(t.getRect(satir).right, lessThanOrEqualTo(320));
        }
      });
    }
  });
}

// ---------------------------------------------------------------------------
// Ana sayfa testleri için sahte veri deposu ve menü
// ---------------------------------------------------------------------------

class _SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  String? secili;
  Completer<void>? kapi;
  _SahteDepo(this.liste, this.menuVeri, {this.secili});

  @override
  Future<List<Universite>> universiteler() async => liste;
  @override
  Future<Menu> menu(String universiteId) async {
    if (kapi != null) await kapi!.future;
    return menuVeri[universiteId]!;
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

/// 2 Kasım 2026 (pazartesi) öğle ve akşam menülü; 3 Kasım için menü yok; 4 Kasım'da yalnızca öğle var.
_SahteDepo _depo({String? secili = 'ankara'}) => _SahteDepo([
      _uni(),
    ], {
      'ankara': Menu('ankara', null, {
        '2026-11-02': {
          'lunch': Ogun(
              [_y('Mercimek Çorbası', 120), _y('Pirinç Pilavı', 300)], 420),
          'dinner': Ogun([_y('Fırın Makarna', 500)], 500),
        },
        '2026-11-04': {
          'lunch': Ogun([_y('Ezogelin Çorbası', 110)], 110),
        },
      })
    }, secili: secili);
