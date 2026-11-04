import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/config.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/yemek_detay.dart';
import 'package:yemekhane/tema.dart';

import 'sahte_resim.dart';

// Tur 10: yemek fotoğrafının Commons bilgisi (Depo.yemekBilgisi), detay sayfasında yüksek çözünürlüklü kapak +
// atıf satırı ve yorum bölümü başlıkları. Gerçek ağa gidilmez: Depo sahte http istemcisiyle, fotoğraflar sahte
// ImageProvider'larla sınanır.

const _atifMetni = 'Fotoğraf: Ali Veli · CC BY-SA 3.0 · Wikimedia Commons';
const _notMetni = 'Örnek fotoğraf, okuldaki yemek birebir aynı görünmeyebilir.';
const _kopyalandi = 'Fotoğraf sayfasının bağlantısı panoya kopyalandı';
const _sayfaAdresi = 'https://commons.wikimedia.org/wiki/File:Manti_Utah.jpg';

YemekBilgisi _bilgi(
        {String? yazar = 'Ali Veli',
        String? lisans = 'CC BY-SA 3.0',
        String baslik = 'Manti Utah.jpg',
        String? sayfa = _sayfaAdresi}) =>
    YemekBilgisi(
        baslik: baslik,
        yazar: yazar,
        lisans: lisans,
        sayfa: sayfa ?? commonsSayfaUrl(baslik));

YemekOgesi _y(String ad, String? anahtar, {int? kcal, String? img}) =>
    YemekOgesi(ad, kcal, img, anahtar);

Universite _uni() => Universite(
    id: 'ankara',
    ad: 'Ankara Üniversitesi',
    kisa: 'AÜ',
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

Menu _menu() => Menu('ankara', null, {
      '2026-11-02': {
        'lunch': Ogun([
          _y('Mantı', 'manti', kcal: 450, img: 'dishes/manti.jpg'),
          _y('Mercimek Çorbası', 'mercimek', kcal: 120),
          _y('Ayran', null, kcal: 60),
        ], 630),
      },
    });

Widget _uygulama(Widget home,
        {double olcek = 1.0, bool animasyonKapali = false}) =>
    MaterialApp(
      theme: TemaAyari().tema(Brightness.light),
      builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
              textScaler: TextScaler.linear(olcek),
              disableAnimations: animasyonKapali),
          child: w!),
      home: home,
    );

YemekDetaySayfasi _sayfa(
        {ImageProvider? foto,
        Future<YemekBilgisi?> Function()? bilgi,
        ImageProvider Function(String)? buyuk,
        YemekOgesi? yemek}) =>
    YemekDetaySayfasi(
        yemek: yemek ?? _y('Mantı', 'manti', kcal: 450),
        uni: _uni(),
        menu: _menu(),
        bugun: '2026-11-02',
        foto: foto,
        fotoBilgisi: bilgi,
        buyukFotoOlustur: buyuk,
        geriBildirim: YerelDepo());

Future<void> _ac(WidgetTester t, YemekDetaySayfasi sayfa,
    {Size boyut = const Size(400, 2400),
    double olcek = 1.0,
    bool animasyonKapali = false}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
      _uygulama(sayfa, olcek: olcek, animasyonKapali: animasyonKapali));
  await t.pumpAndSettle();
}

/// [saglayici]yı gösteren Image.
Finder _resim(ImageProvider saglayici) =>
    find.byWidgetPredicate((w) => w is Image && identical(w.image, saglayici));

/// [saglayici]yı gösteren Image'ın belirme geçişi (Image'ın frameBuilder'ı AnimatedOpacity kurar).
Finder _gecis(ImageProvider saglayici) => find.descendant(
    of: _resim(saglayici), matching: find.byType(AnimatedOpacity));

/// Panoya yazılan metinleri toplar (SystemChannels.platform sahtesi). [hata] true ise pano çalışmaz.
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

/// Gerçek data/dishes/index.json'a benzeyen küçük bir dosya.
String _indeks() => jsonEncode({
      'dishes': {
        'manti': {
          'baslik': 'Manti Utah.jpg',
          'kaynak': 'Wikimedia Commons',
          'lisans': 'CC BY-SA 3.0',
          'name': 'Mantı',
          'sayfa': _sayfaAdresi,
          'yazar': 'Ali Veli',
        },
        'yazarsiz': {
          'baslik': 'Tres leches cake.jpg',
          'lisans': 'CC BY-SA 2.0',
          'sayfa':
              'https://commons.wikimedia.org/wiki/File:Tres_leches_cake.jpg',
          'yazar': '',
        },
        'bozuk': 'bu bir kayıt değil',
        'basliksiz': {'lisans': 'CC0', 'yazar': 'X'},
      },
      'miss': ['yok1', 'yok2'],
    });

