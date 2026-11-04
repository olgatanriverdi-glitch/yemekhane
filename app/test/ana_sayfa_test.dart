import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

/// Ağa ve diske gitmeyen sahte veri deposu; çağrıları sayar, istenince hata atar ya da bekletir.
class SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  bool hataAt = false;
  int menuCagri = 0;
  String? secili;

  /// Doluysa menü isteği bu tamamlanana kadar bekler (yüklenirken ekranı yakalamak için).
  Completer<void>? kapi;

  SahteDepo(this.liste, this.menuVeri);

  @override
  Future<List<Universite>> universiteler() async => liste;

  @override
  Future<Menu> menu(String universiteId) async {
    menuCagri++;
    if (kapi != null) await kapi!.future;
    if (hataAt) throw Exception('ağ yok');
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

Universite _uni(String id, String ad, List<String> ogunler) => Universite(
    id: id,
    ad: ad,
    kisa: id,
    sehir: 'Ankara',
    kaynak: '',
    ogunler: ogunler,
    fiyatlar: const []);

const _corbalar = {
  '2026-11-02': 'Mercimek Çorbası',
  '2026-11-03': 'Ezogelin Çorbası',
  '2026-11-04': 'Domates Çorbası',
  '2026-11-05': 'Tarhana Çorbası',
  '2026-11-06': 'Yayla Çorbası',
};

Menu _ankaraMenusu() => Menu('ankara', null, {
      for (final e in _corbalar.entries)
        e.key: {
          'lunch': Ogun([
            YemekOgesi(e.value, 120),
            YemekOgesi('Pirinç Pilavı', 300),
          ], 420),
          'dinner': Ogun([YemekOgesi('Fırın Makarna', 500)], 500),
        }
    });

Menu _gaziMenusu() => Menu('gazi', null, {
      '2026-11-02': {
        'lunch': Ogun([YemekOgesi('Gazi Kuru Fasulye', 350)], 350)
      }
    });

SahteDepo _depo() => SahteDepo([
      _uni('ankara', 'Ankara Üniversitesi', ['lunch', 'dinner']),
      _uni('gazi', 'Gazi Üniversitesi', ['lunch']),
    ], {
      'ankara': _ankaraMenusu(),
      'gazi': _gaziMenusu(),
    })
      ..secili = 'ankara'; // kayıtlı okul var: ilk açılış karşılaması çıkmaz

/// Pazartesi 2 Kasım 2026, saat 10:00 (Türkiye duvar saati).
DateTime _sabahSimdi() => DateTime.utc(2026, 11, 2, 10, 0);

Future<void> _ac(WidgetTester t, SahteDepo depo,
    {DateTime Function()? simdi,
    Size boyut = const Size(400, 900),
    double yaziOlcegi = 1.0,
    bool hareketKapali = false,
    bool bekle = true}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari();
  await t.pumpWidget(MaterialApp(
    theme: ayar.tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(yaziOlcegi),
            disableAnimations: hareketKapali),
        child: w!),
    home: AnaSayfa(
        temaAyari: ayar,
        depo: depo,
        geriBildirim: YerelDepo(),
        simdi: simdi ?? _sabahSimdi),
  ));
  if (bekle) await t.pumpAndSettle();
}

