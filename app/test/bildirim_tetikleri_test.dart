// Günlük menü bildirimi: ana sayfanın planlamayı ne zaman tetiklediği (menü yüklenince, okul değişince,
// yenilemede, favori değişince, Ayarlar'dan açılıp kapanınca) ve ayar kapalıyken hiçbir eklenti kodunun
// çalışmadığı. Gerçek eklenti yok: sahte servis çağrıları kaydeder (test/sahte_bildirim.dart).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/bildirim_ayari.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/university_picker.dart';
import 'package:yemekhane/tema.dart';

import 'sahte_bildirim.dart';

/// Ağa ve diske gitmeyen sahte veri deposu. [secili] boşsa kayıtlı okul yoktur (ilk açılış).
class _SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  String? secili;
  bool hataAt = false;
  _SahteDepo(this.liste, this.menuVeri, {this.secili});

  @override
  Future<List<Universite>> universiteler() async => liste;

  @override
  Future<Menu> menu(String universiteId) async {
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

Universite _uni(String id, String ad, String kisa) => Universite(
    id: id,
    ad: ad,
    kisa: kisa,
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

YemekOgesi _y(String ad, String anahtar) => YemekOgesi(ad, null, null, anahtar);

/// 2 - 6 Kasım 2026 (Pzt - Cum): her gün öğlede çorba + pilav; 5 Kasım'da Mantı.
Menu _ankaraMenusu() => Menu('ankara', null, {
      '2026-11-02': {
        'lunch': Ogun(
            [_y('Mercimek Çorbası', 'mercimek'), _y('Pilav', 'pilav')], null)
      },
      '2026-11-03': {
        'lunch': Ogun(
            [_y('Ezogelin Çorbası', 'ezogelin'), _y('Pilav', 'pilav')], null)
      },
      '2026-11-04': {
        'lunch':
            Ogun([_y('Domates Çorbası', 'domates'), _y('Pilav', 'pilav')], null)
      },
      '2026-11-05': {
        'lunch': Ogun([_y('Mantı', 'manti'), _y('Cacık', 'cacik')], null)
      },
      '2026-11-06': {
        'lunch':
            Ogun([_y('Yayla Çorbası', 'yayla'), _y('Pilav', 'pilav')], null)
      },
    });

Menu _gaziMenusu() => Menu('gazi', null, {
      for (final g in [2, 3, 4])
        '2026-11-0$g': {
          'lunch': Ogun([_y('Gazi Kuru Fasulye', 'fasulye')], null)
        }
    });

_SahteDepo _depo({String? secili = 'ankara'}) => _SahteDepo([
      _uni('ankara', 'Ankara Üniversitesi', 'AÜ'),
      _uni('gazi', 'Gazi Üniversitesi', 'GÜ'),
    ], {
      'ankara': _ankaraMenusu(),
      'gazi': _gaziMenusu(),
    }, secili: secili);

/// Pazartesi 2 Kasım 2026, saat 10:00 (Türkiye duvar saati).
DateTime _sabah() => DateTime.utc(2026, 11, 2, 10, 0);

Future<void> _ac(WidgetTester t, _SahteDepo depo,
    {BildirimAyari? bildirim,
    FavoriDeposu? favoriler,
    DateTime Function()? simdi}) async {
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
        simdi: simdi ?? _sabah,
        bildirim: bildirim,
        favoriler: favoriler),
  ));
  await t.pumpAndSettle();
}

Future<BildirimAyari> _ayar(SahteBildirimServisi s, {bool acik = false}) async {
  final a = BildirimAyari(servis: s, acik: acik);
  await a.yukle();
  addTearDown(a.dispose);
  return a;
}

Future<void> _okulDegistir(WidgetTester t, String mevcut, String hedef) async {
  await t.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text(mevcut)));
  await t.pumpAndSettle();
  await t.tap(find.descendant(
      of: find.byType(UniversitePicker), matching: find.text(hedef)));
  await t.pumpAndSettle();
}

Future<void> _digerdenSec(WidgetTester t, String ad) async {
  await t.tap(find.byTooltip('Diğer'));
  await t.pumpAndSettle();
  await t.tap(find.text(ad));
  await t.pumpAndSettle();
}

Future<void> _asagiCek(WidgetTester t) async {
  await t.fling(find.byType(Scrollable).last, const Offset(0, 300), 1000);
  await t.pumpAndSettle();
}

const _iptalPlan = ['iptal', 'planla'];

