import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/kalori_hedefi.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/kalori_ayari.dart';
import 'package:yemekhane/widgets/ogun_karti.dart';

/// Ağa ve diske gitmeyen sahte veri deposu.
class SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  SahteDepo(this.liste, this.menuVeri);

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

/// Pazartesi 2 Kasım 2026: öğle 740 + akşam 728 = 1468 kkal; 3 Kasım'da yalnızca öğle var; vejetaryen kalorisiz.
Menu _menu() => Menu('ankara', null, {
      '2026-11-02': {
        'lunch': Ogun([
          YemekOgesi('Mercimek Çorbası', 120, null, 'k1'),
          YemekOgesi('Pirinç Pilavı', 620, null, 'k2'),
        ], 740),
        'dinner': Ogun([YemekOgesi('Fırın Makarna', 728, null, 'k3')], 728),
        'vegetarian': Ogun([YemekOgesi('Sebze Güveç', null, null, 'k4')], null),
      },
      '2026-11-03': {
        'lunch': Ogun([YemekOgesi('Kuru Fasulye', 600, null, 'k5')], 600),
        'dinner': Ogun(const [], null),
      },
    });

SahteDepo _depo() => SahteDepo([
      Universite(
          id: 'ankara',
          ad: 'Ankara Üniversitesi',
          kisa: 'AÜ',
          sehir: 'Ankara',
          kaynak: '',
          ogunler: const ['lunch', 'dinner', 'vegetarian'],
          fiyatlar: const [])
    ], {
      'ankara': _menu()
    });

DateTime _simdi() => DateTime.utc(2026, 11, 2, 10, 0);

final _temalar = <String, ThemeData>{
  'açık': TemaAyari().tema(Brightness.light),
  'koyu': TemaAyari().tema(Brightness.dark),
  'siyah': temaUret(temaRenkleri.first, Brightness.dark, amoled: true),
};

Future<void> _ekranAc(WidgetTester t, Widget ana,
    {Size boyut = const Size(400, 900),
    double yaziOlcegi = 1.0,
    ThemeData? tema}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: tema ?? TemaAyari().tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c)
            .copyWith(textScaler: TextScaler.linear(yaziOlcegi)),
        child: w!),
    home: ana,
  ));
  await t.pumpAndSettle();
}

Future<void> _anaSayfaAc(WidgetTester t, KaloriHedefi kalori,
        {Size boyut = const Size(400, 900), double yaziOlcegi = 1.0}) =>
    _ekranAc(
        t,
        AnaSayfa(
            temaAyari: TemaAyari(),
            depo: _depo(),
            geriBildirim: YerelDepo(),
            simdi: _simdi,
            kaloriHedefi: kalori),
        boyut: boyut,
        yaziOlcegi: yaziOlcegi);

Future<void> _ayarlaraGit(WidgetTester t) async {
  await t.tap(find.byTooltip('Diğer'));
  await t.pumpAndSettle();
  await t.tap(find.text('Ayarlar'));
  await t.pumpAndSettle();
}

Widget _ozet({int? kcal, int? hedef, int? ogleAksam, bool saatFiyat = true}) =>
    SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: OgunOzeti(
          kcal: kcal,
          hedef: hedef,
          ogleAksamKcal: ogleAksam,
          saat: saatFiyat ? const ServisSaati('11:30–14:00', false) : null,
          fiyat: saatFiyat ? 50 : null),
    );

