import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/yemek_detay.dart';
import 'package:yemekhane/tema.dart';

const _uzunAd =
    'Çok Uzun Adlı Kremalı Mantarlı Közlenmiş Patlıcanlı Tavuk Sote Spesiyal Yemeği';
const _notMetni = 'Örnek fotoğraf, okuldaki yemek birebir aynı görünmeyebilir.';

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

/// Bugün Pazartesi 2 Kasım 2026. Mantı: Salı 27 Ekim öğle, Cuma 30 Ekim akşam (geçmiş); bugün öğle,
/// Perşembe 5 Kasım öğle ve akşam (yaklaşan). Ayran'ın anahtarı yok.
Menu _menu() => Menu('ankara', null, {
      '2026-10-27': {
        'lunch': Ogun([_y('Mantı', 'manti', 450)], 450),
      },
      '2026-10-30': {
        'lunch': Ogun([_y('Pirinç Pilavı', 'pilav', 300)], 300),
        'dinner': Ogun([_y('Mantı', 'manti', 450)], 450),
      },
      '2026-11-02': {
        'lunch': Ogun([
          _y('Mantı', 'manti', 450),
          _y('Mantı', 'manti', 450), // aynı öğünde tekrar: tek satır
          _y('Ayran', null, 60),
        ], 510),
        'dinner': Ogun([_y('Fırın Makarna', 'makarna', 500)], 500),
      },
      '2026-11-03': {
        'lunch': Ogun([_y('Ezogelin Çorbası', 'ezogelin', 110)], 110),
      },
      '2026-11-05': {
        'lunch': Ogun([_y('Mantı', 'manti', 450)], 450),
        'dinner': Ogun([_y('Mantı', 'manti', 450)], 450),
      },
    });

/// Ağa ve diske gitmeyen sahte veri deposu (ana sayfa entegrasyonu için).
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

class _PuanVerHatali extends YerelDepo {
  @override
  Future<void> puanVer(String slot, int yildiz) async =>
      throw Exception('ağ yok');
}

class _PuanOkumaHatali extends YerelDepo {
  bool hata = true;
  @override
  Future<YemekPuanlari> puanlar(List<String> slotlar) async {
    if (hata) throw Exception('ağ yok');
    return super.puanlar(slotlar);
  }
}

/// Hazır bir [ui.Image]'i eşzamanlı veren sahte fotoğraf (ağsız).
class _HazirResim extends ImageProvider<_HazirResim> {
  final ui.Image resim;
  _HazirResim(this.resim);
  @override
  Future<_HazirResim> obtainKey(ImageConfiguration c) =>
      SynchronousFuture<_HazirResim>(this);
  @override
  ImageStreamCompleter loadImage(_HazirResim key, ImageDecoderCallback d) =>
      OneFrameImageStreamCompleter(
          SynchronousFuture<ImageInfo>(ImageInfo(image: resim.clone())));
}

/// Yüklenemeyen fotoğraf.
class _BozukResim extends ImageProvider<_BozukResim> {
  @override
  Future<_BozukResim> obtainKey(ImageConfiguration c) =>
      SynchronousFuture<_BozukResim>(this);
  @override
  ImageStreamCompleter loadImage(_BozukResim key, ImageDecoderCallback d) =>
      OneFrameImageStreamCompleter(
          Future<ImageInfo>.error(StateError('fotoğraf yüklenemedi')));
}

String _slot(String anahtar) => yemekSlotKimligi('ankara', anahtar);

Widget _uygulama(Widget home,
        {double olcek = 1.0, Brightness parlaklik = Brightness.light}) =>
    MaterialApp(
      theme: TemaAyari().tema(parlaklik),
      builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(olcek)),
          child: w!),
      home: home,
    );

YemekDetaySayfasi _sayfa(
        {YemekOgesi? yemek,
        Menu? menu,
        String bugun = '2026-11-02',
        ImageProvider? foto,
        GeriBildirimDeposu? gb,
        FavoriDeposu? favoriler}) =>
    YemekDetaySayfasi(
        yemek: yemek ?? _y('Mantı', 'manti', 450),
        uni: _uni(),
        menu: menu ?? _menu(),
        bugun: bugun,
        foto: foto,
        geriBildirim: gb ?? YerelDepo(),
        favoriler: favoriler);

