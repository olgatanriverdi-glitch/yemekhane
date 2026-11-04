import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';
import 'package:yemekhane/widgets/simdi_seridi.dart';

DateTime _an(int s, int d, [int sn = 0]) => DateTime.utc(2026, 11, 2, s, d, sn);

Universite _uni(
        {List<String> ogunler = const ['lunch', 'dinner'],
        Map<String, ServisSaati> saatler = const {}}) =>
    Universite(
        id: 'ankara',
        ad: 'Ankara Üniversitesi',
        kisa: 'ankara',
        sehir: 'Ankara',
        kaynak: '',
        ogunler: ogunler,
        fiyatlar: const [],
        saatler: saatler);

const _saatli = {
  'lunch': ServisSaati('11:00–14:00', false),
  'dinner': ServisSaati('17:00–19:00', false),
};

/// Ağa ve diske gitmeyen sahte depo: tek okul, verilen menü; çağrıları sayar.
class SahteDepo extends Depo {
  final Universite okul;
  final Menu menuVeri;
  bool hataAt = false;
  int menuCagri = 0;

  SahteDepo(this.okul, this.menuVeri);

  @override
  Future<List<Universite>> universiteler() async => [okul];

  @override
  Future<Menu> menu(String universiteId) async {
    menuCagri++;
    if (hataAt) throw Exception('ağ yok');
    return menuVeri;
  }

  @override
  Future<String?> seciliUniversite() async => 'ankara';

  @override
  Future<void> universiteSec(String id) async {}

  @override
  Future<List<String>> sonSecilenler() async => const [];

  @override
  String? fotoUrl(String universiteId, String? foto) => null;

  @override
  String? yemekFotoUrl(String? img) => null;
}

const _corbalar = {
  '2026-11-02': 'Mercimek Çorbası',
  '2026-11-03': 'Ezogelin Çorbası',
  '2026-11-04': 'Domates Çorbası',
  '2026-11-05': 'Tarhana Çorbası',
  '2026-11-06': 'Yayla Çorbası',
};

/// [tarihler] verilen günler için öğle (çorba + pilav) ve akşam (makarna) menüsü.
Menu _menu([Iterable<String>? tarihler]) => Menu('ankara', null, {
      for (final g in tarihler ?? _corbalar.keys)
        g: {
          'lunch': Ogun([
            YemekOgesi(_corbalar[g] ?? 'Mercimek Çorbası', 120, null,
                g == '2026-11-02' ? 'mercimek' : null),
            YemekOgesi('Pirinç Pilavı', 300),
          ], 420),
          'dinner': Ogun([YemekOgesi('Fırın Makarna', 500)], 500),
        }
    });

Future<void> _ac(WidgetTester t, SahteDepo depo,
    {required DateTime Function() simdi,
    Size boyut = const Size(400, 900),
    double yaziOlcegi = 1.0}) async {
  await t.pumpWidget(
      const SizedBox()); // önceki AnaSayfa durumu yeniden kullanılmasın
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
        temaAyari: ayar, depo: depo, geriBildirim: YerelDepo(), simdi: simdi),
  ));
  await t.pumpAndSettle();
}

/// Uygulamayı arka plana atıp öne getirir (resumed).
void _arkaPlanaGidipDon(WidgetTester t) {
  final b = t.binding;
  for (final d in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    b.handleAppLifecycleStateChanged(d);
  }
}