const _uyari = 'Genel bilgidir, tıbbi tavsiye değildir.';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('KaloriHedefi', () {
    test('varsayılan: kapalı, hedef 2000', () {
      final k = KaloriHedefi();
      expect(k.acik, isFalse);
      expect(k.hedef, KaloriHedefi.varsayilan);
      expect(KaloriHedefi.varsayilan, 2000);
      expect(KaloriHedefi.enAz, 1200);
      expect(KaloriHedefi.enCok, 4000);
      expect(KaloriHedefi.adim, 50);
      expect(KaloriHedefi.adimSayisi, 56);
    });

    test('kayıt yoksa yüklemeden sonra da kapalı ve 2000 kalır', () async {
      final k = KaloriHedefi();
      await k.yukle();
      expect(k.yuklendi, isTrue);
      expect(k.acik, isFalse);
      expect(k.hedef, 2000);
    });

    test('kayıtlı açık / hedef değeri okunur', () async {
      SharedPreferences.setMockInitialValues(
          {'kalori_hedefi_acik': true, 'kalori_hedefi': 2450});
      final k = KaloriHedefi();
      await k.yukle();
      expect(k.acik, isTrue);
      expect(k.hedef, 2450);
    });

    test('yukle bir kez çalışır (aynı işlem döner)', () async {
      final k = KaloriHedefi();
      final a = k.yukle(), b = k.yukle();
      expect(identical(a, b), isTrue);
      await a;
    });

    test('acikSec ve hedefSec cihaza kaydedilir, dinleyiciler haberdar olur',
        () async {
      final k = KaloriHedefi();
      var haber = 0;
      k.addListener(() => haber++);
      await k.yukle();
      final yuklemeHaberi = haber;

      await k.acikSec(true);
      await k.hedefSec(2500);
      expect(k.acik, isTrue);
      expect(k.hedef, 2500);
      expect(haber, yuklemeHaberi + 2);

      final p = await SharedPreferences.getInstance();
      expect(p.getBool('kalori_hedefi_acik'), isTrue);
      expect(p.getInt('kalori_hedefi'), 2500);

      final yeni = KaloriHedefi();
      await yeni.yukle();
      expect(yeni.acik, isTrue);
      expect(yeni.hedef, 2500);
    });

    test('aynı değer yeniden seçilince haber verilmez ve yazılmaz', () async {
      final k = KaloriHedefi();
      await k.yukle();
      var haber = 0;
      k.addListener(() => haber++);
      await k.acikSec(false); // zaten kapalı
      await k.hedefSec(2000); // zaten 2000
      expect(haber, 0);
      final p = await SharedPreferences.getInstance();
      expect(p.getKeys(), isEmpty);
    });

    test('hedefSec aralığa çeker ve 50 adımına yuvarlar', () async {
      final k = KaloriHedefi();
      await k.hedefSec(100);
      expect(k.hedef, 1200);
      await k.hedefSec(9999);
      expect(k.hedef, 4000);
      await k.hedefSec(1234);
      expect(k.hedef, 1250);
      await k.hedefSec(1224);
      expect(k.hedef, 1200);
      await k.hedefSec(1225);
      expect(k.hedef, 1250);
      await k.hedefSec(-10);
      expect(k.hedef, 1200);
      for (var v = 1200; v <= 4000; v += 50) {
        expect(KaloriHedefi.hedefiDuzelt(v), v, reason: '$v adım katıdır');
      }
    });

    test('kurucudaki başlangıç değeri de düzeltilir ve yükleme onu ezmez',
        () async {
      final k = KaloriHedefi(acik: true, hedef: 77777);
      expect(k.hedef, 4000);
      final j = KaloriHedefi(acik: true, hedef: 2400);
      await j.yukle(); // kayıt yok: verilen başlangıç değerleri kalır
      expect(j.acik, isTrue);
      expect(j.hedef, 2400);
    });

    group('bozuk kayıt', () {
      Future<KaloriHedefi> yukle(Map<String, Object> kayit) async {
        SharedPreferences.setMockInitialValues(kayit);
        final k = KaloriHedefi();
        await k.yukle();
        return k;
      }

      test('yanlış türdeki değerler yok sayılır: kapalı, 2000', () async {
        for (final kayit in <Map<String, Object>>[
          {'kalori_hedefi_acik': 'evet', 'kalori_hedefi': 'çok'},
          {'kalori_hedefi_acik': 1, 'kalori_hedefi': true},
          {
            'kalori_hedefi_acik': <String>['x'],
            'kalori_hedefi': <String>['y']
          },
          {'kalori_hedefi_acik': 'true', 'kalori_hedefi': double.nan},
          {'kalori_hedefi': double.infinity},
        ]) {
          final k = await yukle(kayit);
          expect(k.acik, isFalse, reason: '$kayit');
          expect(k.hedef, 2000, reason: '$kayit');
          expect(k.yuklendi, isTrue);
        }
      });

      test('bozuk hedef, geçerli "açık" değerini düşürmez (ve tersi)',
          () async {
        var k = await yukle({'kalori_hedefi_acik': true, 'kalori_hedefi': 'x'});
        expect(k.acik, isTrue);
        expect(k.hedef, 2000);
        k = await yukle({'kalori_hedefi_acik': 'x', 'kalori_hedefi': 3000});
        expect(k.acik, isFalse);
        expect(k.hedef, 3000);
      });

      test('aralık dışı ve adım dışı sayılar düzeltilir', () async {
        expect((await yukle({'kalori_hedefi': 5})).hedef, 1200);
        expect((await yukle({'kalori_hedefi': -3000})).hedef, 1200);
        expect((await yukle({'kalori_hedefi': 99999})).hedef, 4000);
        expect((await yukle({'kalori_hedefi': 1e300})).hedef, 4000);
        expect((await yukle({'kalori_hedefi': 1234})).hedef, 1250);
        expect((await yukle({'kalori_hedefi': 2400.0})).hedef, 2400);
        expect((await yukle({'kalori_hedefi': 2024.6})).hedef, 2050);
      });
    });

    test('önbellek temizleme kalori ayarını silmez', () async {
      SharedPreferences.setMockInitialValues({
        'kalori_hedefi_acik': true,
        'kalori_hedefi': 2600,
        'onbellek/ankara/menu.json': '{}',
      });
      expect(await Depo().onbellekTemizle(), 1);
      final k = KaloriHedefi();
      await k.yukle();
      expect(k.acik, isTrue);
      expect(k.hedef, 2600);
    });

    test('dispose sonrası değişiklik hata vermez', () async {
      final k = KaloriHedefi();
      await k.yukle();
      k.dispose();
      await k.acikSec(true);
      await k.hedefSec(3000);
      expect(k.acik, isTrue);
    });
  });

  group('yüzde ve metinler', () {
    test('kaloriYuzdesi: en yakın tam sayı, geçersizde 0', () {
      expect(kaloriYuzdesi(740, 2000), 37);
      expect(kaloriYuzdesi(1000, 2000), 50);
      expect(kaloriYuzdesi(355, 2000), 18); // 17.75
      expect(kaloriYuzdesi(2500, 2000), 125);
      expect(kaloriYuzdesi(0, 2000), 0);
      expect(kaloriYuzdesi(-5, 2000), 0);
      expect(kaloriYuzdesi(500, 0), 0);
    });

    test('yuzdeIyelikEki: son okunan sözcüğe göre', () {
      const beklenen = {
        0: 'ı', // sıfır-ı
        1: 'i', // bir-i
        2: 'si', // iki-si
        3: 'ü', // üç-ü
        4: 'ü', // dört-ü
        5: 'i', // beş-i
        6: 'sı', // altı-sı
        7: 'si', // yedi-si
        8: 'i', // sekiz-i
        9: 'u', // dokuz-u
        10: 'u', // on-u
        11: 'i', // on bir-i
        12: 'si',
        15: 'i', // on beş-i
        16: 'sı',
        20: 'si', // yirmi-si
        23: 'ü',
        30: 'u', // otuz-u
        36: 'sı', // otuz altı-sı
        37: 'si', // otuz yedi-si
        40: 'ı', // kırk-ı
        50: 'si', // elli-si
        60: 'ı', // altmış-ı
        70: 'i', // yetmiş-i
        80: 'i', // seksen-i
        90: 'ı', // doksan-ı
        99: 'u',
        100: 'ü', // yüz-ü
        101: 'i', // yüz bir-i
        125: 'i',
        130: 'u',
        200: 'ü',
        999: 'u',
      };
      beklenen.forEach((n, ek) => expect(yuzdeIyelikEki(n), ek, reason: '%$n'));
    });

    test("kaloriYuzdeMetni: \"Bu öğün günlük hedefinin %37'si\"", () {
      expect(kaloriYuzdeMetni(740, 2000), "Bu öğün günlük hedefinin %37'si");
      expect(kaloriYuzdeMetni(1000, 2000), "Bu öğün günlük hedefinin %50'si");
      expect(kaloriYuzdeMetni(800, 2000), "Bu öğün günlük hedefinin %40'ı");
      expect(kaloriYuzdeMetni(300, 2000), "Bu öğün günlük hedefinin %15'i");
      expect(kaloriYuzdeMetni(2500, 2000), "Bu öğün günlük hedefinin %125'i");
      expect(kaloriYuzdeMetni(2000, 2000), "Bu öğün günlük hedefinin %100'ü");
      // gösterim üst sınırı
      expect(
          kaloriYuzdeMetni(1000000, 1200), "Bu öğün günlük hedefinin %999'u");
    });

    test('ogleAksamKalorisi: iki öğün de dolu ve kalorili olmalı', () {
      Ogun o(int? kcal) => Ogun([YemekOgesi('Yemek', kcal)], kcal);
      expect(ogleAksamKalorisi({'lunch': o(740), 'dinner': o(728)}), 1468);
      // vejetaryen / kahvaltı toplama girmez
      expect(
          ogleAksamKalorisi(
              {'lunch': o(700), 'dinner': o(300), 'vegetarian': o(900)}),
          1000);
      expect(ogleAksamKalorisi({'lunch': o(740)}), isNull);
      expect(ogleAksamKalorisi({'dinner': o(740)}), isNull);
      expect(ogleAksamKalorisi({'lunch': o(740), 'dinner': o(null)}), isNull);
      expect(ogleAksamKalorisi({'lunch': o(0), 'dinner': o(500)}), isNull);
      expect(
          ogleAksamKalorisi({'lunch': o(740), 'dinner': Ogun(const [], null)}),
          isNull);
      expect(ogleAksamKalorisi({}), isNull);
    });
  });

  group('OgunOzeti', () {
    testWidgets('hedef kapalıyken eskisi gibi: çubuk, yüzde ve uyarı yok',
        (t) async {
      await _ekranAc(t, Scaffold(body: _ozet(kcal: 740, ogleAksam: 1468)));
      expect(find.text('Toplam 740 kkal'), findsOneWidget);
      expect(find.text('Servis 11:30–14:00'), findsOneWidget);
      expect(find.text('Öğrenci 50 ₺'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('günlük hedefinin'), findsNothing);
      expect(find.textContaining('Öğle + akşam'), findsNothing);
      expect(find.text(_uyari), findsNothing);
    });

    testWidgets('hedef açıkken ince çubuk, yüzde metni ve uyarı görünür',
        (t) async {
      await _ekranAc(t, Scaffold(body: _ozet(kcal: 740, hedef: 2000)));
      expect(find.text('Toplam 740 kkal'), findsOneWidget);
      expect(find.text("Bu öğün günlük hedefinin %37'si"), findsOneWidget);
      expect(find.text(_uyari), findsOneWidget);
      final cubuk = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(cubuk.value, closeTo(0.37, 1e-9));
      expect(cubuk.minHeight, lessThanOrEqualTo(8)); // ince
      expect(find.textContaining('Öğle + akşam'), findsNothing);
      // saat ve fiyat yine görünür
      expect(find.text('Servis 11:30–14:00'), findsOneWidget);
      expect(find.text('Öğrenci 50 ₺'), findsOneWidget);
    });

    testWidgets('öğle + akşam toplamı satırı yalnızca verilince çıkar',
        (t) async {
      await _ekranAc(
          t, Scaffold(body: _ozet(kcal: 740, hedef: 2000, ogleAksam: 1468)));
      expect(find.text('Öğle + akşam: 1468 kkal'), findsOneWidget);
    });

    testWidgets('hedefi aşan öğünde çubuk dolu kalır, yüzde 100 üstü yazılır',
        (t) async {
      await _ekranAc(t, Scaffold(body: _ozet(kcal: 2500, hedef: 2000)));
      expect(find.text("Bu öğün günlük hedefinin %125'i"), findsOneWidget);
      expect(
          t
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          1.0);
    });

    testWidgets('kalorisiz öğünde hedef bölümü tümüyle gizlidir', (t) async {
      await _ekranAc(t, Scaffold(body: _ozet(kcal: null, hedef: 2000)));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('günlük hedefinin'), findsNothing);
      expect(find.text(_uyari), findsNothing);
      expect(find.textContaining('Toplam'), findsNothing);
      // saat ve fiyat kartı yine var
      expect(find.text('Servis 11:30–14:00'), findsOneWidget);

      // kalori sıfırsa da (anlamsız veri) gizli
      await _ekranAc(
          t, Scaffold(body: _ozet(kcal: 0, hedef: 2000, ogleAksam: 1468)));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Öğle + akşam'), findsNothing);
      expect(find.text(_uyari), findsNothing);
    });

    testWidgets('sıfır / geçersiz hedefte bölüm gösterilmez', (t) async {
      await _ekranAc(t, Scaffold(body: _ozet(kcal: 740, hedef: 0)));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(_uyari), findsNothing);
    });

    testWidgets('çubuk süstür: ekran okuyucuya ayrıca okunmaz', (t) async {
      await _ekranAc(t, Scaffold(body: _ozet(kcal: 740, hedef: 2000)));
      expect(
          find.descendant(
              of: find.byType(ExcludeSemantics),
              matching: find.byType(LinearProgressIndicator)),
          findsOneWidget);
    });

    for (final e in _temalar.entries) {
      for (final olcek in [1.0, 1.5, 2.0]) {
        testWidgets('320x640, yazı ${olcek}x, ${e.key} tema: taşma yok',
            (t) async {
          await _ekranAc(t,
              Scaffold(body: _ozet(kcal: 1654, hedef: 1200, ogleAksam: 3301)),
              boyut: const Size(320, 640), yaziOlcegi: olcek, tema: e.value);
          expect(t.takeException(), isNull);
          expect(find.text("Bu öğün günlük hedefinin %138'i"), findsOneWidget);
          expect(find.text('Öğle + akşam: 3301 kkal'), findsOneWidget);
          expect(find.text(_uyari), findsOneWidget);
        });
      }
    }

    test('tüm paletlerde çubuk dolgusu zemininden >= 3:1, yazı >= 4.5:1', () {
      for (final p in temaRenkleri) {
        for (final (parlaklik, amoled) in [
          (Brightness.light, false),
          (Brightness.dark, false),
          (Brightness.dark, true),
        ]) {
          final r = renkSemasiUret(p, parlaklik, amoled: amoled);
          final neden = '${p.kimlik} $parlaklik amoled=$amoled';
          expect(kontrastOrani(r.primary, r.primaryContainer),
              greaterThanOrEqualTo(3.0),
              reason: 'çubuk: $neden');
          expect(kontrastOrani(r.onPrimaryContainer, r.primaryContainer),
              greaterThanOrEqualTo(4.5),
              reason: 'yazı: $neden');
        }
      }
    });
  });

  group('OgunKarti', () {
    Widget kart(KaloriHedefi? k, {int? ogleAksam}) => OgunKarti(
        ogun: _menu().gunler['2026-11-02']!['lunch']!,
        yemekFoto: (_) => null,
        geriBildirim: YerelDepo(),
        slot: 's',
        uniId: 'ankara',
        kaloriHedefi: k,
        ogleAksamKcal: ogleAksam);

    testWidgets('kalori ayarı verilmezse hedef gösterilmez', (t) async {
      await _ekranAc(t, Scaffold(body: kart(null, ogleAksam: 1468)));
      expect(find.textContaining('günlük hedefinin'), findsNothing);
      expect(find.text(_uyari), findsNothing);
    });

    testWidgets('ayar değişince yalnızca özet güncellenir (anında)', (t) async {
      final k = KaloriHedefi();
      await _ekranAc(t, Scaffold(body: kart(k, ogleAksam: 1468)));
      expect(find.textContaining('günlük hedefinin'), findsNothing);

      await k.acikSec(true);
      await t.pump();
      expect(find.text("Bu öğün günlük hedefinin %37'si"), findsOneWidget);
      expect(find.text('Öğle + akşam: 1468 kkal'), findsOneWidget);

      await k.hedefSec(1200); // 740 / 1200 = %61.67
      await t.pump();
      expect(find.text("Bu öğün günlük hedefinin %62'si"), findsOneWidget);

      await k.acikSec(false);
      await t.pump();
      expect(find.textContaining('günlük hedefinin'), findsNothing);
      expect(find.text(_uyari), findsNothing);
    });
  });

  group('KaloriHedefiAyari (Ayarlar bölümü)', () {
    Future<KaloriHedefi> ac(WidgetTester t,
        {bool acik = false,
        int hedef = 2000,
        Size boyut = const Size(400, 900),
        double yaziOlcegi = 1.0,
        ThemeData? tema}) async {
      final k = KaloriHedefi(acik: acik, hedef: hedef);
      await k.yukle(); // uygulamada main() ya da AnaSayfa yükler
      await _ekranAc(
          t,
          Scaffold(
              body: SingleChildScrollView(
                  child: KaloriHedefiAyari(kaloriHedefi: k))),
          boyut: boyut,
          yaziOlcegi: yaziOlcegi,
          tema: tema);
      return k;
    }

    testWidgets('kapalıyken yalnızca anahtar var; dokununca seçici açılır',
        (t) async {
      final k = await ac(t);
      expect(find.text('Günlük kalori hedefi'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(t.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.byType(Slider), findsNothing);
      expect(find.text(_uyari), findsNothing);

      await t
          .tap(find.text('Günlük kalori hedefi')); // satırın tamamı dokunulur
      await t.pumpAndSettle();
      expect(k.acik, isTrue);
      expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Günlük hedef: 2000 kkal'), findsOneWidget);
      expect(find.text(_uyari), findsOneWidget);

      final p = await SharedPreferences.getInstance();
      expect(p.getBool('kalori_hedefi_acik'), isTrue);

      await t.tap(find.byType(Switch)); // kapat
      await t.pumpAndSettle();
      expect(k.acik, isFalse);
      expect(find.byType(Slider), findsNothing);
      expect(k.hedef, 2000); // hedef değeri korunur
    });

    testWidgets('kaydırıcı 1200-4000 arası 50 adımlıdır', (t) async {
      await ac(t, acik: true);
      final s = t.widget<Slider>(find.byType(Slider));
      expect(s.min, 1200);
      expect(s.max, 4000);
      expect(s.divisions, 56);
      expect(s.value, 2000);
    });

    testWidgets('kaydırınca hedef 50 katı olarak değişir ve kaydedilir',
        (t) async {
      final k = await ac(t, acik: true);
      await t.drag(find.byType(Slider), const Offset(80, 0));
      await t.pumpAndSettle();
      expect(k.hedef, greaterThan(2000));
      expect(k.hedef % 50, 0);
      expect(k.hedef, lessThanOrEqualTo(4000));
      expect(find.text('Günlük hedef: ${k.hedef} kkal'), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('kalori_hedefi'), k.hedef);

      await t.drag(find.byType(Slider), const Offset(-2000, 0));
      await t.pumpAndSettle();
      expect(k.hedef, 1200); // sol uç
      await t.drag(find.byType(Slider), const Offset(2000, 0));
      await t.pumpAndSettle();
      expect(k.hedef, 4000); // sağ uç
    });

    testWidgets('eksi ve artı düğmeleri 50 kkal oynatır, uçlarda pasif olur',
        (t) async {
      final k = await ac(t, acik: true);
      await t.tap(find.byTooltip('Hedefi artır'));
      await t.pumpAndSettle();
      expect(k.hedef, 2050);
      await t.tap(find.byTooltip('Hedefi azalt'));
      await t.tap(find.byTooltip('Hedefi azalt'));
      await t.pumpAndSettle();
      expect(k.hedef, 1950);
      expect(find.text('Günlük hedef: 1950 kkal'), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('kalori_hedefi'), 1950);

      await k.hedefSec(1200);
      await t.pumpAndSettle();
      expect(
          t
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
              .onPressed,
          isNull);
      expect(
          t
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
              .onPressed,
          isNotNull);

      await k.hedefSec(4000);
      await t.pumpAndSettle();
      expect(
          t
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
              .onPressed,
          isNull);
    });

    testWidgets('dokunma hedefleri >= 48dp, kaydırıcının adı ve değeri okunur',
        (t) async {
      final anlam = t.ensureSemantics();
      await ac(t, acik: true);
      for (final ikon in [Icons.remove, Icons.add]) {
        final boyut = t.getSize(find.widgetWithIcon(IconButton, ikon));
        expect(boyut.width, greaterThanOrEqualTo(48), reason: '$ikon');
        expect(boyut.height, greaterThanOrEqualTo(48), reason: '$ikon');
      }
      expect(t.getSize(find.byType(SwitchListTile)).height,
          greaterThanOrEqualTo(48));
      final veri = t.getSemantics(find.byType(Slider)).getSemanticsData();
      expect(veri.label, 'Günlük kalori hedefi');
      expect(veri.value, '2000 kkal');
      expect(veri.increasedValue, '2050 kkal');
      expect(veri.decreasedValue, '1950 kkal');
      expect(veri.hasAction(SemanticsAction.increase), isTrue);
      expect(veri.hasAction(SemanticsAction.decrease), isTrue);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      anlam.dispose();
    });

    for (final e in _temalar.entries) {
      for (final olcek in [1.5, 2.0]) {
        testWidgets('320x640, yazı ${olcek}x, ${e.key} tema: taşma yok',
            (t) async {
          final anlam = t.ensureSemantics();
          await ac(t,
              acik: true,
              boyut: const Size(320, 640),
              yaziOlcegi: olcek,
              tema: e.value);
          expect(t.takeException(), isNull);
          expect(find.text('Günlük hedef: 2000 kkal'), findsOneWidget);
          await expectLater(t, meetsGuideline(textContrastGuideline));
          anlam.dispose();
        });
      }
    }
  });

  group('AnaSayfa + Ayarlar bütünleşik', () {
    testWidgets(
        'Ayarlar\'dan hedef açılınca öğün kartında yüzde, öğle + akşam ve uyarı çıkar',
        (t) async {
      final k = KaloriHedefi();
      await _anaSayfaAc(t, k);
      expect(find.text('Mercimek Çorbası'), findsOneWidget); // öğle sekmesi
      expect(find.textContaining('günlük hedefinin'), findsNothing);
      expect(find.text(_uyari), findsNothing);

      await _ayarlaraGit(t);
      expect(find.text('Günlük kalori hedefi'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      await t.tap(find.text('Günlük kalori hedefi'));
      await t.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);

      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text("Bu öğün günlük hedefinin %37'si"), findsOneWidget);
      expect(find.text('Öğle + akşam: 1468 kkal'), findsOneWidget);
      expect(find.text(_uyari), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // akşam sekmesi: 728 / 2000 = %36,4 -> %36; toplam satırı orada da var
      await t.tap(find.text('Akşam'));
      await t.pumpAndSettle();
      expect(find.text("Bu öğün günlük hedefinin %36'sı"), findsOneWidget);
      expect(find.text('Öğle + akşam: 1468 kkal'), findsOneWidget);

      // vejetaryen kalorisiz: bölüm gizli
      await t.tap(find.text('Vejetaryen'));
      await t.pumpAndSettle();
      expect(find.text('Sebze Güveç'), findsOneWidget);
      expect(find.textContaining('günlük hedefinin'), findsNothing);
      expect(find.textContaining('Öğle + akşam'), findsNothing);
      expect(find.text(_uyari), findsNothing);

      // hedef değişince kart da değişir
      await k.hedefSec(1200);
      await t.tap(find.text('Öğle'));
      await t.pumpAndSettle();
      expect(find.text("Bu öğün günlük hedefinin %62'si"), findsOneWidget);
    });

    testWidgets('akşamı boş günde toplam satırı çıkmaz, yüzde çıkar',
        (t) async {
      final k = KaloriHedefi(acik: true);
      await _anaSayfaAc(t, k);
      await t.tap(find.byTooltip('Sonraki gün')); // 3 Kasım: yalnızca öğle
      await t.pumpAndSettle();
      expect(find.text('Kuru Fasulye'), findsOneWidget);
      expect(find.text("Bu öğün günlük hedefinin %30'u"), findsOneWidget);
      expect(find.textContaining('Öğle + akşam'), findsNothing);
    });

    testWidgets('kayıtlı açık hedef uygulama açılınca uygulanır', (t) async {
      SharedPreferences.setMockInitialValues(
          {'kalori_hedefi_acik': true, 'kalori_hedefi': 1200});
      await _anaSayfaAc(t, KaloriHedefi());
      expect(find.text("Bu öğün günlük hedefinin %62'si"), findsOneWidget);
    });

    testWidgets('bozuk kayıt uygulamayı düşürmez: hedef kapalı kalır',
        (t) async {
      SharedPreferences.setMockInitialValues(
          {'kalori_hedefi_acik': 'evet', 'kalori_hedefi': 'çok'});
      await _anaSayfaAc(t, KaloriHedefi());
      expect(t.takeException(), isNull);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(find.textContaining('günlük hedefinin'), findsNothing);
    });

    testWidgets(
        'ayar verilmezse AnaSayfa kendi ayarını kurar ve kayıtlıyı okur',
        (t) async {
      SharedPreferences.setMockInitialValues(
          {'kalori_hedefi_acik': true, 'kalori_hedefi': 2000});
      await _ekranAc(
          t,
          AnaSayfa(
              temaAyari: TemaAyari(),
              depo: _depo(),
              geriBildirim: YerelDepo(),
              simdi: _simdi));
      expect(find.text("Bu öğün günlük hedefinin %37'si"), findsOneWidget);
    });

    testWidgets('enjekte edilen ayar AnaSayfa kapanınca atılmaz', (t) async {
      final k = KaloriHedefi(acik: true);
      await _anaSayfaAc(t, k);
      await t.pumpWidget(const SizedBox()); // ana sayfa kapandı
      k.addListener(() {}); // atılmış olsaydı hata verirdi
      await k.hedefSec(3000);
      expect(k.hedef, 3000);
      expect(t.takeException(), isNull);
    });

    testWidgets('320x640, yazı 1.5x: açık hedefle ana sayfa ve Ayarlar taşmaz',
        (t) async {
      final k = KaloriHedefi(acik: true);
      await _anaSayfaAc(t, k, boyut: const Size(320, 640), yaziOlcegi: 1.5);
      expect(t.takeException(), isNull);
      expect(find.text("Bu öğün günlük hedefinin %37'si"), findsOneWidget);
      await _ayarlaraGit(t);
      expect(t.takeException(), isNull);
      expect(find.text('Günlük hedef: 2000 kkal'), findsOneWidget);
    });
  });
}
