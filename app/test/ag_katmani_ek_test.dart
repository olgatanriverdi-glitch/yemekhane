// P2 (veri ve ağ katmanı) ek testleri: hazır testlerin (ag_katmani_test.dart, ag_zaman_asimi_test.dart)
// kapsamadığı durumlar. Gerçek ağa gidilmez; veri ve Firestore istekleri sahte http istemcisiyle, paket
// verisi (assets) gerektiğinde sahte varlık kanalıyla sınanır.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:yemekhane/screens/yemek_detay.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/ogun_karti.dart';

String _menuJson(String id,
        {String gun = '2026-11-02',
        String guncel = '2026-10-31T08:00:00+03:00'}) =>
    jsonEncode({
      'university': id,
      'updated': guncel,
      'days': {
        gun: {
          'lunch': {
            'items': [
              {'name': 'Mercimek Çorbası', 'kcal': 120}
            ],
            'kcal': 120
          }
        }
      }
    });

http.Response _json(String govde) => http.Response(govde, 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _okul(String id,
        {Object? fiyatlar, Object? saatler, String ad = ''}) =>
    {
      'id': id,
      'name': ad.isEmpty ? 'Okul $id' : ad,
      'short': id,
      'city': 'Ankara',
      'source': '',
      'meals': ['lunch'],
      'prices': fiyatlar ?? [],
      'hours': saatler ?? {},
    };

http.Response _oturumYaniti(int n) => http.Response(
    jsonEncode({
      'idToken': 'tok$n',
      'refreshToken': 'ref$n',
      'localId': 'uid$n',
      'expiresIn': '3600'
    }),
    200);

/// Hiç tamamlanmayan (takılan) yanıt.
Future<http.Response> _takil() => Completer<http.Response>().future;

/// Sahte Firebase sunucusu: oturum açma [oturum] ile, diğer her istek [digerleri] ile yanıtlanır (varsayılan:
/// oturum açılır, geri kalan her şey takılır). İstekler kaydedilir.
class _SahteSunucu {
  final List<String> istekler = [];
  Future<http.Response> Function() oturum = () async => _oturumYaniti(1);
  Future<http.Response> Function() digerleri = _takil;

  int get oturumSayisi =>
      istekler.where((e) => e.contains('accounts:signUp')).length;

  late final MockClient istemci = MockClient((r) {
    istekler.add('${r.method} ${r.url}');
    return r.url.toString().contains('accounts:signUp')
        ? oturum()
        : digerleri();
  });
}

/// Bir Future'ın bitip bitmediğini ve hatasını izler.
class _Sonuc {
  bool bitti = false;
  Object? hata;
}

_Sonuc _izle(Future<Object?> f) {
  final s = _Sonuc();
  f.then<void>((_) => s.bitti = true, onError: (Object e) {
    s.bitti = true;
    s.hata = e;
  });
  return s;
}

/// 'assets/data/index.json' için sahte varlık yanıtı: [icerik] null ise dosya yok sayılır. Test bitince gerçek
/// varlık kanalı geri gelir ve rootBundle önbelleğindeki kopya atılır.
void _paketIndeksi(String? icerik) {
  const anahtar = 'assets/data/index.json';
  rootBundle.evict(anahtar);
  final iletisim = TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;
  iletisim.setMockMessageHandler('flutter/assets', (ByteData? mesaj) async {
    final istenen = utf8.decode(
        mesaj!.buffer.asUint8List(mesaj.offsetInBytes, mesaj.lengthInBytes));
    if (istenen != anahtar || icerik == null) return null;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(icerik)));
  });
  addTearDown(() {
    iletisim.setMockMessageHandler('flutter/assets', null);
    rootBundle.evict(anahtar);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Depo: çevrimdışı bayrağı (ek durumlar)', () {
    test(
        'sunucu 404 verirse önbellekteki kopya kullanılır ve çevrimdışı sayılmaz',
        () async {
      SharedPreferences.setMockInitialValues({
        'onbellek/ankara/menu.json': _menuJson('ankara',
            gun: '2099-01-05', guncel: '2099-01-01T00:00:00+03:00')
      });
      final depo =
          Depo(istemci: MockClient((r) async => http.Response('yok', 404)));
      depo.cevrimdisi = true; // önceki bir okuma başarısız olmuştu
      final menu = await depo.menu('ankara');
      expect(menu.tarihler, ['2099-01-05'], reason: 'önbellek kullanılmalı');
      expect(depo.cevrimdisi, isFalse, reason: 'sunucu yanıt verdi');
    });

    test(
        'menuler() başarıyla bitse bile önceden true olan bayrağı false yapmaz',
        () async {
      final depo =
          Depo(istemci: MockClient((r) async => _json(_menuJson('ankara'))));
      depo.cevrimdisi = true;
      final r = await depo.menuler(['ankara', 'gazi']);
      expect(r.values.every((m) => m != null), isTrue);
      expect(depo.cevrimdisi, isTrue);
      await depo
          .menu('ankara'); // seçili okulun kendi okuması bayrağı günceller
      expect(depo.cevrimdisi, isFalse);
    });

    test(
        'menuler() sürerken seçili okulun okuması bayrağı kendi sonucuna göre günceller',
        () async {
      final topluKapi = Completer<void>(), anaKapi = Completer<void>();
      final depo = Depo(istemci: MockClient((r) async {
        if (r.url.path.endsWith('/yok_okul/menu.json')) {
          await topluKapi.future;
          return http.Response('hata', 500);
        }
        await anaKapi.future;
        return _json(_menuJson('ankara'));
      }));
      depo.cevrimdisi = true;
      final toplu =
          depo.menuler(['yok_okul']); // arama başladı (pakette olmayan okul)
      final ana = depo.menu('ankara'); // arama sürerken seçili okul yüklenir
      anaKapi.complete();
      await ana;
      expect(depo.cevrimdisi, isFalse,
          reason: 'arama zone\'u seçili okulun okumasını etkilememeli');
      topluKapi.complete();
      expect((await toplu)['yok_okul'], isNull);
      expect(depo.cevrimdisi, isFalse,
          reason: 'aramadaki hata bayrağı çevirmemeli');
    });
  }, skip: veriTabanUrl.isEmpty ? 'VERI_URL boş: Depo ağa gitmez' : false);

  group('Okul listesi: ek durumlar', () {
    test('Fiyat.jsonDene ve ServisSaati.jsonDene bozuk girdide null verir', () {
      expect(Fiyat.jsonDene({'label': 'Öğrenci', 'tl': 45.9})!.tl, 45);
      expect(Fiyat.jsonDene({'label': 'Öğrenci', 'tl': 45})!.etiket, 'Öğrenci');
      expect(Fiyat.jsonDene({'label': 5, 'tl': 4}), isNull);
      expect(Fiyat.jsonDene({'label': 'x', 'tl': '4'}), isNull);
      expect(Fiyat.jsonDene({'label': 'x', 'tl': double.infinity}), isNull);
      expect(Fiyat.jsonDene({'label': 'x'}), isNull);
      expect(Fiyat.jsonDene('çöp'), isNull);
      expect(Fiyat.jsonDene(null), isNull);
      expect(Fiyat.fromJson({'label': 'Misafir', 'tl': 298}).tl, 298);
      expect(
          () => Fiyat.fromJson({'label': 5, 'tl': 4}), throwsFormatException);

      expect(
          ServisSaati.jsonDene({'t': '11:30–14:00', 'approx': true})!.yaklasik,
          isTrue);
      expect(ServisSaati.jsonDene({'t': '11:30–14:00'})!.yaklasik, isFalse);
      expect(
          ServisSaati.jsonDene({'t': '11:30–14:00', 'approx': 'evet'})!
              .yaklasik,
          isFalse);
      expect(ServisSaati.jsonDene({'t': 3}), isNull);
      expect(ServisSaati.jsonDene({'approx': true}), isNull);
      expect(ServisSaati.jsonDene('11:30'), isNull);
      expect(ServisSaati.jsonDene(null), isNull);
    });

    test('prices liste, hours harita değilse boş kalır; okul düşmez', () {
      final u =
          Universite.fromJson(_okul('x', fiyatlar: 'yok', saatler: [1, 2]));
      expect(u.id, 'x');
      expect(u.fiyatlar, isEmpty);
      expect(u.saatler, isEmpty);
      final v = Universite.fromJson({
        ..._okul('y'),
        'prices': null,
        'hours': null,
      });
      expect(v.fiyatlar, isEmpty);
      expect(v.saatler, isEmpty);
    });

    test('geçerli fiyat ve saatler korunur (sıra ve yaklaşık bilgisi dahil)',
        () {
      final u = Universite.fromJson(_okul('x', fiyatlar: [
        {'label': 'Öğrenci (Öğle Yemeği)', 'tl': 50},
        {'label': 'Misafir', 'tl': 298},
      ], saatler: {
        'lunch': {'t': '11:00–14:00', 'approx': true},
        'dinner': {'t': '17:00–19:00'},
      }));
      expect(u.fiyatlar.map((f) => f.etiket),
          ['Öğrenci (Öğle Yemeği)', 'Misafir']);
      expect(u.ogrenciFiyati('lunch'), 50);
      expect(u.saatler['lunch']!.yaklasik, isTrue);
      expect(u.saatler['dinner']!.yaklasik, isFalse);
    });

    test(
        'uzak listede hiç geçerli okul yoksa uygulamayla gelen liste kullanılır',
        () async {
      final depo = Depo(
          istemci: MockClient((r) async => _json(jsonEncode({
                'universities': [
                  5,
                  {'id': 'adsiz'},
                  {'name': 'kimliksiz'}
                ]
              }))));
      final uniler = await depo.universiteler();
      final idler = uniler.map((u) => u.id).toList();
      expect(idler, contains('ankara'));
      expect(idler, isNot(contains('adsiz')));
      expect(uniler.length, greaterThan(10));
    }, skip: veriTabanUrl.isEmpty ? 'VERI_URL boş: Depo ağa gitmez' : false);

    test(
        'aynı kimlik hem uzakta hem pakette: uzaktaki kayıt kalır, tekrar eklenmez',
        () async {
      final depo = Depo(
          istemci: MockClient((r) async => _json(jsonEncode({
                'universities': [_okul('ankara', ad: 'Uzaktaki Ankara')]
              }))));
      final uniler = await depo.universiteler();
      final ankaralar = uniler.where((u) => u.id == 'ankara').toList();
      expect(ankaralar, hasLength(1));
      expect(ankaralar.single.ad, 'Uzaktaki Ankara');
      expect(uniler.length, greaterThan(10)); // paketteki diğer okullar eklendi
    }, skip: veriTabanUrl.isEmpty ? 'VERI_URL boş: Depo ağa gitmez' : false);

    test('uzak liste okunamazsa (hata) uygulamayla gelen liste kullanılır',
        () async {
      final depo = Depo(
          istemci:
              MockClient((r) async => throw http.ClientException('ağ yok')));
      final uniler = await depo.universiteler();
      expect(uniler.map((u) => u.id), contains('ankara'));
    });

    test('iki liste de boşsa boş liste döner (hata fırlatılmaz)', () async {
      _paketIndeksi(jsonEncode({'universities': []}));
      final depo = Depo(
          istemci:
              MockClient((r) async => _json(jsonEncode({'universities': 5}))));
      expect(await depo.universiteler(), isEmpty);
    });

    test(
        'uzak liste bozuk, paket listesi geçerliyse yalnızca paket listesi döner',
        () async {
      _paketIndeksi(jsonEncode({
        'universities': [_okul('paketli')]
      }));
      final depo = Depo(
          istemci:
              MockClient((r) async => _json(jsonEncode({'universities': 5}))));
      expect((await depo.universiteler()).map((u) => u.id), ['paketli']);
    });

    test('iki liste de okunamıyorsa hata fırlatılır (boş liste sayılmaz)',
        () async {
      _paketIndeksi(null); // paket dosyası yok
      final depo = Depo(
          istemci:
              MockClient((r) async => throw http.ClientException('ağ yok')));
      await expectLater(depo.universiteler(), throwsA(anything));
    });
  });

  group('FirestoreDepo: zaman aşımı ve oturum (ek durumlar)', () {
    testWidgets(
        'istek varsayılan olarak 15 sn sonra, zamanAsimi verilirse o süre sonra zaman aşımına uğrar',
        (t) async {
      final sunucu = _SahteSunucu();
      final varsayilan =
          _izle(FirestoreDepo('p', 'k', sunucu.istemci).yorumlar('s'));
      await t.pump(const Duration(seconds: 14));
      expect(varsayilan.bitti, isFalse, reason: '15 sn dolmadan beklenir');
      await t.pump(const Duration(seconds: 2));
      expect(varsayilan.bitti, isTrue);
      expect(varsayilan.hata, isA<TimeoutException>());

      final kisa = _izle(FirestoreDepo('p', 'k', sunucu.istemci,
              zamanAsimi: const Duration(seconds: 2))
          .yorumlar('s'));
      await t.pump(const Duration(seconds: 1));
      expect(kisa.bitti, isFalse);
      await t.pump(const Duration(seconds: 2));
      expect(kisa.bitti, isTrue);
      expect(kisa.hata, isA<TimeoutException>());
    });

    final islemler = <String, Future<Object?> Function(FirestoreDepo)>{
      'puanOzeti': (d) => d.puanOzeti('s'),
      'benimPuanim': (d) => d.benimPuanim('s'),
      'puanlar': (d) => d.puanlar(['y_a_b']),
      'puanVer': (d) => d.puanVer('s', 4),
      'yorumlar': (d) => d.yorumlar('s'),
      'yorumEkle': (d) => d.yorumEkle('s', 'Ali', 'Merhaba'),
      'yorumSil': (d) =>
          d.yorumSil(Yorum('c1', 'uid1', 'Ali', 'Merhaba', DateTime(2026))),
    };
    for (final e in islemler.entries) {
      testWidgets('${e.key}: ağ takılırsa TimeoutException fırlatır',
          (t) async {
        final sunucu = _SahteSunucu(); // oturum açılır, asıl istek takılır
        final s = _izle(e.value(FirestoreDepo('p', 'k', sunucu.istemci)));
        await t.pump(const Duration(seconds: 16));
        expect(s.bitti, isTrue, reason: '${e.key} sonsuza dek beklememeli');
        expect(s.hata, isA<TimeoutException>());
      });
    }

    testWidgets('kayıtlı oturum yenilenirken ağ takılırsa da zaman aşımı olur',
        (t) async {
      SharedPreferences.setMockInitialValues(
          {'fb_yenile': 'eski', 'fb_uid': 'uid0'});
      final sunucu = _SahteSunucu()..oturum = _takil;
      final istemci = MockClient((r) {
        sunucu.istekler.add('${r.method} ${r.url}');
        return _takil(); // securetoken isteği de dahil her şey takılır
      });
      final s = _izle(FirestoreDepo('p', 'k', istemci).kullaniciId());
      await t.pump(const Duration(seconds: 16));
      expect(s.bitti, isTrue);
      expect(s.hata, isA<TimeoutException>());
      expect(sunucu.istekler.single, contains('securetoken.googleapis.com'));
    });

    testWidgets(
        'oturum açma takılırsa eşzamanlı çağrıların hepsi zaman aşımı alır; sonraki çağrı yeniden dener',
        (t) async {
      final sunucu = _SahteSunucu()..oturum = _takil;
      final depo = FirestoreDepo('p', 'k', sunucu.istemci);
      final a = _izle(depo.kullaniciId());
      final b = _izle(depo.yorumlar('s'));
      final c = _izle(depo.puanlar(['y_a_b']));
      await t.pump(const Duration(seconds: 16));
      for (final s in [a, b, c]) {
        expect(s.bitti, isTrue);
        expect(s.hata, isA<TimeoutException>());
      }
      expect(sunucu.oturumSayisi, 1, reason: 'üç çağrı tek isteği paylaşır');

      // ağ düzeldi: takılı kalmış eski istek beklenmez, yeni istek yapılır
      sunucu.oturum = () async => _oturumYaniti(2);
      String? uid;
      depo.kullaniciId().then<void>((v) => uid = v);
      await t.pump(const Duration(seconds: 1));
      expect(uid, 'uid2');
      expect(sunucu.oturumSayisi, 2);
    });

    test(
        'oturum açma hata verirse eşzamanlı çağrılar tek istek yapar ve hepsi hata alır; sonraki çağrı yeniden dener',
        () async {
      var kayit = 0;
      final istemci = MockClient((r) async {
        if (r.url.toString().contains('accounts:signUp')) {
          final n = ++kayit;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return n == 1 ? http.Response('{}', 500) : _oturumYaniti(n);
        }
        return http.Response('[]', 200);
      });
      final depo = FirestoreDepo('p', 'k', istemci);
      final sonuclar = await Future.wait<Object?>([
        depo.kullaniciId().then<Object?>((v) => v, onError: (Object e) => e),
        depo.yorumlar('s').then<Object?>((v) => v, onError: (Object e) => e),
        depo.puanlar(['y_a_b']).then<Object?>((v) => v,
            onError: (Object e) => e),
      ]);
      expect(kayit, 1);
      expect(sonuclar.every((s) => s is Exception), isTrue);
      expect(await depo.kullaniciId(), 'uid2');
      expect(kayit, 2);
      expect(await depo.kullaniciId(), 'uid2',
          reason: 'jeton geçerli: yeni giriş yok');
      expect(kayit, 2);
    });

    test(
        'kayıtlı yenileme jetonuyla açılışta eşzamanlı çağrılar tek yenileme isteği yapar',
        () async {
      SharedPreferences.setMockInitialValues(
          {'fb_yenile': 'eski', 'fb_uid': 'uid0'});
      var yenileme = 0;
      final istemci = MockClient((r) async {
        if (r.url.toString().contains('securetoken.googleapis.com')) {
          yenileme++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(
              jsonEncode({
                'id_token': 'yeni',
                'refresh_token': 'yeniYenile',
                'user_id': 'uid0',
                'expires_in': '3600'
              }),
              200);
        }
        return http.Response('[]', 200);
      });
      final depo = FirestoreDepo('p', 'k', istemci);
      final ids = await Future.wait([
        depo.kullaniciId(),
        depo.kullaniciId(),
        depo.yorumlar('s').then((_) => 'uid0')
      ]);
      expect(ids, ['uid0', 'uid0', 'uid0']);
      expect(yenileme, 1);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('fb_yenile'), 'yeniYenile');
    });
  });

  group('Ekranlar Firestore zaman aşımını yakalar', () {
    void genis(WidgetTester t) {
      t.view.physicalSize = const Size(400, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Widget uygulama(Widget w) => MaterialApp(
        theme: TemaAyari().tema(Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: w)));

    testWidgets(
        'GeriBildirimBolumu: yükleme takılınca "Yorumlar yüklenemedi" ve Tekrar dene; puan verme de hata bildirir',
        (t) async {
      genis(t);
      final depo = FirestoreDepo('p', 'k', _SahteSunucu().istemci);
      await t.pumpWidget(uygulama(GeriBildirimBolumu(depo: depo, slot: 's')));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pump(const Duration(seconds: 16));
      await t.pump();
      expect(find.text('Yorumlar yüklenemedi.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(t.takeException(), isNull);

      // puan ver: istek takılır, zaman aşımında puan eski haline döner ve bildirim çıkar
      await t.tap(find.byTooltip('3 yıldız'));
      await t.pump();
      await t.pump(const Duration(seconds: 16));
      await t.pump();
      expect(find.text('Puan kaydedilemedi. İnternet bağlantını kontrol et.'),
          findsOneWidget);
      expect(find.text('Bu öğünü nasıl buldun?'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'GeriBildirimBolumu: yorum gönderirken ağ takılırsa hata bildirilir',
        (t) async {
      genis(t);
      final depo = FirestoreDepo('p', 'k', _SahteSunucu().istemci);
      SharedPreferences.setMockInitialValues(
          {'yorum_adi': 'Ali', 'topluluk_kurallari_surum': 1});
      await t.pumpWidget(uygulama(
          GeriBildirimBolumu(depo: depo, slot: 's', puanGoster: false)));
      await t.pump(const Duration(seconds: 16));
      await t.pump();
      await t.enterText(find.byType(TextField), 'Pilav güzeldi');
      await t.tap(find.byTooltip('Gönder'));
      await t.pump();
      await t.pump(const Duration(seconds: 16));
      await t.pump();
      expect(find.text('Yorum gönderilemedi. Daha sonra tekrar dene.'),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'OgunKarti: puan satırı "Puanla" kalır, yorumlar yüklenemedi görünür; hata sızmaz',
        (t) async {
      genis(t);
      final depo = FirestoreDepo('p', 'k', _SahteSunucu().istemci);
      await t.pumpWidget(MaterialApp(
          theme: TemaAyari().tema(Brightness.light),
          home: Scaffold(
              body: OgunKarti(
                  ogun: Ogun([YemekOgesi('Mantı', 450, null, 'manti')], 450),
                  yemekFoto: (_) => null,
                  geriBildirim: depo,
                  slot: 'ankara_2026-11-02_lunch',
                  uniId: 'ankara'))));
      await t.pump(const Duration(seconds: 16));
      await t.pump();
      expect(find.text('Puanla'), findsOneWidget);
      expect(find.text('Yorumlar yüklenemedi.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'Yemek ayrıntısı: "Puanlar yüklenemedi" ve "Yorumlar yüklenemedi" görünür; hata sızmaz',
        (t) async {
      genis(t);
      final depo = FirestoreDepo('p', 'k', _SahteSunucu().istemci);
      final yemek = YemekOgesi('Mantı', 450, null, 'manti');
      await t.pumpWidget(MaterialApp(
          theme: TemaAyari().tema(Brightness.light),
          home: YemekDetaySayfasi(
              yemek: yemek,
              uni: Universite(
                  id: 'ankara',
                  ad: 'Ankara Üniversitesi',
                  kisa: 'AÜ',
                  sehir: 'Ankara',
                  kaynak: '',
                  ogunler: const ['lunch'],
                  fiyatlar: const []),
              menu: Menu('ankara', null, {
                '2026-11-02': {
                  'lunch': Ogun([yemek], 450)
                }
              }),
              bugun: '2026-11-02',
              geriBildirim: depo)));
      await t.pump(const Duration(seconds: 16));
      await t.pump();
      expect(find.text('Puanlar yüklenemedi.'), findsOneWidget);
      expect(find.text('Yorumlar yüklenemedi.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