/// Şerit metni: SimdiSeridi içindeki tek Text (yoksa null).
String? _seritMetni(WidgetTester t) {
  final metinler = find.descendant(
      of: find.byType(SimdiSeridi), matching: find.byType(Text));
  if (metinler.evaluate().isEmpty) return null;
  return t.widget<Text>(metinler).data;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ServisSaati.aralik', () {
    test('en dash, kısa çizgi ve boşluklu biçimler çözülür', () {
      expect(const ServisSaati('11:30–14:00', false).aralik(), (690, 840));
      expect(const ServisSaati('11:30-14:00', false).aralik(), (690, 840));
      expect(const ServisSaati(' 7:30 – 09:00 ', true).aralik(), (450, 540));
      expect(const ServisSaati('00:00–24:00', false).aralik(), (0, 1440));
    });

    test('bozuk ya da mantıksız saat null döner', () {
      for (final t in [
        '',
        'öğle',
        '11:30',
        '11:30–',
        '11.30–14.00',
        '25:00–26:00',
        '11:60–14:00',
        '11:00–24:30',
        '14:00–11:30', // bitiş başlangıçtan önce
        '11:30–11:30', // süre sıfır
        '11:30–14:00–16:00',
      ]) {
        expect(ServisSaati(t, false).aralik(), isNull, reason: t);
      }
    });
  });

  group('ogunDurumu', () {
    const s = ServisSaati('11:30–14:00', false);

    test('sınırlar: başlamadı / devam / bitti', () {
      var d = ogunDurumu(s, _an(11, 29))!;
      expect(d.asama, OgunAsama.baslamadi);
      expect(d.kalanDk, 1);

      d = ogunDurumu(s, _an(11, 30))!; // başlangıç dakikası: servis açık
      expect(d.asama, OgunAsama.devam);
      expect(d.kalanDk, 150);

      d = ogunDurumu(s, _an(13, 59))!;
      expect(d.asama, OgunAsama.devam);
      expect(d.kalanDk, 1);

      d = ogunDurumu(s, _an(14, 0))!; // bitiş dakikası: bitti
      expect(d.asama, OgunAsama.bitti);
      expect(d.kalanDk, 0);

      expect(ogunDurumu(s, _an(23, 59))!.asama, OgunAsama.bitti);
      expect(ogunDurumu(s, _an(0, 0))!.asama, OgunAsama.baslamadi);
    });

    test('saniyeler yok sayılır', () {
      expect(ogunDurumu(s, _an(11, 29, 59))!.asama, OgunAsama.baslamadi);
      expect(ogunDurumu(s, _an(13, 59, 59))!.asama, OgunAsama.devam);
    });

    test('bozuk saat için null', () {
      expect(ogunDurumu(const ServisSaati('???', false), _an(12, 0)), isNull);
    });
  });

  group('metinler', () {
    test('sureMetni', () {
      expect(sureMetni(0), '0 dk');
      expect(sureMetni(25), '25 dk');
      expect(sureMetni(59), '59 dk');
      expect(sureMetni(60), '1 sa');
      expect(sureMetni(70), '1 sa 10 dk');
      expect(sureMetni(150), '2 sa 30 dk');
    });

    test("saatMetniEkli: okunuşa uyan -de / -da / -te / -ta", () {
      expect(saatMetniEkli(11 * 60), "11:00'de"); // on bir
      expect(saatMetniEkli(10 * 60), "10:00'da"); // on
      expect(saatMetniEkli(14 * 60), "14:00'te"); // on dört
      expect(saatMetniEkli(17 * 60), "17:00'de"); // on yedi
      expect(saatMetniEkli(7 * 60 + 30), "07:30'da"); // otuz
      expect(saatMetniEkli(14 * 60 + 15), "14:15'te"); // on beş
      expect(saatMetniEkli(9 * 60 + 40), "09:40'ta"); // kırk
      expect(saatMetniEkli(17 * 60 + 45), "17:45'te"); // kırk beş
      expect(saatMetniEkli(12 * 60 + 20), "12:20'de"); // yirmi
    });

    const kesin = ServisSaati('11:00–14:00', false);
    const yaklasik = ServisSaati('11:00–14:00', true);

    test('başlamadı', () {
      expect(
          simdiSeridiMetni('lunch', kesin, _an(10, 35)), 'Öğle yemeğine 25 dk');
      expect(simdiSeridiMetni('dinner', kesin, _an(10, 35)),
          'Akşam yemeğine 25 dk');
      expect(
          simdiSeridiMetni('breakfast', kesin, _an(9, 0)), 'Kahvaltıya 2 sa');
      expect(simdiSeridiMetni('lunch', yaklasik, _an(10, 35)),
          "Genelde 11:00'de başlar · 25 dk");
    });

    test('devam', () {
      expect(simdiSeridiMetni('lunch', kesin, _an(12, 50)),
          'Servis açık · bitmesine 1 sa 10 dk');
      expect(simdiSeridiMetni('lunch', kesin, _an(13, 59)),
          'Servis açık · bitmesine 1 dk');
      expect(simdiSeridiMetni('lunch', yaklasik, _an(12, 50)),
          "Genelde 14:00'te biter · 1 sa 10 dk");
    });

    test('bitti', () {
      expect(
          simdiSeridiMetni('lunch', kesin, _an(14, 0)), 'Öğle servisi bitti');
      expect(simdiSeridiMetni('dinner', yaklasik, _an(20, 0)),
          'Akşam servisi bitti');
      expect(simdiSeridiMetni('breakfast', kesin, _an(23, 0)),
          'Kahvaltı servisi bitti');
    });

    test('bozuk saatte null', () {
      expect(
          simdiSeridiMetni(
              'lunch', const ServisSaati('???', false), _an(12, 0)),
          isNull);
    });
  });

  group('akilliOgun', () {
    test('saatli okul: bitişi şimdiden sonra olan ilk öğün', () {
      final uni = _uni(saatler: _saatli);
      expect(akilliOgun(uni, _an(6, 0)), 'lunch');
      expect(akilliOgun(uni, _an(13, 59)), 'lunch');
      expect(akilliOgun(uni, _an(14, 0)), 'dinner'); // öğle tam bitti
      expect(akilliOgun(uni, _an(14, 59)), 'dinner');
      expect(akilliOgun(uni, _an(15, 1)), 'dinner');
      expect(akilliOgun(uni, _an(18, 59)), 'dinner');
      expect(akilliOgun(uni, _an(19, 0)), 'dinner'); // hepsi bitti: sonuncusu
      expect(akilliOgun(uni, _an(23, 30)), 'dinner');
    });

    test('öğle 15:30\'a kadar sürüyorsa 15:01\'de hâlâ öğle', () {
      final uni = _uni(saatler: {
        ...(_saatli),
        'lunch': const ServisSaati('11:30–15:30', false),
      });
      expect(akilliOgun(uni, _an(14, 59)), 'lunch');
      expect(akilliOgun(uni, _an(15, 1)), 'lunch');
      expect(akilliOgun(uni, _an(15, 30)), 'dinner');
    });

    test('kahvaltı saatli okul: sabah kahvaltı, sonra öğle', () {
      final uni = _uni(ogunler: const [
        'breakfast',
        'lunch',
        'dinner'
      ], saatler: {
        ..._saatli,
        'breakfast': const ServisSaati('07:30–09:00', false),
      });
      expect(akilliOgun(uni, _an(6, 0)), 'breakfast');
      expect(akilliOgun(uni, _an(8, 59)), 'breakfast');
      expect(akilliOgun(uni, _an(9, 0)), 'lunch');
    });

    test('saatsiz okul: eski 15:00 kuralı', () {
      final uni = _uni();
      expect(akilliOgun(uni, _an(0, 0)), 'lunch');
      expect(akilliOgun(uni, _an(14, 59)), 'lunch');
      expect(akilliOgun(uni, _an(15, 0)), 'dinner');
      expect(akilliOgun(uni, _an(15, 1)), 'dinner');
      expect(akilliOgun(uni, _an(23, 59)), 'dinner');
    });

    test('bozuk saat metni saatsiz sayılır', () {
      final uni = _uni(saatler: {'lunch': const ServisSaati('???', false)});
      expect(akilliOgun(uni, _an(14, 59)), 'lunch');
      expect(akilliOgun(uni, _an(15, 1)), 'dinner');
    });

    test(
        'yalnızca öğle saati olan okulda akşam saatsizse akşam gün sonuna kadar',
        () {
      final uni = _uni(saatler: {'lunch': _saatli['lunch']!});
      expect(akilliOgun(uni, _an(13, 0)), 'lunch');
      expect(akilliOgun(uni, _an(14, 30)), 'dinner');
    });

    test('tek öğünlü okul: o öğün; vejetaryen otomatik seçilmez', () {
      expect(
          akilliOgun(
              _uni(ogunler: const ['lunch'], saatler: _saatli), _an(20, 0)),
          'lunch');
      expect(
          akilliOgun(
              _uni(ogunler: const ['vegetarian', 'lunch'], saatler: _saatli),
              _an(12, 0)),
          'lunch');
      expect(akilliOgun(_uni(ogunler: const ['vegetarian']), _an(12, 0)),
          'lunch'); // aday yok: eski kural (ekran ilk sekmeye düşer)
    });
  });

  group('menuBandBilgisi', () {
    Menu sonuncu(String son) => _menu(['2026-01-05', son]);

    test('bugün son günden sonraysa "yayınlanmadı" bandı', () {
      final b = menuBandBilgisi(sonuncu('2026-10-31'), '2026-11-02')!;
      expect(b.bitti, isTrue);
      expect(
          b.metin,
          'Bu okulun yeni menüsü henüz yayınlanmadı. '
          'Gösterilen son menü: 31 Ekim.');
      // bir gün sonrası da bant
      expect(
          menuBandBilgisi(sonuncu('2026-11-01'), '2026-11-02')!.bitti, isTrue);
    });

    test('son güne 0-2 gün kala hafif bilgi, 3 gün kala hiçbir şey', () {
      final bugun = menuBandBilgisi(sonuncu('2026-11-02'), '2026-11-02')!;
      expect(bugun.bitti, isFalse);
      expect(bugun.metin, "Menü 2 Kasım'a kadar yayınlandı.");
      expect(menuBandBilgisi(sonuncu('2026-11-03'), '2026-11-02')!.metin,
          "Menü 3 Kasım'a kadar yayınlandı.");
      final iki = menuBandBilgisi(sonuncu('2026-11-04'), '2026-11-02')!;
      expect(iki.bitti, isFalse);
      expect(iki.metin, "Menü 4 Kasım'a kadar yayınlandı.");
      expect(menuBandBilgisi(sonuncu('2026-11-05'), '2026-11-02'), isNull);
    });

    test("ay adı eki: Ekim'e, Eylül'e, Mart'a; ay sonu sınırı takvime göre",
        () {
      expect(menuBandBilgisi(sonuncu('2026-10-31'), '2026-10-30')!.metin,
          "Menü 31 Ekim'e kadar yayınlandı.");
      expect(menuBandBilgisi(sonuncu('2026-09-30'), '2026-09-29')!.metin,
          "Menü 30 Eylül'e kadar yayınlandı.");
      expect(menuBandBilgisi(sonuncu('2026-03-01'), '2026-02-28')!.metin,
          "Menü 1 Mart'a kadar yayınlandı."); // 2026 artık yıl değil: 28 Şubat -> 1 Mart 1 gün
      // 30 Ekim -> 1 Kasım 2 gün (31 Ekim arada)
      expect(
          menuBandBilgisi(sonuncu('2026-11-01'), '2026-10-30')!.bitti, isFalse);
    });

    test('boş menü ya da bozuk tarih için null', () {
      expect(menuBandBilgisi(Menu('x', null, {}), '2026-11-02'), isNull);
      expect(menuBandBilgisi(_menu(), 'bozuk'), isNull);
    });
  });

  group('SimdiSeridi (tek başına)', () {
    Future<void> kur(WidgetTester t, Widget w,
        {Brightness parlaklik = Brightness.light}) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: TemaAyari().tema(parlaklik),
        builder: (c, x) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: x!),
        home: Scaffold(body: w),
      ));
    }

    testWidgets('30 saniyede bir yenilenir, kaldırılınca zamanlayıcı kalmaz',
        (t) async {
      var saat = _an(10, 35);
      var cagri = 0;
      DateTime simdi() {
        cagri++;
        return saat;
      }

      await kur(
          t,
          SimdiSeridi(
              ogun: 'lunch',
              saat: _saatli['lunch'],
              bugunMu: true,
              simdi: simdi));
      expect(_seritMetni(t), 'Öğle yemeğine 25 dk');

      saat = _an(10, 36);
      await t.pump(const Duration(seconds: 29));
      expect(_seritMetni(t), 'Öğle yemeğine 25 dk'); // 30 sn dolmadı
      await t.pump(const Duration(seconds: 1));
      expect(_seritMetni(t), 'Öğle yemeğine 24 dk');

      // ağaçtan kalkınca zamanlayıcı iptal olur: saat okunmaz, setState hatası çıkmaz
      await t.pumpWidget(const SizedBox());
      final onceki = cagri;
      await t.pump(const Duration(minutes: 5));
      expect(cagri, onceki);
      expect(t.takeException(), isNull);
    });

    testWidgets('bugün değilse, saat yoksa ya da bozuksa görünmez', (t) async {
      for (final (bugunMu, saat) in [
        (false, _saatli['lunch']),
        (true, null),
        (true, const ServisSaati('???', false)),
      ]) {
        await kur(
            t,
            SimdiSeridi(
                ogun: 'lunch',
                saat: saat,
                bugunMu: bugunMu,
                simdi: () => _an(12, 0)));
        await t.pumpAndSettle();
        expect(_seritMetni(t), isNull, reason: '$bugunMu $saat');
        expect(t.getSize(find.byType(SimdiSeridi)).height, 0);
      }
    });

    for (final parlaklik in Brightness.values) {
      testWidgets('320x640, yazı 1.5x: üç durum da taşmaz ($parlaklik)',
          (t) async {
        for (final (saat, metin) in [
          (_an(10, 35), 'Öğle yemeğine 25 dk'),
          (_an(12, 50), 'Servis açık · bitmesine 1 sa 10 dk'),
          (_an(15, 0), 'Öğle servisi bitti'),
        ]) {
          await kur(
              t,
              SimdiSeridi(
                  ogun: 'lunch',
                  saat: _saatli['lunch'],
                  bugunMu: true,
                  simdi: () => saat),
              parlaklik: parlaklik);
          expect(t.takeException(), isNull);
          expect(_seritMetni(t), metin);
          expect(t.getSize(find.byType(SimdiSeridi)).width, 320);
        }
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('menü bandı iki türde de taşmaz ($parlaklik)', (t) async {
        for (final bilgi in [
          menuBandBilgisi(_menu(['2026-10-28', '2026-10-31']), '2026-11-02')!,
          menuBandBilgisi(_menu(['2026-10-28', '2026-11-03']), '2026-11-02')!,
        ]) {
          await kur(t, MenuBandi(bilgi: bilgi), parlaklik: parlaklik);
          expect(t.takeException(), isNull);
          expect(find.text(bilgi.metin), findsOneWidget);
        }
      });
    }
  });

  group('ana sayfa: şerit', () {
    SahteDepo saatliDepo({Map<String, ServisSaati> saatler = _saatli}) =>
        SahteDepo(_uni(saatler: saatler), _menu());

    testWidgets('öğle başlamadan: kalan süre; sonraki güne geçince gizlenir',
        (t) async {
      await _ac(t, saatliDepo(), simdi: () => _an(10, 35));
      expect(
          find.text('Mercimek Çorbası'), findsOneWidget); // akıllı öğün: öğle
      expect(_seritMetni(t), 'Öğle yemeğine 25 dk');

      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(_seritMetni(t), isNull); // bugün seçili değil

      await t.tap(find.byTooltip('Önceki gün'));
      await t.pumpAndSettle();
      expect(_seritMetni(t), 'Öğle yemeğine 25 dk');
    });

    testWidgets('yaklaşık saatte "Genelde ... başlar" biçimi', (t) async {
      await _ac(
          t,
          saatliDepo(saatler: {
            'lunch': const ServisSaati('11:00–14:00', true),
            'dinner': const ServisSaati('17:00–19:00', true),
          }),
          simdi: () => _an(10, 35));
      expect(_seritMetni(t), "Genelde 11:00'de başlar · 25 dk");
    });

    testWidgets('servis açıkken ve bittiğinde metinler', (t) async {
      await _ac(t, saatliDepo(), simdi: () => _an(12, 50));
      expect(_seritMetni(t), 'Servis açık · bitmesine 1 sa 10 dk');

      // öğle bittikten sonra akıllı öğün akşam; öğle sekmesinde "bitti"
      await _ac(t, saatliDepo(), simdi: () => _an(14, 30));
      expect(find.text('Fırın Makarna'), findsOneWidget);
      expect(_seritMetni(t), 'Akşam yemeğine 2 sa 30 dk');
      await t.tap(find.text('Öğle'));
      await t.pumpAndSettle();
      expect(_seritMetni(t), 'Öğle servisi bitti');
    });

    testWidgets('servis saati olmayan okulda şerit yok', (t) async {
      await _ac(t, saatliDepo(saatler: const {}), simdi: () => _an(10, 35));
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(_seritMetni(t), isNull);
    });

    testWidgets('saat ilerledikçe metin kendiliğinden güncellenir', (t) async {
      var saat = _an(10, 35);
      await _ac(t, saatliDepo(), simdi: () => saat);
      expect(_seritMetni(t), 'Öğle yemeğine 25 dk');
      saat = _an(11, 5);
      await t.pump(const Duration(seconds: 30));
      expect(_seritMetni(t), 'Servis açık · bitmesine 2 sa 55 dk');
    });

    testWidgets('akıllı öğün: 15:01\'de öğle hâlâ sürüyorsa öğle menüsü',
        (t) async {
      final depo = saatliDepo(saatler: {
        'lunch': const ServisSaati('11:30–15:30', false),
        'dinner': _saatli['dinner']!,
      });
      await _ac(t, depo, simdi: () => _an(15, 1));
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(find.text('Fırın Makarna'), findsNothing);
    });

    testWidgets('akıllı öğün, saatsiz okul: 14:59 öğle, 15:01 akşam',
        (t) async {
      await _ac(t, saatliDepo(saatler: const {}), simdi: () => _an(14, 59));
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      await _ac(t, saatliDepo(saatler: const {}), simdi: () => _an(15, 1));
      expect(find.text('Fırın Makarna'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsNothing);
    });
  });

  group('ana sayfa: menü bandı', () {
    testWidgets('bugün menünün son gününden sonraysa bant görünür', (t) async {
      final depo = SahteDepo(_uni(), _menu(['2026-10-29', '2026-10-30']));
      await _ac(t, depo, simdi: () => _an(10, 0));
      expect(
          find.text('Bu okulun yeni menüsü henüz yayınlanmadı. '
              'Gösterilen son menü: 30 Ekim.'),
          findsOneWidget);
      expect(find.byType(OgunKarti), findsOneWidget); // son menü gösteriliyor
      expect(find.byType(IskeletGovde), findsNothing);
      expect(_seritMetni(t), isNull); // seçili gün bugün değil
    });

    testWidgets('son güne 2 gün kala hafif bilgi çıkar', (t) async {
      final depo = SahteDepo(_uni(), _menu(['2026-11-02', '2026-11-04']));
      await _ac(t, depo, simdi: () => _an(10, 0));
      expect(find.text("Menü 4 Kasım'a kadar yayınlandı."), findsOneWidget);
      expect(find.textContaining('henüz yayınlanmadı'), findsNothing);
    });

    testWidgets('menü bol ise bant da bilgi de yok', (t) async {
      await _ac(t, SahteDepo(_uni(), _menu()), simdi: () => _an(10, 0));
      expect(find.textContaining('yayınlan'), findsNothing);
    });
  });

  group('ana sayfa: sessiz yenileme (resumed)', () {
    testWidgets('3 saat dolmadıysa yenilemez, dolunca iskeletsiz yeniler',
        (t) async {
      var saat = _an(10, 0);
      final depo = SahteDepo(_uni(), _menu());
      await _ac(t, depo, simdi: () => saat);
      expect(depo.menuCagri, 1);

      saat = _an(12, 59);
      _arkaPlanaGidipDon(t);
      await t.pumpAndSettle();
      expect(depo.menuCagri, 1); // 2 sa 59 dk

      saat = _an(13, 0);
      _arkaPlanaGidipDon(t);
      await t.pump();
      expect(find.byType(IskeletGovde), findsNothing);
      await t.pumpAndSettle();
      expect(depo.menuCagri, 2);
      expect(find.byType(IskeletGovde), findsNothing);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);

      // sayaç son başarılı yüklemeden (13:00) sayılır
      saat = _an(15, 59);
      _arkaPlanaGidipDon(t);
      await t.pumpAndSettle();
      expect(depo.menuCagri, 2);
      saat = _an(16, 0);
      _arkaPlanaGidipDon(t);
      await t.pumpAndSettle();
      expect(depo.menuCagri, 3);
    });

    testWidgets('otomatik yenileme hata verirse bildirim çıkmaz, menü kalır',
        (t) async {
      var saat = _an(10, 0);
      final depo = SahteDepo(_uni(), _menu());
      await _ac(t, depo, simdi: () => saat);
      depo.hataAt = true;
      saat = _an(14, 0);
      _arkaPlanaGidipDon(t);
      await t.pumpAndSettle();
      expect(depo.menuCagri, 2); // denendi
      expect(find.textContaining('Menü yüklenemedi'), findsNothing);
      expect(find.text('Tekrar dene'), findsNothing);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
    });

    testWidgets('çevrimdışı önbellekten gelen yükleme sayılmaz, tekrar denenir',
        (t) async {
      var saat = _an(10, 0);
      final depo = SahteDepo(_uni(), _menu())..cevrimdisi = true;
      await _ac(t, depo, simdi: () => saat);
      expect(depo.menuCagri, 1);
      saat = _an(10, 5); // 3 saat dolmadı ama gerçek yükleme hiç olmadı
      _arkaPlanaGidipDon(t);
      await t.pumpAndSettle();
      expect(depo.menuCagri, 2);
    });

    testWidgets('gün değişimi korunur: bugüne dönülür ve yeni gün yenilenir',
        (t) async {
      var saat = _an(21, 0);
      final depo = SahteDepo(_uni(), _menu());
      await _ac(t, depo, simdi: () => saat);
      expect(find.text('Fırın Makarna'), findsOneWidget); // akşam saati
      saat = DateTime.utc(2026, 11, 3, 9, 0);
      _arkaPlanaGidipDon(t);
      await t.pumpAndSettle();
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Ezogelin Çorbası'), findsOneWidget); // 3 Kasım öğle
      expect(depo.menuCagri, 2); // 12 saat geçti: sessiz yenileme de oldu
    });

    testWidgets('aynı gün kısa dönüşte seçili gün ve öğün değişmez', (t) async {
      var saat = _an(10, 0);
      final depo = SahteDepo(_uni(), _menu());
      await _ac(t, depo, simdi: () => saat);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      saat = _an(10, 30);
      _arkaPlanaGidipDon(t);
      await t.pumpAndSettle();
      expect(find.text('Yarın'), findsOneWidget);
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      expect(depo.menuCagri, 1);
    });
  });

  group('ana sayfa: düzen', () {
    for (final olcek in [1.0, 1.5]) {
      testWidgets(
          '320x640, yazı ${olcek}x: hafif bant + favori şeridi + şimdi şeridi birlikte taşmaz, içerik alanı kalır',
          (t) async {
        SharedPreferences.setMockInitialValues({
          FavoriDeposu.prefsAnahtari:
              jsonEncode({'mercimek': 'Mercimek Çorbası'})
        });
        final depo = SahteDepo(
            _uni(saatler: _saatli), _menu(['2026-11-02', '2026-11-04']));
        await _ac(t, depo,
            simdi: () => _an(10, 35),
            boyut: const Size(320, 640),
            yaziOlcegi: olcek);
        expect(t.takeException(), isNull);
        expect(find.text("Menü 4 Kasım'a kadar yayınlandı."), findsOneWidget);
        expect(find.textContaining('Bugün menüde: Mercimek Çorbası'),
            findsOneWidget);
        expect(_seritMetni(t), 'Öğle yemeğine 25 dk');
        // şerit ve hafif bant tek satırdır: büyük yazıda bile birer satır yüksekliğini aşmaz
        expect(t.getSize(find.byType(SimdiSeridi)).height,
            lessThanOrEqualTo(24 * olcek + 12));
        expect(t.getSize(find.byType(MenuBandi)).height,
            lessThanOrEqualTo(24 * olcek + 8));
        // üçü birden açıkken de menü alanı kalır (Ahem yazı tipi gerçekten geniştir; sınır bilerek gevşek)
        final govde = t.getSize(find.byType(RefreshIndicator)).height;
        expect(govde, greaterThanOrEqualTo(100), reason: 'gövde $govde dp');
        // gün değiştirip geri dönmek de taşırmaz
        await t.tap(find.byTooltip('Sonraki gün'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(_seritMetni(t), isNull);
      });

      testWidgets('320x640, yazı ${olcek}x: menü bitti bandı taşmaz',
          (t) async {
        final depo = SahteDepo(
            _uni(saatler: _saatli), _menu(['2026-10-29', '2026-10-30']));
        await _ac(t, depo,
            simdi: () => _an(10, 35),
            boyut: const Size(320, 640),
            yaziOlcegi: olcek);
        expect(t.takeException(), isNull);
        expect(find.textContaining('henüz yayınlanmadı'), findsOneWidget);
        // renkli bant en çok 3 satır: yine de menü alanı kalır
        expect(t.getSize(find.byType(MenuBandi)).height,
            lessThanOrEqualTo(3 * 24 * olcek + 16));
        expect(t.getSize(find.byType(RefreshIndicator)).height,
            greaterThanOrEqualTo(100));
      });
    }
  });
}