/// Verilen yemek adını saran gün geçişi kaymasının (SlideTransition) anlık yatay kayması.
double _kayma(WidgetTester t, String yemek) {
  final kaymalar = find.ancestor(
      of: find.text(yemek),
      matching: find.descendant(
          of: find.byType(AnimatedSwitcher),
          matching: find.byType(SlideTransition)));
  expect(kaymalar, findsOneWidget, reason: yemek);
  return t.widget<SlideTransition>(kaymalar).position.value.dx;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('açılışta okul adı ve bugünün menüsü görünür', (t) async {
    final depo = _depo();
    await _ac(t, depo);
    expect(find.text('Ankara Üniversitesi'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Mercimek Çorbası'), findsOneWidget);
    expect(find.text('Pirinç Pilavı'), findsOneWidget);
    expect(find.text('Toplam 420 kkal'), findsOneWidget);
    expect(find.byType(IskeletGovde), findsNothing);
    expect(depo.secili, 'ankara'); // seçim kaydedilir
    expect(depo.menuCagri, 1);
  });

  testWidgets('sahte saat öğleden sonraysa akşam menüsü açılır', (t) async {
    await _ac(t, _depo(), simdi: () => DateTime.utc(2026, 11, 2, 16, 30));
    expect(find.text('Fırın Makarna'), findsOneWidget);
    expect(find.text('Mercimek Çorbası'), findsNothing);
  });

  testWidgets(
      'sonraki gün oku ertesi günün menüsünü açar, önceki gün geri döner',
      (t) async {
    await _ac(t, _depo());
    await t.tap(find.byTooltip('Sonraki gün'));
    await t.pumpAndSettle();
    expect(find.text('Yarın'), findsOneWidget);
    expect(find.text('Ezogelin Çorbası'), findsOneWidget);
    expect(find.text('Mercimek Çorbası'), findsNothing);

    await t.tap(find.byTooltip('Önceki gün'));
    await t.pumpAndSettle();
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Mercimek Çorbası'), findsOneWidget);
  });

  testWidgets('sola fling sonraki güne, sağa fling önceki güne geçirir',
      (t) async {
    await _ac(t, _depo());
    await t.fling(find.byType(OgunKarti), const Offset(-300, 0), 1000);
    await t.pumpAndSettle();
    expect(find.text('Yarın'), findsOneWidget);
    expect(find.text('Ezogelin Çorbası'), findsOneWidget);

    await t.fling(find.byType(OgunKarti), const Offset(300, 0), 1000);
    await t.pumpAndSettle();
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Mercimek Çorbası'), findsOneWidget);
  });

  group('yön duyarlı geçiş', () {
    testWidgets('sonraki gün: yeni içerik sağdan gelir, eskisi sola çıkar',
        (t) async {
      await _ac(t, _depo());
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(_kayma(t, 'Ezogelin Çorbası'), greaterThan(0));
      expect(_kayma(t, 'Mercimek Çorbası'), lessThan(0));
      await t.pumpAndSettle();
      expect(find.text('Mercimek Çorbası'), findsNothing);
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
    });

    testWidgets('önceki gün: yeni içerik soldan gelir, eskisi sağa çıkar',
        (t) async {
      await _ac(t, _depo());
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Önceki gün'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(_kayma(t, 'Mercimek Çorbası'), lessThan(0));
      expect(_kayma(t, 'Ezogelin Çorbası'), greaterThan(0));
      await t.pumpAndSettle();
    });

    testWidgets('öğün değişince yalnızca solma olur, kayma olmaz', (t) async {
      await _ac(t, _depo());
      await t.tap(find.text('Akşam'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(
          find.descendant(
              of: find.byType(AnimatedSwitcher),
              matching: find.byType(SlideTransition)),
          findsNothing);
      expect(find.text('Mercimek Çorbası'),
          findsOneWidget); // eski, solarak çıkıyor
      expect(find.text('Fırın Makarna'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('Mercimek Çorbası'), findsNothing);
    });

    testWidgets('hareket kapalıysa gün geçişi anında biter', (t) async {
      await _ac(t, _depo(), hareketKapali: true);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pump();
      await t.pump();
      expect(find.text('Mercimek Çorbası'), findsNothing);
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
    });
  });

  group('aşağı çekip yenileme', () {
    testWidgets('menüyü yeniden ister, iskelet göstermez, menü ekranda kalır',
        (t) async {
      final depo = _depo();
      await _ac(t, depo);
      expect(depo.menuCagri, 1);

      depo.kapi = Completer<void>(); // yenileme sürerken ekranı yakala
      await t.fling(find.byType(OgunKarti), const Offset(0, 300), 1000);
      // gösterge oturunca (~150 ms) yenileme başlar
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 200));
      expect(depo.menuCagri, 2);
      expect(find.byType(IskeletGovde), findsNothing);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);

      depo.kapi!.complete();
      await t.pumpAndSettle();
      expect(find.byType(IskeletGovde), findsNothing);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(find.text('Menü yüklenemedi. İnternet bağlantını kontrol et.'),
          findsNothing);
    });

    testWidgets('boş (yemek yok) günde de çekilince yenilenir', (t) async {
      final depo = _depo();
      // 3 Kasım Salı için okul menü yayınlamamış: gün çubuğunda yer alır, içeriği boştur
      depo.menuVeri['ankara']!.gunler.remove('2026-11-03');
      await _ac(t, depo);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(find.text('Bu gün yemek yok'), findsOneWidget);
      final onceki = depo.menuCagri;
      await t.fling(find.byType(YemekYok), const Offset(0, 300), 1000);
      await t.pumpAndSettle();
      expect(depo.menuCagri, onceki + 1);
      expect(find.byType(IskeletGovde), findsNothing);
    });

    testWidgets('hata olursa menü kalır, kısa bildirim çıkar', (t) async {
      final depo = _depo();
      await _ac(t, depo);
      depo.hataAt = true;
      await t.fling(find.byType(OgunKarti), const Offset(0, 300), 1000);
      await t.pumpAndSettle();
      expect(find.text('Menü yüklenemedi. İnternet bağlantını kontrol et.'),
          findsOneWidget); // SnackBar
      expect(find.text('Tekrar dene'), findsNothing); // hata ekranı değil
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
    });

    testWidgets('Yenile düğmesi eskisi gibi iskelet gösterir', (t) async {
      final depo = _depo();
      await _ac(t, depo);
      depo.kapi = Completer<void>();
      await t.tap(find.byTooltip('Diğer')); // Yenile artık taşma menüsünde
      await t.pumpAndSettle();
      await t.tap(find.text('Yenile'));
      await t.pump();
      expect(find.byType(IskeletGovde), findsOneWidget);
      depo.kapi!.complete();
      await t.pumpAndSettle();
      expect(find.byType(IskeletGovde), findsNothing);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(depo.menuCagri, 2);
    });
  });

  testWidgets('depo hata atınca "Menü yüklenemedi" ve "Tekrar dene" çıkar',
      (t) async {
    final depo = _depo()..hataAt = true;
    await _ac(t, depo);
    expect(find.textContaining('Menü yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byType(OgunKarti), findsNothing);

    depo.hataAt = false;
    await t.tap(find.text('Tekrar dene'));
    await t.pumpAndSettle();
    expect(find.textContaining('Menü yüklenemedi'), findsNothing);
    expect(find.text('Mercimek Çorbası'), findsOneWidget);
  });

  testWidgets('başlığa dokunup okul seçilince o okulun menüsü açılır',
      (t) async {
    final depo = _depo();
    await _ac(t, depo);
    await t.tap(find.text('Ankara Üniversitesi'));
    await t.pumpAndSettle();
    await t.tap(find.text('Gazi Üniversitesi'));
    await t.pumpAndSettle();
    expect(find.text('Gazi Üniversitesi'), findsOneWidget); // AppBar başlığı
    expect(find.text('Gazi Kuru Fasulye'), findsOneWidget);
    expect(depo.secili, 'gazi');
  });

  testWidgets('320x640 ve yazı 1.5x: ana sayfa taşmaz', (t) async {
    await _ac(t, _depo(), boyut: const Size(320, 640), yaziOlcegi: 1.5);
    expect(t.takeException(), isNull);
    expect(find.text('Mercimek Çorbası'), findsOneWidget);
    await t.tap(find.byTooltip('Sonraki gün'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  group('üst çubuk eylemleri', () {
    testWidgets(
        'Yemek ara, Favoriler ve Diğer görünür; Tema, Yenile ve Ayarlar Diğer menüsündedir',
        (t) async {
      await _ac(t, _depo());
      expect(find.byTooltip('Yemek ara'), findsOneWidget);
      expect(find.byTooltip('Favoriler'), findsOneWidget);
      expect(find.byTooltip('Diğer'), findsOneWidget);
      // artık ayrı simge değiller
      expect(find.byTooltip('Ayarlar'), findsNothing);
      expect(find.byTooltip('Tema'), findsNothing);
      expect(find.byTooltip('Yenile'), findsNothing);

      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Yenile'), findsOneWidget);
      expect(find.text('Ayarlar'), findsOneWidget);
    });

    testWidgets('Diğer > Tema tema seçiciyi açar', (t) async {
      await _ac(t, _depo());
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tema'));
      await t.pumpAndSettle();
      expect(find.text('Görünüm'), findsOneWidget);
      expect(find.text('Siyah'), findsOneWidget);
    });

    testWidgets('menü yüklenirken Diğer > Yenile pasiftir', (t) async {
      final depo = _depo()..kapi = Completer<void>();
      await _ac(t, depo, bekle: false);
      await t.pump();
      expect(find.byType(IskeletGovde), findsOneWidget);
      await t.tap(find.byTooltip('Diğer'));
      // iskelet sonsuz animasyonlu: pumpAndSettle yerine süreli pump
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      final yenile = t.widget<PopupMenuItem<VoidCallback>>(
          find.widgetWithText(PopupMenuItem<VoidCallback>, 'Yenile'));
      expect(yenile.enabled, isFalse);
      await t.tapAt(const Offset(5, 5));
      await t.pump(const Duration(milliseconds: 400));
      depo.kapi!.complete();
      await t.pumpAndSettle();
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
    });

    for (final olcek in [1.0, 1.5]) {
      testWidgets(
          '320x640, yazı ${olcek}x, çok uzun okul adı: başlık sıkışır ama taşma olmaz, simgeler 48dp',
          (t) async {
        final depo = SahteDepo([
          _uni(
              'ankara',
              'Ankara Hacı Bayram Veli Sağlık Bilimleri ve Teknoloji Üniversitesi',
              ['lunch', 'dinner']),
        ], {
          'ankara': _ankaraMenusu()
        })
          ..secili = 'ankara';
        await _ac(t, depo, boyut: const Size(320, 640), yaziOlcegi: olcek);
        expect(t.takeException(), isNull);
        for (final dugme in [
          find.widgetWithIcon(IconButton, Icons.search),
          find.widgetWithIcon(IconButton, Icons.favorite_border),
          find.byType(PopupMenuButton<VoidCallback>),
        ]) {
          final boyut = t.getSize(dugme);
          expect(boyut.width, greaterThanOrEqualTo(48));
          expect(boyut.height, greaterThanOrEqualTo(48));
        }
        // başlık üç simgenin soluna sığar, üst üste binmez
        final baslik = t.getRect(find.byIcon(Icons.arrow_drop_down));
        final ilkSimge = t.getRect(find.byTooltip('Yemek ara'));
        expect(baslik.right, lessThanOrEqualTo(ilkSimge.left));
        await t.tap(find.byTooltip('Diğer'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('Tema'), findsOneWidget);
        expect(find.text('Ayarlar'), findsOneWidget);
      });
    }
  });

  test('widgets bölmesi sonrası eski adlar home.dart üzerinden erişilir', () {
    expect(yemekIkonu('Mercimek Çorbası'), Icons.soup_kitchen);
    expect(const YemekResmi(), isA<Widget>());
  });
}
