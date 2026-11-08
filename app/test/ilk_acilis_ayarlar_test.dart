import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/config.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/ilk_acilis.dart';
import 'package:yemekhane/screens/university_picker.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

/// Ağa ve diske gitmeyen sahte veri deposu. [secili] boşsa kayıtlı okul yoktur (ilk açılış).
class SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  String? secili;
  bool listeHata = false;
  bool menuHata = false;
  int menuCagri = 0;
  int sec = 0; // universiteSec çağrı sayısı
  int temizleCagri = 0;
  final List<String> menuIstekleri = [];

  SahteDepo(this.liste, this.menuVeri, {this.secili});

  @override
  Future<List<Universite>> universiteler() async {
    if (listeHata) throw Exception('ağ yok');
    return liste;
  }

  @override
  Future<Menu> menu(String universiteId) async {
    menuCagri++;
    menuIstekleri.add(universiteId);
    if (menuHata) throw Exception('ağ yok');
    return menuVeri[universiteId]!;
  }

  @override
  Future<String?> seciliUniversite() async => secili;

  @override
  Future<void> universiteSec(String id) async {
    sec++;
    secili = id;
  }

  @override
  Future<List<String>> sonSecilenler() async => const [];

  @override
  Future<int> onbellekTemizle() async {
    temizleCagri++;
    return 0;
  }

  @override
  String? fotoUrl(String universiteId, String? foto) => null;

  @override
  String? yemekFotoUrl(String? img) => null;
}

Universite _uni(String id, String ad, {String kaynak = ''}) => Universite(
    id: id,
    ad: ad,
    kisa: id,
    sehir: 'Ankara',
    kaynak: kaynak,
    ogunler: const ['lunch'],
    fiyatlar: const []);

Menu _menu(String uniId, String yemek) => Menu(uniId, null, {
      '2026-11-02': {
        'lunch': Ogun([YemekOgesi(yemek, 350)], 350)
      }
    });

const _ankaraKaynak = 'https://sks.ankara.edu.tr/yemek-hizmetleri-2/';

SahteDepo _depo({String? secili}) => SahteDepo([
      _uni('ankara', 'Ankara Üniversitesi', kaynak: _ankaraKaynak),
      _uni('gazi', 'Gazi Üniversitesi', kaynak: 'https://gazi.example/menu'),
    ], {
      'ankara': _menu('ankara', 'Mercimek Çorbası'),
      'gazi': _menu('gazi', 'Gazi Kuru Fasulye'),
    }, secili: secili);

DateTime _simdi() => DateTime.utc(2026, 11, 2, 10, 0);

Future<void> _ac(WidgetTester t, SahteDepo depo,
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
        temaAyari: ayar, depo: depo, geriBildirim: YerelDepo(), simdi: _simdi),
  ));
  await t.pumpAndSettle();
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