/// Ayarlar'da iki anahtar var (kalori hedefi ve bildirim): bildirim anahtarı başlığından bulunur.
Finder get _anahtar =>
    find.widgetWithText(SwitchListTile, 'Günlük menü bildirimi');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ayar kapalıyken eklentiye dokunulmaz', () {
    testWidgets(
        'açılış, gün geçişi, okul değişimi ve yenileme servise hiç dokunmaz',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s));
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      await _okulDegistir(t, 'Ankara Üniversitesi', 'Gazi Üniversitesi');
      await _digerdenSec(t, 'Yenile');
      await _asagiCek(t);
      expect(s.cagrilar, isEmpty);
    });

    testWidgets(
        'varsayılan ayarla (servis verilmeden) açılan ana sayfa eklenti kanalına hiç çağrı yapmaz',
        (t) async {
      const kanal = MethodChannel('dexterous.com/flutter/local_notifications');
      final gelen = <MethodCall>[];
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, (c) async {
        gelen.add(c);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null));
      await _ac(t,
          _depo()); // bildirim verilmedi: AnaSayfa kendi BildirimAyari'nı (kapalı) kurar
      await _okulDegistir(t, 'Ankara Üniversitesi', 'Gazi Üniversitesi');
      await _digerdenSec(t, 'Yenile');
      expect(gelen, isEmpty,
          reason:
              'ayar kapalıyken eklenti başlatılmaz, planlama / iptal yapılmaz');
      expect(t.takeException(), isNull);
    });
  });

  group('ayar açıkken yeniden planlama', () {
    testWidgets(
        'menü yüklenince önce iptal sonra plan: bugünden itibaren menülü günler, 10:30',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s, acik: true));
      expect(s.cagrilar, _iptalPlan);
      expect(s.sonPlan.map((b) => b.kimlik),
          [20261102, 20261103, 20261104, 20261105, 20261106]);
      expect(s.sonPlan.first.zaman, DateTime.utc(2026, 11, 2, 10, 30));
      expect(s.sonPlan.first.baslik, 'AÜ · bugün öğle');
      expect(s.sonPlan.first.metin, 'Mercimek Çorbası, Pilav');
    });

    testWidgets('bugünkü bildirim saati geçmişse bugün planlanmaz', (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(),
          bildirim: await _ayar(s, acik: true),
          simdi: () => DateTime.utc(2026, 11, 2, 11, 0));
      expect(s.sonPlan.first.kimlik, 20261103);
    });

    testWidgets(
        'okul değişince yeniden planlanır: yeni okulun başlığı ve menüsü',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s, acik: true));
      await _okulDegistir(t, 'Ankara Üniversitesi', 'Gazi Üniversitesi');
      expect(s.cagrilar, [..._iptalPlan, ..._iptalPlan]);
      expect(s.sonPlan.map((b) => b.kimlik), [20261102, 20261103, 20261104]);
      expect(s.sonPlan.first.baslik, 'GÜ · bugün öğle');
      expect(s.sonPlan.first.metin, 'Gazi Kuru Fasulye');
    });

    testWidgets('Diğer > Yenile ve aşağı çekip yenileme planı yeniden kurar',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s, acik: true));
      await _digerdenSec(t, 'Yenile');
      expect(s.cagrilar, [..._iptalPlan, ..._iptalPlan]);
      await _asagiCek(t);
      expect(s.cagrilar, [..._iptalPlan, ..._iptalPlan, ..._iptalPlan]);
    });

    testWidgets('gün ya da öğün seçmek planı değiştirmez', (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s, acik: true));
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(s.cagrilar, _iptalPlan);
    });

    testWidgets(
        'menü yüklenemezse plan kurulmaz; sonra başarıyla yüklenince kurulur',
        (t) async {
      final s = SahteBildirimServisi();
      final depo = _depo(secili: 'ankara')..hataAt = true;
      await _ac(t, depo, bildirim: await _ayar(s, acik: true));
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(s.cagrilar, isEmpty);
      depo.hataAt = false;
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(s.cagrilar, _iptalPlan);
    });

    testWidgets(
        'ilk açılışta (okul seçilmemiş) plan kurulmaz; okul seçilince kurulur',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(secili: null), bildirim: await _ayar(s, acik: true));
      expect(find.text('Okulunu seç'), findsOneWidget);
      expect(s.cagrilar, isEmpty);
      await t.tap(find.text('Okulunu seç'));
      await t.pumpAndSettle();
      await t.tap(find.descendant(
          of: find.byType(UniversitePicker),
          matching: find.text('Gazi Üniversitesi')));
      await t.pumpAndSettle();
      expect(s.cagrilar, _iptalPlan);
      expect(s.sonPlan.first.baslik, 'GÜ · bugün öğle');
    });
  });

  group('favoriler', () {
    testWidgets('yemeği favoriye eklemek planı favori cümlesiyle günceller',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s, acik: true));
      expect(s.sonPlan.first.metin, 'Mercimek Çorbası, Pilav');
      s.cagrilar.clear();
      // bugünün menüsündeki ilk yemeğin kalbi (Mercimek Çorbası)
      await t.tap(find.byTooltip('Favorilere ekle').first);
      await t.pumpAndSettle();
      expect(s.cagrilar, _iptalPlan);
      expect(s.sonPlan.first.metin, 'Bugün favorin Mercimek Çorbası menüde');
      // 5 Kasım'ın metni Mantı yüzünden değil, favori Mercimek'i içermediği için eskisi gibi
      expect(s.sonPlan[3].metin, 'Mantı, Cacık');
    });

    testWidgets('favoriyi çıkarmak plan metnini eski haline döndürür',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s, acik: true));
      await t.tap(find.byTooltip('Favorilere ekle').first);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Favorilerden çıkar').first);
      await t.pumpAndSettle();
      expect(s.sonPlan.first.metin, 'Mercimek Çorbası, Pilav');
    });

    testWidgets('cihazda kayıtlı favoriler yüklenince son plan onları içerir',
        (t) async {
      SharedPreferences.setMockInitialValues(
          {'favori_yemekler': '{"manti":"Mantı"}'});
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s, acik: true));
      // 5 Kasım (4. bildirim) Mantı gününde favori cümlesi
      expect(s.sonPlan[3].metin, 'Bugün favorin Mantı menüde');
      expect(s.sonPlan[0].metin, 'Mercimek Çorbası, Pilav');
    });

    testWidgets('ayar kapalıyken favori değişimi servise dokunmaz', (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s));
      await t.tap(find.byTooltip('Favorilere ekle').first);
      await t.pumpAndSettle();
      expect(s.cagrilar, isEmpty);
    });

    testWidgets('sayfa kapandıktan sonra favori değişimi planlamayı tetiklemez',
        (t) async {
      final s = SahteBildirimServisi();
      final favoriler = FavoriDeposu();
      final ayar = await _ayar(s, acik: true);
      await _ac(t, _depo(), bildirim: ayar, favoriler: favoriler);
      s.cagrilar.clear();
      await t.pumpWidget(const SizedBox()); // ana sayfa kaldırıldı
      await favoriler.ekle('mercimek', 'Mercimek Çorbası');
      await t.pump();
      expect(s.cagrilar, isEmpty, reason: 'dinleyici dispose\'ta sökülür');
      expect(t.takeException(), isNull);
    });
  });

  group('Ayarlar üzerinden açma ve kapama', () {
    testWidgets(
        'anahtarı açınca plan ekrandaki okul ve menüyle kurulur; kapatınca iptal edilir',
        (t) async {
      final s = SahteBildirimServisi();
      final ayar = await _ayar(s);
      await _ac(t, _depo(), bildirim: ayar);
      expect(s.cagrilar, isEmpty);
      await _digerdenSec(t, 'Ayarlar');
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(s.cagrilar, ['izin', 'iptal', 'planla']);
      expect(s.sonPlan.map((b) => b.kimlik),
          [20261102, 20261103, 20261104, 20261105, 20261106]);
      expect(s.sonPlan.first.baslik, 'AÜ · bugün öğle');
      s.cagrilar.clear();
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(s.cagrilar, ['iptal']);
      expect(ayar.acik, isFalse);
    });

    testWidgets('izin verilmezse anahtar kapalı kalır ve hiçbir plan kurulmaz',
        (t) async {
      final s = SahteBildirimServisi(izin: false);
      await _ac(t, _depo(), bildirim: await _ayar(s));
      await _digerdenSec(t, 'Ayarlar');
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(s.cagrilar, ['izin']);
      expect(t.widget<SwitchListTile>(_anahtar).value, isFalse);
      expect(find.textContaining('Bildirim izni verilmedi'), findsOneWidget);
    });

    testWidgets(
        'Ayarlar\'da Önbelleği temizle menüyü yeniden yükler ve planı yeniler',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, _depo(), bildirim: await _ayar(s, acik: true));
      s.cagrilar.clear();
      await _digerdenSec(t, 'Ayarlar');
      await t.tap(find.text('Önbelleği temizle'));
      await t.pumpAndSettle();
      await t.tap(find.text('Temizle'));
      await t.pumpAndSettle();
      expect(s.cagrilar, _iptalPlan);
    });
  });
}