Future<void> _ac(WidgetTester t, YemekDetaySayfasi sayfa,
    {Size boyut = const Size(400, 2400),
    double olcek = 1.0,
    Brightness parlaklik = Brightness.light}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_uygulama(sayfa, olcek: olcek, parlaklik: parlaklik));
  await t.pumpAndSettle();
}

/// [f] ekranda ve dokunulabilir olana kadar kaydırır (henüz oluşmamış olabilir); yerleşimin oturması için pompalar.
Future<void> _gor(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

// --- ana sayfa entegrasyonu ---------------------------------------------------------------------------------------

Menu _anaMenu() => Menu('ankara', null, {
      '2026-10-30': {
        'lunch': Ogun([
          _y('Geçen Cuma Mantısı', 'gmanti', 400),
          _y('Pirinç Pilavı', 'pilav', 300),
        ], 700),
      },
      '2026-11-02': {
        'lunch': Ogun([
          _y('Mercimek Çorbası', 'mercimek', 120),
          _y('Pirinç Pilavı', 'pilav', 300),
          _y('Ayran', null, 60),
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
        'lunch': Ogun([_y('Kuru Fasulye', 'fasulye', 350)], 350),
        'dinner': Ogun([_y('Fırın Makarna', 'makarna', 500)], 500),
      },
    });

DateTime _simdi() => DateTime.utc(2026, 11, 2, 10, 0);

Future<FavoriDeposu> _anaSayfa(WidgetTester t,
    {Size boyut = const Size(400, 900), double olcek = 1.0}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari();
  final favoriler = FavoriDeposu();
  await t.pumpWidget(MaterialApp(
    theme: ayar.tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(olcek)),
        child: w!),
    home: AnaSayfa(
        temaAyari: ayar,
        depo: _SahteDepo([_uni()], {'ankara': _anaMenu()}),
        geriBildirim: YerelDepo(),
        favoriler: favoriler,
        simdi: _simdi),
  ));
  await t.pumpAndSettle();
  return favoriler;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('yemekTarihleri', () {
    test(
        'tarih sırasında, geçmiş ve gelecek dahil; aynı öğünde tekrar tek sayılır',
        () {
      final g = yemekTarihleri(_menu(), 'manti');
      expect(g.map((x) => '${x.tarih} ${x.ogun}'), [
        '2026-10-27 lunch',
        '2026-10-30 dinner',
        '2026-11-02 lunch',
        '2026-11-05 lunch',
        '2026-11-05 dinner',
      ]);
    });

    test('aynı günde öğün sırası kahvaltı, öğle, akşam, vejetaryen', () {
      Ogun ogun() => Ogun([_y('Mantı', 'manti')], null);
      final menu = Menu('x', null, {
        '2026-11-03': {
          'vegetarian': ogun(),
          'dinner': ogun(),
          'lunch': ogun(),
          'breakfast': ogun(),
        },
        '2026-11-02': {'dinner': ogun(), 'lunch': ogun()},
      });
      expect(yemekTarihleri(menu, 'manti').map((x) => '${x.tarih} ${x.ogun}'), [
        '2026-11-02 lunch',
        '2026-11-02 dinner',
        '2026-11-03 breakfast',
        '2026-11-03 lunch',
        '2026-11-03 dinner',
        '2026-11-03 vegetarian',
      ]);
    });

    test('ay sonu ve yıl sonu kronolojik sıralanır', () {
      Ogun ogun() => Ogun([_y('Mantı', 'manti')], null);
      final menu = Menu('x', null, {
        '2027-01-01': {'lunch': ogun()},
        '2026-12-31': {'lunch': ogun()},
        '2026-11-01': {'lunch': ogun()},
        '2026-10-31': {'lunch': ogun()},
      });
      expect(yemekTarihleri(menu, 'manti').map((x) => x.tarih),
          ['2026-10-31', '2026-11-01', '2026-12-31', '2027-01-01']);
    });

    test('olmayan yemek, boş anahtar, boş menü ve tatil günü boş liste verir',
        () {
      expect(yemekTarihleri(_menu(), 'yok'), isEmpty);
      expect(yemekTarihleri(_menu(), ''), isEmpty);
      expect(yemekTarihleri(Menu('x', null, {}), 'manti'), isEmpty);
      final tatil = Menu('x', null, {
        '2026-11-02': {'lunch': Ogun([], null, null, false, 'Tatil')},
        '2026-11-03': <String, Ogun>{},
      });
      expect(yemekTarihleri(tatil, 'manti'), isEmpty);
    });

    test('anahtarsız öğeler eşleşmez', () {
      final menu = Menu('x', null, {
        '2026-11-02': {
          'lunch': Ogun([_y('Ayran', null), _y('Mantı', 'manti')], null)
        },
      });
      expect(yemekTarihleri(menu, 'manti').length, 1);
      expect(yemekTarihleri(menu, 'null'), isEmpty);
    });
  });

  group('kapak ve fotoğraf', () {
    testWidgets(
        'fotoğraf yokken degrade zemin + yemek simgesi, not gösterilmez',
        (t) async {
      await _ac(t, _sayfa());
      expect(t.takeException(), isNull);
      expect(find.byIcon(Icons.restaurant), findsOneWidget); // Mantı simgesi
      expect(find.text(_notMetni), findsNothing);
      expect(find.byType(Image), findsNothing);
      // ad (başlık), kalori ve okul etiketi
      expect(find.text('Mantı'), findsOneWidget);
      expect(find.text('450 kkal'), findsOneWidget);
      expect(find.text('AÜ'), findsOneWidget);
    });

    testWidgets('simge yemek adına göre seçilir (çorba)', (t) async {
      await _ac(t, _sayfa(yemek: _y('Mercimek Çorbası', 'mercimek', 120)));
      expect(find.byIcon(Icons.soup_kitchen), findsOneWidget);
    });

    testWidgets('fotoğraf yüklenince görünür ve örnek fotoğraf notu çıkar',
        (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      await _ac(t, _sayfa(foto: _HazirResim(resim)));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text(_notMetni), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsNothing); // yer tutucu yok
      expect(t.takeException(), isNull);
    });

    testWidgets('fotoğraf yüklenemezse yer tutucu kalır, not çıkmaz',
        (t) async {
      await _ac(t, _sayfa(foto: _BozukResim()));
      expect(t.takeException(), isNull);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.text(_notMetni), findsNothing);
    });

    testWidgets('kalorisiz yemekte kalori etiketi yok', (t) async {
      await _ac(t, _sayfa(yemek: _y('Mantı', 'manti')));
      expect(find.textContaining('kkal'), findsNothing);
    });

    testWidgets('kaydırınca yemek adı üst çubukta da görünür', (t) async {
      await _ac(t, _sayfa(), boyut: const Size(400, 500));
      const anahtar = ValueKey('daralmis-baslik');
      expect(find.byKey(anahtar), findsNothing);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await t.pumpAndSettle();
      expect(find.byKey(anahtar), findsOneWidget);
      await t.drag(find.byType(CustomScrollView), const Offset(0, 800));
      await t.pumpAndSettle();
      expect(find.byKey(anahtar), findsNothing);
    });
  });

  group('puan', () {
    testWidgets(
        'oy yokken ilk puan çağrısı; yıldıza dokununca YerelDepo\'ya yazılır',
        (t) async {
      final gb = YerelDepo();
      await _ac(t, _sayfa(gb: gb));
      expect(find.text('Henüz oy yok. İlk puanı sen ver.'), findsOneWidget);
      expect(find.text('Bu yemeği nasıl buldun?'), findsOneWidget);
      expect(find.byTooltip('1 yıldız'), findsOneWidget);
      expect(find.byTooltip('5 yıldız'), findsOneWidget);

      await t.tap(find.byTooltip('4 yıldız'));
      await t.pumpAndSettle();
      expect(await gb.benimPuanim(_slot('manti')), 4);
      expect((await gb.puanlar([_slot('manti')])).benim, {_slot('manti'): 4});
      expect(find.text('Senin puanın: 4 / 5 (değiştirmek için dokun)'),
          findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('Ortalama · 1 oy'), findsOneWidget);
      expect(find.text('Henüz oy yok. İlk puanı sen ver.'), findsNothing);

      // puan değiştirilebilir
      await t.tap(find.byTooltip('2 yıldız'));
      await t.pumpAndSettle();
      expect(await gb.benimPuanim(_slot('manti')), 2);
      expect(find.text('2.0'), findsOneWidget);
    });

    testWidgets('puan yemek bazlı slota yazılır (y_<okul>_<anahtar>)',
        (t) async {
      await _ac(t, _sayfa());
      await t.tap(find.byTooltip('5 yıldız'));
      await t.pumpAndSettle();
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('yp/y_ankara_manti'), 5);
    });

    testWidgets('kayıtlı puan açılışta okunur; dolu yıldız sayısı puana eşit',
        (t) async {
      await YerelDepo().puanVer(_slot('manti'), 3);
      await _ac(t, _sayfa());
      expect(find.text('Senin puanın: 3 / 5 (değiştirmek için dokun)'),
          findsOneWidget);
      expect(find.byIcon(Icons.star_rounded),
          findsNWidgets(3 + 1)); // 3 yıldız + ortalama simgesi
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    });

    testWidgets('deneme modunda (YerelDepo) not görünür', (t) async {
      await _ac(t, _sayfa());
      expect(find.text('Deneme modu: puanlar yalnızca bu cihazda saklanır.'),
          findsWidgets); // puan kartı (+ yorumlar kartı kendi notunu göstermez)
    });

    testWidgets('kayıt başarısızsa puan eski haline döner ve bildirim çıkar',
        (t) async {
      await _ac(t, _sayfa(gb: _PuanVerHatali()));
      await t.tap(find.byTooltip('4 yıldız'));
      await t.pumpAndSettle();
      expect(find.text('Puan kaydedilemedi. İnternet bağlantını kontrol et.'),
          findsOneWidget);
      expect(find.text('Bu yemeği nasıl buldun?'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('puanlar okunamazsa hata ve Tekrar dene; sonra yüklenir',
        (t) async {
      final gb = _PuanOkumaHatali();
      await _ac(t, _sayfa(gb: gb));
      expect(find.text('Puanlar yüklenemedi.'), findsOneWidget);
      gb.hata = false;
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(find.text('Puanlar yüklenemedi.'), findsNothing);
      expect(find.text('Henüz oy yok. İlk puanı sen ver.'), findsOneWidget);
    });

    testWidgets('yıldız düğmeleri en az 48 dp (320 dp genişlikte de)',
        (t) async {
      await _ac(t, _sayfa(), boyut: const Size(320, 640), olcek: 1.5);
      for (var i = 1; i <= 5; i++) {
        final f = find
            .widgetWithIcon(IconButton, Icons.star_outline_rounded)
            .at(i - 1);
        await _gor(t, f);
        final b = t.getSize(f);
        expect(b.width, greaterThanOrEqualTo(48), reason: '$i');
        expect(b.height, greaterThanOrEqualTo(48), reason: '$i');
      }
    });
  });

  group('favori kalbi', () {
    testWidgets('dokununca favoriye eklenir / çıkar, kayıt yazılır', (t) async {
      final f = FavoriDeposu();
      await _ac(t, _sayfa(favoriler: f));
      expect(find.byTooltip('Favorilerden çıkar'), findsNothing);
      await t.tap(find.byTooltip('Favorilere ekle'));
      await t.pumpAndSettle();
      expect(f.varMi('manti'), isTrue);
      expect(f.liste.single.ad, 'Mantı');
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getString(FavoriDeposu.prefsAnahtari), contains('manti'));

      await t.tap(find.byTooltip('Favorilerden çıkar'));
      await t.pumpAndSettle();
      expect(f.varMi('manti'), isFalse);
      expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
    });

    testWidgets('kayıtlı favori dolu kalple açılır', (t) async {
      SharedPreferences.setMockInitialValues(
          {FavoriDeposu.prefsAnahtari: '{"manti":"Mantı"}'});
      await _ac(t, _sayfa(favoriler: FavoriDeposu()));
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
    });

    testWidgets('favori deposu verilmezse kalp yok', (t) async {
      await _ac(t, _sayfa());
      expect(find.byTooltip('Favorilere ekle'), findsNothing);
      expect(find.byTooltip('Favorilerden çıkar'), findsNothing);
    });

    testWidgets('limit dolunca eklenmez, bildirim çıkar', (t) async {
      SharedPreferences.setMockInitialValues({
        FavoriDeposu.prefsAnahtari:
            '{${[for (var i = 0; i < 200; i++) '"k$i":"Yemek $i"'].join(',')}}'
      });
      final f = FavoriDeposu();
      await _ac(t, _sayfa(favoriler: f));
      await t.pump(); // kayıtlı favoriler yüklensin
      await t.tap(find.byTooltip('Favorilere ekle'));
      await t.pumpAndSettle();
      expect(f.varMi('manti'), isFalse);
      expect(
          find.text('En fazla 200 favori ekleyebilirsin. Önce birini çıkar.'),
          findsOneWidget);
    });

    testWidgets('kalp üst çubukta, 48 dp ve geri düğmesiyle çakışmaz',
        (t) async {
      await _ac(t, _sayfa(favoriler: FavoriDeposu()),
          boyut: const Size(320, 640), olcek: 1.5);
      final kalp =
          t.getRect(find.widgetWithIcon(IconButton, Icons.favorite_border));
      expect(kalp.width, greaterThanOrEqualTo(48));
      expect(kalp.height, greaterThanOrEqualTo(48));
      final geri = t.getRect(find.byType(BackButton));
      expect(geri.right, lessThanOrEqualTo(kalp.left));
    });
  });

  group('anahtarsız yemek', () {
    testWidgets(
        'yalnızca fotoğraf / ad / kalori; puan, kalp, gün listesi, yorum yok',
        (t) async {
      await _ac(
          t, _sayfa(yemek: _y('Ayran', null, 60), favoriler: FavoriDeposu()));
      expect(t.takeException(), isNull);
      expect(find.text('Ayran'), findsOneWidget);
      expect(find.text('60 kkal'), findsOneWidget);
      expect(find.text('Bu yemek için puan, yorum ve favori henüz yok.'),
          findsOneWidget);
      expect(find.byTooltip('1 yıldız'), findsNothing);
      expect(find.byTooltip('Favorilere ekle'), findsNothing);
      expect(find.text('Bu yemek ne zaman var'), findsNothing);
      expect(find.textContaining('Yorum'), findsNothing);
    });

    testWidgets('boş anahtar da anahtarsız sayılır', (t) async {
      await _ac(t, _sayfa(yemek: _y('Ayran', '')));
      expect(find.text('Bu yemek için puan, yorum ve favori henüz yok.'),
          findsOneWidget);
    });
  });

  group('Bu yemek ne zaman var', () {
    testWidgets('yaklaşanlar ve geçmişler ayrı gruplarda, doğru sırayla',
        (t) async {
      await _ac(t, _sayfa());
      expect(find.text('Bu yemek ne zaman var'), findsOneWidget);
      expect(find.text('Yaklaşan günler'), findsOneWidget);
      expect(find.text('Geçmişte'), findsOneWidget);
      // yaklaşanlar: bugün (tekrar eden Mantı tek), Perşembe öğle ve akşam
      expect(find.text('Bugün · 2 Kasım'), findsOneWidget);
      expect(find.text('Perşembe 5 Kasım'), findsNWidgets(2));
      // geçmiş: en yeni başta
      final cuma = t.getTopLeft(find.text('Cuma 30 Ekim')).dy;
      final sali = t.getTopLeft(find.text('Salı 27 Ekim')).dy;
      expect(cuma, lessThan(sali));
      final bugun = t.getTopLeft(find.text('Bugün · 2 Kasım')).dy;
      expect(bugun, lessThan(cuma)); // yaklaşanlar geçmişlerin üstünde
      expect(find.text('Akşam'), findsNWidgets(2)); // Perşembe + Cuma 30 Ekim
      expect(find.text('Tümünü göster (5)'), findsNothing); // 5 satır sığar
    });

    testWidgets('yarın etiketi tarihle birlikte', (t) async {
      await _ac(t, _sayfa(yemek: _y('Ezogelin Çorbası', 'ezogelin', 110)));
      expect(find.text('Yarın · 3 Kasım'), findsOneWidget);
      expect(find.text('Geçmişte'), findsNothing);
    });

    testWidgets('yalnızca geçmiş günler varsa "yaklaşan gün yok" yazar',
        (t) async {
      await _ac(t, _sayfa(bugun: '2026-11-10'));
      expect(find.text('Yayınlanan menüde yaklaşan gün yok.'), findsOneWidget);
      expect(find.text('Geçmişte'), findsOneWidget);
    });

    testWidgets('menüde görünmeyen yemek için bilgi satırı', (t) async {
      await _ac(t, _sayfa(yemek: _y('Hayalet Yemek', 'hayalet')));
      expect(
          find.text('Bu yemek yayınlanan menüde görünmüyor.'), findsOneWidget);
    });

    testWidgets('6+ satırda "Tümünü göster" listeyi açar / kapatır', (t) async {
      Ogun ogun() => Ogun([_y('Pilav', 'pilav')], null);
      final menu = Menu('ankara', null, {
        for (var g = 2; g <= 9; g++)
          '2026-11-${g.toString().padLeft(2, '0')}': {'lunch': ogun()},
      });
      await _ac(t, _sayfa(yemek: _y('Pilav', 'pilav'), menu: menu));
      expect(find.text('Tümünü göster (8)'), findsOneWidget);
      expect(find.text('Bugün · 2 Kasım'), findsOneWidget);
      expect(find.text('Pazartesi 9 Kasım'), findsNothing); // 6. satır gizli
      await _gor(t, find.text('Tümünü göster (8)'));
      await t.tap(find.text('Tümünü göster (8)'));
      await t.pumpAndSettle();
      expect(find.text('Pazartesi 9 Kasım'), findsOneWidget);
      expect(find.text('Daha az göster'), findsOneWidget);
      await t.tap(find.text('Daha az göster'));
      await t.pumpAndSettle();
      expect(find.text('Pazartesi 9 Kasım'), findsNothing);
    });

    testWidgets('satıra dokununca sayfa o gün ve öğünle kapanır', (t) async {
      t.view.physicalSize = const Size(400, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      YemekGorunumu? sonuc;
      var kapandi = false;
      await t.pumpWidget(_uygulama(Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                sonuc = await Navigator.of(c).push<YemekGorunumu>(
                    MaterialPageRoute(builder: (_) => _sayfa()));
                kapandi = true;
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      )));
      await t.tap(find.text('Aç'));
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsOneWidget);
      expect(kapandi, isFalse);

      // Perşembe 5 Kasım akşam: iki "Perşembe 5 Kasım" satırından ikincisi
      await t.tap(find.text('Perşembe 5 Kasım').last);
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsNothing);
      expect(kapandi, isTrue);
      expect(sonuc!.tarih, '2026-11-05');
      expect(sonuc!.ogun, 'dinner');
    });

    testWidgets('geri düğmesi sonuçsuz kapatır', (t) async {
      YemekGorunumu? sonuc = const YemekGorunumu(tarih: 'x', ogun: 'y');
      var kapandi = false;
      await t.pumpWidget(_uygulama(Builder(
        builder: (c) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              sonuc = await Navigator.of(c).push<YemekGorunumu>(
                  MaterialPageRoute(builder: (_) => _sayfa()));
              kapandi = true;
            },
            child: const Text('Aç'),
          ),
        ),
      )));
      await t.tap(find.text('Aç'));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(kapandi, isTrue);
      expect(sonuc, isNull);
    });
  });

  group('yorumlar', () {
    testWidgets('yorum bölümü var, ayrıca ikinci bir puan kartı yok',
        (t) async {
      await _ac(t, _sayfa());
      expect(find.text('Bu yemek hakkında'), findsOneWidget);
      expect(find.text('Yorumlar'), findsNothing);
      expect(find.text('İlk yorumu sen yaz.'), findsOneWidget);
      expect(find.text('Puan'), findsOneWidget);
    });

    testWidgets('yorum eklenince yemek slotuna yazılır', (t) async {
      final gb = YerelDepo();
      await _ac(t, _sayfa(gb: gb));
      await t.enterText(find.byType(TextField), 'Çok güzeldi');
      SharedPreferences.setMockInitialValues(
          {'yorum_adi': 'Ali', 'topluluk_kurallari_surum': 1});
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();
      final yorumlar = await gb.yorumlar(_slot('manti'));
      expect(yorumlar.map((y) => y.metin), ['Çok güzeldi']);
    });

    testWidgets('yemek slotundaki yorumlar listelenir', (t) async {
      final gb = YerelDepo();
      await gb.yorumEkle(_slot('manti'), 'Ali', 'Çok güzeldi');
      await gb.yorumEkle(_slot('pilav'), 'Veli', 'Başka yemeğin yorumu');
      await _ac(t, _sayfa(gb: gb));
      expect(find.text('Bu yemek hakkında (1)'), findsOneWidget);
      expect(find.text('Çok güzeldi'), findsOneWidget);
      expect(find.text('Başka yemeğin yorumu'), findsNothing);
    });
  });

  group('taşma', () {
    for (final parlaklik in Brightness.values) {
      for (final foto in [false, true]) {
        testWidgets(
            '320x640, yazı 1.5x, uzun ad, ${foto ? 'fotoğraflı' : 'fotoğrafsız'} ($parlaklik): baştan sona kaydırınca taşma yok',
            (t) async {
          final resim = foto ? (await t.runAsync(createTestImage))! : null;
          await _ac(
              t,
              _sayfa(
                  yemek: _y(_uzunAd, 'manti', 1234),
                  menu: Menu('ankara', null, {
                    for (var g = 20; g <= 30; g++)
                      '2026-10-$g': {
                        'lunch': Ogun([_y(_uzunAd, 'manti', 1234)], 1234),
                        'dinner': Ogun([_y(_uzunAd, 'manti', 1234)], 1234),
                      },
                    '2026-11-02': {
                      'lunch': Ogun([_y(_uzunAd, 'manti', 1234)], 1234)
                    },
                  }),
                  foto: resim == null ? null : _HazirResim(resim),
                  favoriler: FavoriDeposu()),
              boyut: const Size(320, 640),
              olcek: 1.5,
              parlaklik: parlaklik);
          expect(t.takeException(), isNull);
          for (var i = 0; i < 12; i++) {
            await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: 'kaydırma $i');
          }
          // "Tümünü göster" ile en uzun liste de taşmaz
          await t.drag(find.byType(CustomScrollView), const Offset(0, 6000));
          await t.pumpAndSettle();
          final tumu = find.textContaining('Tümünü göster');
          await _gor(t, tumu);
          await t.tap(tumu);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          for (var i = 0; i < 20; i++) {
            await t.drag(find.byType(CustomScrollView), const Offset(0, -400));
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('liste satırları >= 48 dp', (t) async {
      await _ac(t, _sayfa(), boyut: const Size(320, 640), olcek: 1.5);
      final satir = find.widgetWithText(ListTile, 'Bugün · 2 Kasım');
      await _gor(t, satir);
      expect(t.getSize(satir).height, greaterThanOrEqualTo(48));
    });
  });

  group('ana sayfa entegrasyonu', () {
    testWidgets('satırın adına dokununca ayrıntı sayfası açılır', (t) async {
      await _anaSayfa(t);
      expect(find.byType(YemekDetaySayfasi), findsNothing);
      await t.tap(find.text('Mercimek Çorbası'));
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(find.text('120 kkal'), findsOneWidget);
      expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
      expect(find.byTooltip('3 yıldız'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsNothing);
    });

    testWidgets('yemek resmine dokununca da açılır', (t) async {
      await _anaSayfa(t);
      await t.tap(find.byType(YemekResmi).first);
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsOneWidget);
    });

    testWidgets('"Puanla" da ayrıntı sayfasına götürür', (t) async {
      await _anaSayfa(t);
      await t.tap(find.text('Puanla').first);
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
    });

    testWidgets('anahtarsız yemek (Ayran) dokunulmaz, sayfa açılmaz',
        (t) async {
      await _anaSayfa(t);
      await t.tap(find.text('Ayran'));
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsNothing);
    });

    testWidgets('oy verilip dönülünce satırdaki puan güncellenir', (t) async {
      await _anaSayfa(t);
      await t.tap(find.text('Mercimek Çorbası'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('5 yıldız'));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('5.0 · 1 oy · senin: 5'), findsOneWidget);
      expect(find.text('Puanla'), findsNWidgets(1)); // Pirinç Pilavı satırı
    });

    testWidgets('detaydaki kalp ana sayfadaki kalbi ve şeridi de günceller',
        (t) async {
      final f = await _anaSayfa(t);
      await t.tap(find.text('Mercimek Çorbası'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Favorilere ekle'));
      await t.pumpAndSettle();
      expect(f.varMi('mercimek'), isTrue);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(
          find.text('Bugün menüde: Mercimek Çorbası (öğle)'), findsOneWidget);
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
    });

    testWidgets('yaklaşan gün seçilince ana sayfa o güne geçer', (t) async {
      await _anaSayfa(t);
      await t.tap(find.text('Pirinç Pilavı'));
      await t.pumpAndSettle();
      // Pirinç Pilavı: Bugün, Yarın (öğle) ve geçmişte Cuma 30 Ekim
      expect(find.text('Yarın · 3 Kasım'), findsOneWidget);
      await t.tap(find.text('Yarın · 3 Kasım'));
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsNothing);
      expect(find.text('Yarın'), findsOneWidget); // gün başlığı
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsNothing);
    });

    testWidgets('akşam öğününe giden satır Akşam sekmesini açar', (t) async {
      await _anaSayfa(t);
      await t.tap(find.text('Akşam')); // sekme
      await t.pumpAndSettle();
      await t.tap(find.text('Fırın Makarna'));
      await t.pumpAndSettle();
      expect(find.text('Perşembe 5 Kasım'), findsOneWidget);
      await t.tap(find.text('Perşembe 5 Kasım'));
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsNothing);
      expect(find.text('Perşembe'), findsOneWidget);
      expect(find.text('Fırın Makarna'), findsOneWidget); // akşam menüsü
      expect(find.text('Kuru Fasulye'), findsNothing); // öğle değil
    });

    testWidgets(
        'geçmiş gün seçilince o güne geçer, gün çubuğu uzar ve ileri gidilebilir',
        (t) async {
      await _anaSayfa(t);
      await t.tap(find.text('Pirinç Pilavı'));
      await t.pumpAndSettle();
      await _gor(t, find.text('Cuma 30 Ekim'));
      await t.tap(find.text('Cuma 30 Ekim'));
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsNothing);
      expect(find.text('Cuma'), findsOneWidget); // gün başlığı
      expect(find.text('Geçen Cuma Mantısı'), findsOneWidget);
      // seçili gün çubukta: ilk gün olduğu için geri pasif, ileri aktif
      final geri = t.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_left));
      final ileri = t.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(geri.onPressed, isNull);
      expect(ileri.onPressed, isNotNull);
      // bugüne kadar ileri gidilir; sonra gün çubuğu eski haline döner (geçmiş günler çıkar)
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byTooltip('Sonraki gün'));
        await t.pumpAndSettle();
      }
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      final geri2 = t.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_left));
      expect(geri2.onPressed, isNull); // bugün yeniden ilk gün
      expect(t.takeException(), isNull);
    });

    testWidgets(
        '320x640, yazı 1.5x: ayrıntı sayfası ana sayfadan açılınca taşmaz',
        (t) async {
      await _anaSayfa(t, boyut: const Size(320, 640), olcek: 1.5);
      final ad = find.text('Pirinç Pilavı');
      await _gor(t, ad);
      await t.tap(ad);
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsOneWidget);
      expect(t.takeException(), isNull);
      for (var i = 0; i < 6; i++) {
        await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
    });
  });
}