Future<void> _ayarlaraGit(WidgetTester t) async {
  // Ayarlar artık "Diğer" taşma menüsünde (üst çubukta yemek arama simgesine yer açmak için)
  await t.tap(find.byTooltip('Diğer'));
  await t.pumpAndSettle();
  await t.tap(find.text('Ayarlar'));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ilk açılış', () {
    testWidgets(
        'kayıtlı okul yokken menü yerine karşılama çıkar, okul seçilmez',
        (t) async {
      final depo = _depo(); // secili == null
      await _ac(t, depo);
      expect(find.byType(IlkAcilis), findsOneWidget);
      expect(find.text('Üni Yemek'), findsOneWidget);
      expect(find.text('Okulunun günlük yemek menüsü'), findsOneWidget);
      expect(
          find.text('Kalori, servis saati ve fiyat bilgisi'), findsOneWidget);
      expect(find.text('Yemeklere puan ver, yorum yaz'), findsOneWidget);
      expect(find.text('Okulunu seç'), findsOneWidget);
      expect(find.byType(OgunKarti), findsNothing);
      expect(find.byType(IskeletGovde), findsNothing);
      expect(find.textContaining('Menü yüklenemedi'), findsNothing);
      // Ankara'ya düşme yok: ne menü istendi ne de okul kaydedildi
      expect(depo.menuCagri, 0);
      expect(depo.sec, 0);
      expect(depo.secili, isNull);
    });

    testWidgets('"Okulunu seç" seçiciyi açar, seçilen okulun menüsü yüklenir',
        (t) async {
      final depo = _depo();
      await _ac(t, depo);
      await t.tap(find.text('Okulunu seç'));
      await t.pumpAndSettle();
      expect(find.byType(UniversitePicker), findsOneWidget);

      await t.tap(find.text('Gazi Üniversitesi'));
      await t.pumpAndSettle();
      expect(find.byType(IlkAcilis), findsNothing);
      expect(find.text('Gazi Üniversitesi'), findsOneWidget); // AppBar başlığı
      expect(find.text('Gazi Kuru Fasulye'), findsOneWidget);
      expect(depo.secili, 'gazi'); // universiteSec ile kaydedilir
      expect(depo.menuIstekleri, ['gazi']);
    });

    testWidgets('seçmeden geri dönülürse karşılama kalır', (t) async {
      final depo = _depo();
      await _ac(t, depo);
      await t.tap(find.text('Okulunu seç'));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(UniversitePicker), findsNothing);
      expect(find.byType(IlkAcilis), findsOneWidget);
      expect(find.byType(OgunKarti), findsNothing);
      expect(depo.menuCagri, 0);
      expect(depo.secili, isNull);
    });

    testWidgets('kayıtlı okulu olan kullanıcıda karşılama görünmez', (t) async {
      final depo = _depo(secili: 'gazi');
      await _ac(t, depo);
      expect(find.byType(IlkAcilis), findsNothing);
      expect(find.text('Okulunu seç'), findsNothing);
      expect(find.text('Gazi Kuru Fasulye'), findsOneWidget);
      expect(depo.menuIstekleri, ['gazi']);
    });

    testWidgets('okul listesi yüklenemezse eski hata ekranı çıkar', (t) async {
      final depo = _depo()..listeHata = true;
      await _ac(t, depo);
      expect(find.byType(IlkAcilis), findsNothing);
      expect(find.textContaining('Menü yüklenemedi'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);

      depo.listeHata = false;
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(find.byType(IlkAcilis), findsOneWidget); // liste geldi, okul yok
    });

    testWidgets(
        'seçilen okulun menüsü yüklenemezse "Tekrar dene" seçilen okulu dener',
        (t) async {
      final depo = _depo()..menuHata = true;
      await _ac(t, depo);
      await t.tap(find.text('Okulunu seç'));
      await t.pumpAndSettle();
      await t.tap(find.text('Gazi Üniversitesi'));
      await t.pumpAndSettle();
      expect(find.textContaining('Menü yüklenemedi'), findsOneWidget);
      expect(depo.secili, isNull); // menü gelmedi: okul kaydedilmedi

      depo.menuHata = false;
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(find.byType(IlkAcilis), findsNothing); // karşılamaya dönülmez
      expect(find.text('Gazi Kuru Fasulye'), findsOneWidget);
      expect(depo.secili, 'gazi');
    });

    testWidgets('320x640, yazı 1.5x: karşılama taşmaz', (t) async {
      await _ac(t, _depo(), boyut: const Size(320, 640), yaziOlcegi: 1.5);
      expect(t.takeException(), isNull);
      expect(find.text('Okulunu seç'), findsOneWidget);
      final dugme = t.getSize(find.byType(FilledButton));
      expect(dugme.height, greaterThanOrEqualTo(48));
    });
  });

  group('ayarlar', () {
    testWidgets('Diğer > Ayarlar sayfasını açar; satırlar ve Hakkında görünür',
        (t) async {
      await _ac(t, _depo(secili: 'ankara'));
      // Tema eylemi artık "Diğer" taşma menüsünde
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      expect(find.text('Tema'), findsOneWidget);
      await t.tapAt(const Offset(5, 5)); // menüyü kapat
      await t.pumpAndSettle();
      await _ayarlaraGit(t);

      expect(find.byType(AyarlarSayfasi), findsOneWidget);
      expect(find.text('Ayarlar'), findsOneWidget); // sayfa başlığı
      expect(find.text('Okul'), findsOneWidget);
      expect(find.text('Ankara Üniversitesi'), findsOneWidget);
      expect(find.text('Tema'), findsOneWidget);
      expect(find.text('Önbelleği temizle'), findsOneWidget);
      expect(find.text('Sürüm'), findsOneWidget);
      expect(find.text(uygulamaSurumu), findsOneWidget);
      expect(find.text('Veri kaynağı'), findsOneWidget);
      expect(find.text(_ankaraKaynak), findsOneWidget);
      expect(find.textContaining('okul sitelerinden otomatik derlenir'),
          findsOneWidget);
      expect(
          find.textContaining('hatalı ya da eksik olabilir'), findsOneWidget);
      // Kalori hedefi ve günlük menü bildirimi satırları eklenince son satırlar 900 px'lik test penceresinin
      // altına kaydı: aşağı kaydır
      await t.scrollUntilVisible(find.text('Açık kaynak lisansları'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Wikimedia Commons, CC'), findsOneWidget);
      expect(find.text('Puan ve yorumlar anonimdir.'), findsOneWidget);
      expect(find.text('Açık kaynak lisansları'), findsOneWidget);
    });

    testWidgets('Okul satırı seçiciyi açar, seçilen okul ana sayfada yüklenir',
        (t) async {
      final depo = _depo(secili: 'ankara');
      await _ac(t, depo);
      await _ayarlaraGit(t);
      await t.tap(find.text('Okul'));
      await t.pumpAndSettle();
      expect(find.byType(UniversitePicker), findsOneWidget);

      await t.tap(find.text('Gazi Üniversitesi'));
      await t.pumpAndSettle();
      expect(find.byType(AyarlarSayfasi), findsNothing); // ana sayfaya dönüldü
      expect(find.text('Gazi Kuru Fasulye'), findsOneWidget);
      expect(depo.secili, 'gazi');
    });

    testWidgets('Okul satırında aynı okul seçilirse Ayarlar açık kalır',
        (t) async {
      final depo = _depo(secili: 'ankara');
      await _ac(t, depo);
      await _ayarlaraGit(t);
      await t.tap(find.text('Okul'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ankara Üniversitesi').last);
      await t.pumpAndSettle();
      expect(find.byType(AyarlarSayfasi), findsOneWidget);
      expect(depo.menuCagri, 1);
    });

    testWidgets('Tema satırı tema seçiciyi açar', (t) async {
      await _ac(t, _depo(secili: 'ankara'));
      await _ayarlaraGit(t);
      await t.tap(find.text('Tema'));
      await t.pumpAndSettle();
      expect(find.text('Görünüm'), findsOneWidget);
      expect(find.text('Siyah'), findsOneWidget);
    });

    testWidgets('önbellek temizleme: vazgeçilirse bir şey olmaz', (t) async {
      final depo = _depo(secili: 'ankara');
      await _ac(t, depo);
      await _ayarlaraGit(t);
      await t.tap(find.text('Önbelleği temizle'));
      await t.pumpAndSettle();
      expect(find.text('Önbellek temizlensin mi?'), findsOneWidget);
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(find.text('Önbellek temizlensin mi?'), findsNothing);
      expect(depo.temizleCagri, 0);
      expect(depo.menuCagri, 1);
    });

    testWidgets(
        'önbellek temizleme: onaylanırsa silinir ve menü yeniden yüklenir',
        (t) async {
      final depo = _depo(secili: 'ankara');
      await _ac(t, depo);
      expect(depo.menuCagri, 1);
      await _ayarlaraGit(t);
      await t.tap(find.text('Önbelleği temizle'));
      await t.pumpAndSettle();
      await t.tap(find.text('Temizle'));
      await t.pumpAndSettle();
      expect(depo.temizleCagri, 1);
      expect(depo.menuCagri, 2); // menü yeniden istendi
      expect(find.text('Önbellek temizlendi'), findsOneWidget);
      expect(find.byType(AyarlarSayfasi), findsOneWidget); // sayfada kalınır

      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(find.byType(IskeletGovde), findsNothing);
    });

    testWidgets('veri kaynağına dokununca adres panoya kopyalanır', (t) async {
      final pano = _panoyuDinle(t);
      await _ac(t, _depo(secili: 'ankara'));
      await _ayarlaraGit(t);
      await t.tap(find.text('Veri kaynağı'));
      await t.pumpAndSettle();
      expect(pano, [_ankaraKaynak]);
      expect(find.text('Bağlantı panoya kopyalandı'), findsOneWidget);
    });

    testWidgets('açık kaynak lisansları sayfası açılır', (t) async {
      await _ac(t, _depo(secili: 'ankara'));
      await _ayarlaraGit(t);
      await t.scrollUntilVisible(find.text('Açık kaynak lisansları'), 100,
          scrollable: find.byType(Scrollable).first);
      // satır oluşmuş ama ekran dışındaysa kaydırma bitsin
      await t.pumpAndSettle();
      await t.tap(find.text('Açık kaynak lisansları'));
      await t.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('okul seçilmemişken Okul "Seçilmedi", veri kaynağı pasif',
        (t) async {
      final pano = _panoyuDinle(t);
      await _ac(t, _depo()); // ilk açılış karşılaması
      await _ayarlaraGit(t);
      expect(find.text('Seçilmedi'), findsOneWidget);
      expect(find.text('Okul seçilmedi'), findsOneWidget);
      await t.tap(find.text('Veri kaynağı'));
      await t.pumpAndSettle();
      expect(pano, isEmpty);
      expect(find.text('Bağlantı panoya kopyalandı'), findsNothing);

      // karşılamadayken Ayarlar'dan okul seçmek de menüyü yükler
      await t.tap(find.text('Okul'));
      await t.pumpAndSettle();
      await t.tap(find.text('Gazi Üniversitesi'));
      await t.pumpAndSettle();
      expect(find.byType(IlkAcilis), findsNothing);
      expect(find.text('Gazi Kuru Fasulye'), findsOneWidget);
    });

    testWidgets(
        '320x640, yazı 1.5x: Ayarlar taşmaz ve dokunma hedefleri >= 48dp',
        (t) async {
      await _ac(t, _depo(secili: 'ankara'),
          boyut: const Size(320, 640), yaziOlcegi: 1.5);
      expect(t.takeException(), isNull);
      await _ayarlaraGit(t);
      expect(t.takeException(), isNull);
      for (final satir in find.byType(ListTile).evaluate()) {
        expect(t.getSize(find.byWidget(satir.widget)).height,
            greaterThanOrEqualTo(48));
      }
      await t.scrollUntilVisible(find.text('Açık kaynak lisansları'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(t.takeException(), isNull);
    });
  });

  group('Depo.onbellekTemizle', () {
    test('yalnızca onbellek/ anahtarlarını siler', () async {
      SharedPreferences.setMockInitialValues({
        'onbellek/index.json': '{}',
        'onbellek/ankara/menu.json': '{}',
        'universite': 'ankara',
        'son_secilenler': ['ankara'],
        'yp/ankara_x': 4,
        'tema_mod': 'dark',
      });
      final n = await Depo().onbellekTemizle();
      expect(n, 2);
      final p = await SharedPreferences.getInstance();
      expect(p.getKeys(),
          {'universite', 'son_secilenler', 'yp/ankara_x', 'tema_mod'});
    });

    test('hiç önbellek yoksa 0 döner', () async {
      expect(await Depo().onbellekTemizle(), 0);
    });
  });

  test('uygulamaSurumu pubspec.yaml sürümünün (+ öncesi) aynısı', () {
    final satir = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final surum = satir.substring('version:'.length).trim().split('+').first;
    expect(uygulamaSurumu, surum);
  });
}