http.Response _yanit(String govde, [int kod = 200]) =>
    http.Response.bytes(utf8.encode(govde), kod);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('yuksekCozunurlukUrl / commonsSayfaUrl', () {
    const taban = 'https://commons.wikimedia.org/wiki/Special:FilePath/';

    test('boşluklar alt çizgi olur, Türkçe harfler kodlanır, genişlik 960', () {
      expect(yuksekCozunurlukUrl('Kuru köfte ve pilav.jpg'),
          '${taban}Kuru_k%C3%B6fte_ve_pilav.jpg?width=960');
      expect(yuksekCozunurlukUrl('Manti Utah.jpg'),
          '${taban}Manti_Utah.jpg?width=960');
    });

    test('parantez, virgül, kesme ve ayrılmış karakterler', () {
      expect(yuksekCozunurlukUrl('Dana haşlama (Black Sea cuisine).jpg'),
          '${taban}Dana_ha%C5%9Flama_(Black_Sea_cuisine).jpg?width=960');
      expect(yuksekCozunurlukUrl('Doner Kebab, sols carn.jpg'),
          '${taban}Doner_Kebab%2C_sols_carn.jpg?width=960');
      expect(yuksekCozunurlukUrl("Sam'dan lokma tatlisi.jpg"),
          "${taban}Sam'dan_lokma_tatlisi.jpg?width=960");
      expect(yuksekCozunurlukUrl('a&b?c#d%e+f.png'),
          '${taban}a%26b%3Fc%23d%25e%2Bf.png?width=960');
    });

    test('genişlik ayarlanabilir', () {
      expect(yuksekCozunurlukUrl('A b.jpg', genislik: 480),
          '${taban}A_b.jpg?width=480');
    });

    test('üretilen adres geçerlidir: tek yol parçası, tek sorgu değeri', () {
      final u = Uri.parse(yuksekCozunurlukUrl('Çok  uzun / eğik çizgili.jpg'));
      expect(u.scheme, 'https');
      expect(u.host, 'commons.wikimedia.org');
      expect(u.pathSegments.length, 3); // wiki, Special:FilePath, dosya adı
      // pathSegments zaten çözülmüş gelir: '/' kodlandığı için yol parçası bölünmedi
      expect(u.pathSegments.last, 'Çok__uzun_/_eğik_çizgili.jpg');
      expect(u.queryParameters, {'width': '960'});
    });

    test('commonsSayfaUrl: File: sayfası', () {
      expect(commonsSayfaUrl('Manti Utah.jpg'), _sayfaAdresi);
      expect(commonsSayfaUrl('Kuru köfte.jpg'),
          'https://commons.wikimedia.org/wiki/File:Kuru_k%C3%B6fte.jpg');
    });

    test(
        'commonsFotoSaglayici: NetworkImage + tanımlayıcı User-Agent (web dışı)',
        () {
      expect(kIsWeb, isFalse);
      final p = commonsFotoSaglayici('https://x.test/a.jpg');
      expect(p, isA<NetworkImage>());
      final n = p as NetworkImage;
      expect(n.url, 'https://x.test/a.jpg');
      expect(n.headers, {
        'User-Agent':
            'UniYemek/$uygulamaSurumu (https://github.com/olgatanriverdi-glitch/yemekhane)'
      });
      expect(commonsKullaniciAjani, startsWith('UniYemek/$uygulamaSurumu ('));
    });
  });

  group('YemekBilgisi', () {
    test('tam kayıt', () {
      final b = YemekBilgisi.fromJson({
        'baslik': 'Kuru köfte ve pilav.jpg',
        'kaynak': 'Wikimedia Commons',
        'lisans': 'CC BY-SA 4.0',
        'name': 'Kuru Köfte/Garnitür',
        'sayfa':
            'https://commons.wikimedia.org/wiki/File:Kuru_k%C3%B6fte_ve_pilav.jpg',
        'sorgu': 'Kuru Köfte',
        'yazar': 'E4024',
      })!;
      expect(b.baslik, 'Kuru köfte ve pilav.jpg');
      expect(b.yazar, 'E4024');
      expect(b.lisans, 'CC BY-SA 4.0');
      expect(b.sayfa,
          'https://commons.wikimedia.org/wiki/File:Kuru_k%C3%B6fte_ve_pilav.jpg');
      expect(b.atif, 'Fotoğraf: E4024 · CC BY-SA 4.0 · Wikimedia Commons');
      expect(b.yuksekCozunurlukAdresi,
          yuksekCozunurlukUrl('Kuru köfte ve pilav.jpg'));
    });

    test('yazar ya da lisans yoksa / boşsa atıf yok', () {
      final yazarsiz = YemekBilgisi.fromJson(
          {'baslik': 'A.jpg', 'yazar': '', 'lisans': 'CC0'})!;
      expect(yazarsiz.yazar, isNull);
      expect(yazarsiz.atif, isNull);
      final lisanssiz =
          YemekBilgisi.fromJson({'baslik': 'A.jpg', 'yazar': 'X'})!;
      expect(lisanssiz.lisans, isNull);
      expect(lisanssiz.atif, isNull);
      final bosluk = YemekBilgisi.fromJson(
          {'baslik': 'A.jpg', 'yazar': '   ', 'lisans': '  '})!;
      expect(bosluk.atif, isNull);
      // yine de yüksek çözünürlüklü sürüm bulunabilir
      expect(bosluk.yuksekCozunurlukAdresi, yuksekCozunurlukUrl('A.jpg'));
    });

    test('metinler kırpılır', () {
      final b = YemekBilgisi.fromJson(
          {'baslik': '  A b.jpg ', 'yazar': ' Ali ', 'lisans': ' CC0 '})!;
      expect(b.baslik, 'A b.jpg');
      expect(b.atif, 'Fotoğraf: Ali · CC0 · Wikimedia Commons');
    });

    test('dosya adı yok ya da kayıt bozuksa null', () {
      expect(YemekBilgisi.fromJson(null), isNull);
      expect(YemekBilgisi.fromJson('metin'), isNull);
      expect(YemekBilgisi.fromJson(42), isNull);
      expect(YemekBilgisi.fromJson(<String, dynamic>{}), isNull);
      expect(YemekBilgisi.fromJson({'baslik': ''}), isNull);
      expect(YemekBilgisi.fromJson({'baslik': 5, 'yazar': 'X'}), isNull);
    });

    test('sayfa adresi yoksa ya da https değilse dosya adından üretilir', () {
      expect(YemekBilgisi.fromJson({'baslik': 'Manti Utah.jpg'})!.sayfa,
          _sayfaAdresi);
      expect(
          YemekBilgisi.fromJson(
                  {'baslik': 'Manti Utah.jpg', 'sayfa': 'javascript:alert(1)'})!
              .sayfa,
          _sayfaAdresi);
      expect(
          YemekBilgisi.fromJson({'baslik': 'Manti Utah.jpg', 'sayfa': 7})!
              .sayfa,
          _sayfaAdresi);
    });
  });

  group('Depo.yemekBilgisi', () {
    const indeksAdresi = '$veriTabanUrl/dishes/index.json';

    test(
        'internetten bir kez indirilir, bellekte tutulur, önbelleğe yazılır; çevrimdışı bayrağı değişmez',
        () async {
      final istekler = <String>[];
      final depo = Depo(istemci: MockClient((r) async {
        istekler.add(r.url.toString());
        return _yanit(_indeks());
      }));
      depo.cevrimdisi = true; // menü yüklemesinden kalan durum bozulmamalı
      final b = await depo.yemekBilgisi('manti');
      expect(b, isNotNull);
      expect(b!.baslik, 'Manti Utah.jpg');
      expect(b.yazar, 'Ali Veli');
      expect(b.lisans, 'CC BY-SA 3.0');
      expect(b.sayfa, _sayfaAdresi);
      expect(istekler, [indeksAdresi]);

      // sonraki çağrılar ağa gitmez
      expect((await depo.yemekBilgisi('yazarsiz'))!.baslik,
          'Tres leches cake.jpg');
      expect(await depo.yemekBilgisi('olmayan'), isNull);
      expect(istekler, hasLength(1));

      final p = await SharedPreferences.getInstance();
      expect(p.getString('onbellek/dishes/index.json'), _indeks());
      expect(depo.cevrimdisi, isTrue);
    });

    test('aynı anda gelen istekler tek ağ isteğini paylaşır', () async {
      var istek = 0;
      final depo = Depo(istemci: MockClient((r) async {
        istek++;
        return _yanit(_indeks());
      }));
      final sonuc = await Future.wait(
          [depo.yemekBilgisi('manti'), depo.yemekBilgisi('yazarsiz')]);
      expect(sonuc.map((b) => b?.baslik),
          ['Manti Utah.jpg', 'Tres leches cake.jpg']);
      expect(istek, 1);
    });

    test('bozuk ya da başlıksız kayıt yalnızca o yemeği null yapar', () async {
      final depo = Depo(istemci: MockClient((r) async => _yanit(_indeks())));
      expect(await depo.yemekBilgisi('bozuk'), isNull);
      expect(await depo.yemekBilgisi('basliksiz'), isNull);
      expect(await depo.yemekBilgisi('manti'), isNotNull);
      final yazarsiz = (await depo.yemekBilgisi('yazarsiz'))!;
      expect(yazarsiz.yazar, isNull); // boş yazar yok sayılır
      expect(yazarsiz.atif, isNull);
    });

    test('boş anahtar ağa gitmez', () async {
      var istek = 0;
      final depo = Depo(istemci: MockClient((r) async {
        istek++;
        return _yanit(_indeks());
      }));
      expect(await depo.yemekBilgisi(''), isNull);
      expect(istek, 0);
    });

    test('ağ hatasında önbellekteki kopya kullanılır', () async {
      SharedPreferences.setMockInitialValues(
          {'onbellek/dishes/index.json': _indeks()});
      final depo = Depo(
          istemci:
              MockClient((r) async => throw http.ClientException('ağ yok')));
      final b = await depo.yemekBilgisi('manti');
      expect(b?.yazar, 'Ali Veli');
      expect(depo.cevrimdisi,
          isFalse); // isteğe bağlı dosya "çevrimdışı" uyarısı çıkarmaz
    });

    test('sunucu 404 verirse de önbellek kullanılır', () async {
      SharedPreferences.setMockInitialValues(
          {'onbellek/dishes/index.json': _indeks()});
      final depo =
          Depo(istemci: MockClient((r) async => _yanit('bulunamadı', 404)));
      expect((await depo.yemekBilgisi('manti'))?.baslik, 'Manti Utah.jpg');
    });

    test('ağ da önbellek de yoksa null döner, hata fırlatmaz', () async {
      final depo = Depo(
          istemci:
              MockClient((r) async => throw http.ClientException('ağ yok')));
      expect(await depo.yemekBilgisi('manti'), isNull);
      expect(depo.cevrimdisi, isFalse);
    });

    test('bozuk JSON önbelleğe yazılmaz, null döner', () async {
      final depo = Depo(istemci: MockClient((r) async => _yanit('{bozuk')));
      expect(await depo.yemekBilgisi('manti'), isNull);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('onbellek/dishes/index.json'), isNull);
    });

    test('"dishes" tablosu olmayan dosya null verir', () async {
      final depo =
          Depo(istemci: MockClient((r) async => _yanit('{"miss": []}')));
      expect(await depo.yemekBilgisi('manti'), isNull);
    });

    test('başarısız okuma bellekte tutulmaz: sonraki çağrı yeniden dener',
        () async {
      var istek = 0;
      final depo = Depo(istemci: MockClient((r) async {
        istek++;
        if (istek == 1) throw http.ClientException('ağ yok');
        return _yanit(_indeks());
      }));
      expect(await depo.yemekBilgisi('manti'), isNull);
      expect((await depo.yemekBilgisi('manti'))?.baslik, 'Manti Utah.jpg');
      expect(istek, 2);
      expect(await depo.yemekBilgisi('manti'), isNotNull);
      expect(istek, 2); // başarılı sonuç artık bellekte
    });

    test('Ayarlar > önbelleği temizle bu kopyayı da siler', () async {
      final depo = Depo(istemci: MockClient((r) async => _yanit(_indeks())));
      await depo.yemekBilgisi('manti');
      expect(await depo.onbellekTemizle(), 1);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('onbellek/dishes/index.json'), isNull);
    });
  }, skip: veriTabanUrl.isEmpty ? 'VERI_URL boş: Depo ağa gitmez' : false);

  group('detay kapağı: yüksek çözünürlüklü fotoğraf', () {
    testWidgets(
        'bilgi gelince yüksek çözünürlüklü adres istenir; yüklenene kadar küçük fotoğraf görünür',
        (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      final kucuk = HazirResim(resim);
      final buyuk = GecikmeliResim();
      final istenen = <String>[];
      var bilgiIstegi = 0;
      await _ac(
          t,
          _sayfa(
              foto: kucuk,
              bilgi: () async {
                bilgiIstegi++;
                return _bilgi();
              },
              buyuk: (adres) {
                istenen.add(adres);
                return buyuk;
              }));
      expect(bilgiIstegi, 1);
      expect(istenen, [yuksekCozunurlukUrl('Manti Utah.jpg')]);
      expect(_resim(kucuk), findsOneWidget);
      expect(_resim(buyuk), findsOneWidget);
      // büyük fotoğraf gelene kadar saydam: küçük fotoğraf kapakta görünür kalır
      expect(t.widget<AnimatedOpacity>(_gecis(buyuk)).opacity, 0);
      expect(find.text(_notMetni), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('yüklenince 250 ms içinde yumuşakça belirir', (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      final buyuk = GecikmeliResim();
      await _ac(
          t,
          _sayfa(
              foto: HazirResim(resim),
              bilgi: () async => _bilgi(),
              buyuk: (_) => buyuk));
      FadeTransition solma() => t.widget<FadeTransition>(find.descendant(
          of: _gecis(buyuk), matching: find.byType(FadeTransition)));
      expect(solma().opacity.value, 0);

      buyuk.tamamla(resim);
      await t.pump(); // tamamlanma bildirimi işlenir, yeni kare istenir
      await t.pump(); // ilk kare gelir, geçiş başlar
      final animasyon = t.widget<AnimatedOpacity>(_gecis(buyuk));
      expect(animasyon.opacity, 1);
      expect(animasyon.duration, const Duration(milliseconds: 250));
      await t.pump(const Duration(milliseconds: 100));
      expect(solma().opacity.value, inExclusiveRange(0.0, 1.0));
      await t.pumpAndSettle();
      expect(solma().opacity.value, 1.0);
      expect(t.takeException(), isNull);
    });

    testWidgets('animasyonlar kapalıysa geçiş süresi 0', (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      final buyuk = GecikmeliResim();
      await _ac(
          t,
          _sayfa(
              foto: HazirResim(resim),
              bilgi: () async => _bilgi(),
              buyuk: (_) => buyuk),
          animasyonKapali: true);
      buyuk.tamamla(resim);
      await t.pump();
      await t.pump();
      expect(t.widget<AnimatedOpacity>(_gecis(buyuk)).opacity, 1);
      expect(t.widget<AnimatedOpacity>(_gecis(buyuk)).duration, Duration.zero);
    });

    testWidgets('önbellekten hemen gelen fotoğrafta geçiş animasyonu yok',
        (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      final buyuk = HazirResim(resim);
      await _ac(
          t,
          _sayfa(
              foto: HazirResim(resim),
              bilgi: () async => _bilgi(),
              buyuk: (_) => buyuk));
      expect(_resim(buyuk), findsOneWidget);
      expect(_gecis(buyuk), findsNothing);
    });

    testWidgets(
        'yüksek çözünürlük yüklenemezse küçük fotoğraf kalır, hata gösterilmez',
        (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      final kucuk = HazirResim(resim);
      final buyuk = GecikmeliResim();
      await _ac(
          t,
          _sayfa(
              foto: kucuk, bilgi: () async => _bilgi(), buyuk: (_) => buyuk));
      buyuk.hata();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(_resim(kucuk), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsNothing); // yer tutucu değil
      // küçük fotoğraf göründüğü için not ve atıf yerinde
      expect(find.text(_notMetni), findsOneWidget);
      expect(find.text(_atifMetni), findsOneWidget);
    });

    testWidgets('bilgi yoksa (null) yüksek çözünürlük istenmez, atıf çıkmaz',
        (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      var istenen = 0;
      await _ac(
          t,
          _sayfa(
              foto: HazirResim(resim),
              bilgi: () async => null,
              buyuk: (_) {
                istenen++;
                return BozukResim();
              }));
      expect(istenen, 0);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text(_notMetni), findsOneWidget);
      expect(find.textContaining('Wikimedia Commons'), findsNothing);
    });

    testWidgets('bilgi alınırken hata olursa küçük fotoğraf kalır', (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      var istenen = 0;
      await _ac(
          t,
          _sayfa(
              foto: HazirResim(resim),
              bilgi: () async => throw Exception('ağ yok'),
              buyuk: (_) {
                istenen++;
                return BozukResim();
              }));
      expect(t.takeException(), isNull);
      expect(istenen, 0);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text(_notMetni), findsOneWidget);
      expect(find.textContaining('Fotoğraf: '), findsNothing);
    });

    testWidgets('bilgi getirici verilmezse sayfa eskisi gibidir', (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      await _ac(t, _sayfa(foto: HazirResim(resim)));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text(_notMetni), findsOneWidget);
      expect(find.textContaining('Fotoğraf: '), findsNothing);
    });

    testWidgets('bilgi sayfa başına bir kez istenir', (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      var istek = 0;
      await _ac(
          t,
          _sayfa(
              foto: HazirResim(resim),
              bilgi: () async {
                istek++;
                return _bilgi();
              },
              buyuk: (_) => GecikmeliResim()));
      await t.pump(const Duration(seconds: 1));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await t.pumpAndSettle();
      expect(istek, 1);
    });

    testWidgets(
        'bilgi gelmeden sayfa kapanırsa hata olmaz ve fotoğraf istenmez',
        (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      final bekleyen = Completer<YemekBilgisi?>();
      var istenen = 0;
      await _ac(
          t,
          _sayfa(
              foto: HazirResim(resim),
              bilgi: () => bekleyen.future,
              buyuk: (_) {
                istenen++;
                return BozukResim();
              }));
      await t.pumpWidget(const SizedBox()); // sayfa kapandı
      bekleyen.complete(_bilgi());
      await t.pump();
      expect(istenen, 0);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'küçük fotoğraf yoksa yüklenen büyük fotoğraf kapağı doldurur, not ve atıf çıkar',
        (t) async {
      final resim = (await t.runAsync(createTestImage))!;
      final buyuk = HazirResim(resim);
      await _ac(t, _sayfa(bilgi: () async => _bilgi(), buyuk: (_) => buyuk));
      expect(_resim(buyuk), findsOneWidget);
      expect(find.text(_notMetni), findsOneWidget);
      expect(find.text(_atifMetni), findsOneWidget);
    });

    testWidgets('fotoğraf hiç yüklenemezse yer tutucu görünür, not ve atıf yok',
        (t) async {
      await _ac(
          t,
          _sayfa(
              foto: BozukResim(),
              bilgi: () async => _bilgi(),
              buyuk: (_) => BozukResim()));
      expect(t.takeException(), isNull);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.text(_notMetni), findsNothing);
      expect(find.textContaining('Wikimedia Commons'), findsNothing);
    });

    testWidgets('kapak anlam etiketi yemeğin adını söyler (tek düğüm)',
        (t) async {
      final anlam = t.ensureSemantics();
      try {
        final resim = (await t.runAsync(createTestImage))!;
        await _ac(
            t,
            _sayfa(
                foto: HazirResim(resim),
                bilgi: () async => _bilgi(),
                buyuk: (_) => HazirResim(resim)));
        expect(find.bySemanticsLabel('Fotoğraf: Mantı'), findsOneWidget);
      } finally {
        anlam.dispose();
      }
    });
  });

  group('atıf satırı', () {
    Future<void> goster(WidgetTester t, YemekBilgisi? bilgi,
        {Size boyut = const Size(400, 2400), double olcek = 1.0}) async {
      final resim = (await t.runAsync(createTestImage))!;
      await _ac(
          t,
          _sayfa(
              foto: HazirResim(resim),
              bilgi: () async => bilgi,
              buyuk: (_) => GecikmeliResim()),
          boyut: boyut,
          olcek: olcek);
    }

    testWidgets(
        'yazar ve lisans varsa "Fotoğraf: yazar · lisans · Wikimedia Commons"',
        (t) async {
      await goster(t, _bilgi());
      expect(find.text(_atifMetni), findsOneWidget);
      // not satırının altında
      expect(t.getTopLeft(find.text(_atifMetni)).dy,
          greaterThan(t.getTopLeft(find.text(_notMetni)).dy));
    });

    testWidgets('yazar yoksa satır yok (not kalır)', (t) async {
      await goster(t, _bilgi(yazar: null));
      expect(find.textContaining('Fotoğraf: '), findsNothing);
      expect(find.text(_notMetni), findsOneWidget);
      await goster(t, _bilgi(yazar: '  '));
      expect(find.textContaining('Fotoğraf: '), findsNothing);
    });

    testWidgets('lisans yoksa satır yok', (t) async {
      await goster(t, _bilgi(lisans: null));
      expect(find.textContaining('Fotoğraf: '), findsNothing);
      expect(find.text(_notMetni), findsOneWidget);
    });

    testWidgets('düğme olarak okunur, dokunma hedefi >= 48 dp', (t) async {
      final anlam = t.ensureSemantics();
      try {
        await goster(t, _bilgi());
        final dugum = t.getSemantics(find.text(_atifMetni));
        final veri = dugum.getSemanticsData();
        expect(veri.label, contains(_atifMetni));
        expect(veri.flagsCollection.isButton, isTrue);
        expect(veri.hasAction(SemanticsAction.tap), isTrue);
        expect(dugum.rect.height, greaterThanOrEqualTo(48));
        expect(dugum.rect.width, greaterThanOrEqualTo(48));
        // yanındaki "Örnek fotoğraf" notu ayrı, dokunulamaz bir düğümdür (düğmeyle birleşmez)
        expect(veri.label, isNot(contains('Örnek fotoğraf')));
        final not = t.getSemantics(find.text(_notMetni)).getSemanticsData();
        expect(not.label, _notMetni);
        expect(not.flagsCollection.isButton, isFalse);
        expect(not.hasAction(SemanticsAction.tap), isFalse);
      } finally {
        anlam.dispose();
      }
    });

    testWidgets('dokununca fotoğraf sayfasının adresi panoya kopyalanır',
        (t) async {
      final pano = _panoyuDinle(t);
      await goster(t, _bilgi());
      expect(find.text(_kopyalandi), findsNothing);
      await t.tap(find.text(_atifMetni));
      await t.pump();
      expect(pano, [_sayfaAdresi]);
      expect(find.text(_kopyalandi), findsOneWidget);
    });

    testWidgets(
        'sayfa adresi kayıtta yoksa dosya adından üretilen adres kopyalanır',
        (t) async {
      final pano = _panoyuDinle(t);
      await goster(t, _bilgi(baslik: 'Kuru köfte.jpg', sayfa: null));
      await t.tap(find.text(_atifMetni));
      await t.pump();
      expect(pano,
          ['https://commons.wikimedia.org/wiki/File:Kuru_k%C3%B6fte.jpg']);
    });

    testWidgets('pano çalışmazsa "Bağlantı kopyalanamadı" bildirimi çıkar',
        (t) async {
      final pano = _panoyuDinle(t, hata: true);
      await goster(t, _bilgi());
      await t.tap(find.text(_atifMetni));
      await t.pump();
      expect(pano, isEmpty);
      expect(find.text('Bağlantı kopyalanamadı'), findsOneWidget);
      expect(find.text(_kopyalandi), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        '320x640, yazı 1.5x, çok uzun yazar adı: taşma yok, satır >= 48 dp',
        (t) async {
      await goster(
          t,
          _bilgi(
              yazar:
                  'No machine-readable author provided. Adri08 assumed (based on copyright claims).',
              lisans: 'Copyrighted free use'),
          boyut: const Size(320, 640),
          olcek: 1.5);
      expect(t.takeException(), isNull);
      final satir = find.ancestor(
          of: find.textContaining('Fotoğraf: No machine-readable'),
          matching: find.byType(InkWell));
      expect(satir, findsOneWidget);
      expect(t.getSize(satir).height, greaterThanOrEqualTo(48));
      for (var i = 0; i < 8; i++) {
        await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'kaydırma $i');
      }
    });
  });

  group('ana sayfadan açılan detay', () {
    Future<_FotoluDepo> anaSayfa(WidgetTester t, {YemekBilgisi? bilgi}) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final depo = _FotoluDepo([_uni()], {'ankara': _menu()})..bilgi = bilgi;
      final ayar = TemaAyari();
      await t.pumpWidget(MaterialApp(
          theme: ayar.tema(Brightness.light),
          home: AnaSayfa(
              temaAyari: ayar,
              depo: depo,
              geriBildirim: YerelDepo(),
              simdi: () => DateTime.utc(2026, 11, 2, 10, 0))));
      await t.pumpAndSettle();
      return depo;
    }

    testWidgets(
        'küçük fotoğrafı olan yemekte bilgi anahtarla istenir; fotoğrafsız yemekte istenmez',
        (t) async {
      final depo = await anaSayfa(t, bilgi: _bilgi());
      expect(
          depo.bilgiIstekleri, isEmpty); // liste açılınca değil, sayfa açılınca
      await t.tap(find.text('Mantı'));
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsOneWidget);
      expect(depo.bilgiIstekleri, ['manti']);
      // ağsız testte fotoğraflar yüklenemez: hata gösterilmez, sayfa çalışır
      expect(t.takeException(), isNull);
      expect(find.text('Bu yemek hakkında'), findsOneWidget);

      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.text('Mercimek Çorbası')); // küçük fotoğrafı yok
      await t.pumpAndSettle();
      expect(find.byType(YemekDetaySayfasi), findsOneWidget);
      expect(depo.bilgiIstekleri, ['manti']);
    });

    testWidgets('bilgi dosyası yoksa (null) detay sayfası yine açılır',
        (t) async {
      final depo = await anaSayfa(t);
      await t.tap(find.text('Mantı'));
      await t.pumpAndSettle();
      expect(depo.bilgiIstekleri, ['manti']);
      expect(find.byType(YemekDetaySayfasi), findsOneWidget);
      expect(find.textContaining('Fotoğraf: '), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('yorum başlıkları', () {
    Future<void> kartAc(WidgetTester t, GeriBildirimDeposu gb) async {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: OgunKarti(
                  ogun: Ogun([_y('Mantı', 'manti', kcal: 450)], 450),
                  yemekFoto: (_) => null,
                  geriBildirim: gb,
                  slot: 'ankara_2026-11-02_lunch',
                  uniId: 'ankara'))));
      await t.pumpAndSettle();
    }

    testWidgets('ana ekranda öğün kartının yorum bölümü "Öğün yorumları"',
        (t) async {
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await kartAc(t, YerelDepo());
      expect(find.text('Öğün yorumları'), findsOneWidget);
      expect(find.text('Yorumlar'), findsNothing);
      expect(find.text('İlk yorumu sen yaz.'), findsOneWidget);
    });

    testWidgets('yorum varsa sayı başlığa eklenir', (t) async {
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final gb = YerelDepo();
      await gb.yorumEkle('ankara_2026-11-02_lunch', 'Ali', 'Pilav güzeldi');
      await gb.yorumEkle('ankara_2026-11-02_lunch', 'Veli', 'Çorba sıcaktı');
      await kartAc(t, gb);
      expect(find.text('Öğün yorumları (2)'), findsOneWidget);
    });

    testWidgets(
        'yemek ayrıntısında "Bu yemek hakkında"; ana ekran başlığı orada yok',
        (t) async {
      await _ac(t, _sayfa());
      expect(find.text('Bu yemek hakkında'), findsOneWidget);
      expect(find.text('Öğün yorumları'), findsNothing);
      expect(find.text('Yorumlar'), findsNothing);
    });

    testWidgets(
        'GeriBildirimBolumu: varsayılan başlık "Yorumlar", baslik değişir',
        (t) async {
      Future<void> goster(String? baslik) async {
        await t.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: baslik == null
                        ? GeriBildirimBolumu(
                            depo: YerelDepo(), slot: 's', puanGoster: false)
                        : GeriBildirimBolumu(
                            depo: YerelDepo(),
                            slot: 's',
                            puanGoster: false,
                            baslik: baslik)))));
        await t.pumpAndSettle();
      }

      await goster(null);
      expect(find.text('Yorumlar'), findsOneWidget);
      await goster('Özel başlık');
      expect(find.text('Özel başlık'), findsOneWidget);
      expect(find.text('Yorumlar'), findsNothing);
    });
  });
}

/// Ağa gitmeyen sahte depo: küçük yemek fotoğrafı adresi verir, fotoğraf bilgisi isteklerini sayar.
class _FotoluDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  final List<String> bilgiIstekleri = [];
  YemekBilgisi? bilgi;
  _FotoluDepo(this.liste, this.menuVeri);

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
  String? yemekFotoUrl(String? img) =>
      img == null ? null : 'https://foto.test/$img';
  @override
  Future<YemekBilgisi?> yemekBilgisi(String anahtar) async {
    bilgiIstekleri.add(anahtar);
    return bilgi;
  }
}
