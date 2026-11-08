// Bulgular 3, 4, 5: Firestore zaman aşımı + oturum yarışı, okul listesi toleransı, çevrimdışı bayrağı.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';

String _menuJson(String id) => jsonEncode({
      'university': id,
      'updated': '2026-10-31T08:00:00+03:00',
      'days': {
        '2026-11-02': {
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

Map<String, dynamic> _okul(String id, {Object? fiyatlar, Object? saatler}) => {
      'id': id,
      'name': 'Okul $id',
      'short': id,
      'city': 'Ankara',
      'source': '',
      'meals': ['lunch'],
      'prices': fiyatlar ?? [],
      'hours': saatler ?? {},
    };

void main() {
  TestWidgetsFlutterBinding
      .ensureInitialized(); // rootBundle (paket verisi) için
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bulgu 5: çevrimdışı bayrağı', () {
    test('menuler() (arama ekranı) ortak çevrimdışı bayrağını değiştirmez',
        () async {
      final istemci = MockClient((r) async =>
          r.url.path.endsWith('/ankara/menu.json')
              ? _json(_menuJson('ankara'))
              : http.Response('yok', 500)); // başka okulun isteği başarısız
      final depo = Depo(istemci: istemci);
      await depo.menu('ankara');
      expect(depo.cevrimdisi, isFalse);
      await depo.menuler(['gazi', 'hacettepe']);
      expect(depo.cevrimdisi, isFalse,
          reason:
              'ankara verisi ağdan geldi; arama sırasındaki başka hata bayrağı çevirmemeli');
    });

    test(
        'sunucu 404 verirse (okul depoda henüz yok) paket verisi kullanılır ama çevrimdışı sayılmaz',
        () async {
      final depo =
          Depo(istemci: MockClient((r) async => http.Response('yok', 404)));
      final menu = await depo.menu('ankara'); // uygulamayla gelen kopya
      expect(menu.tarihler, isNotEmpty);
      expect(depo.cevrimdisi, isFalse,
          reason: 'sunucu yanıt verdi: bağlantı var');
    });

    test(
        'sunucu 500 verirse ya da bağlantı kurulamazsa çevrimdışı sayılır (mevcut davranış korunur)',
        () async {
      final d1 =
          Depo(istemci: MockClient((r) async => http.Response('hata', 500)));
      await d1.menu('ankara');
      expect(d1.cevrimdisi, isTrue);
      final d2 = Depo(
          istemci:
              MockClient((r) async => throw http.ClientException('ağ yok')));
      await d2.menu('ankara');
      expect(d2.cevrimdisi, isTrue);
    });
  });

  group('Bulgu 4: okul listesi toleransı', () {
    test(
        'Universite.fromJson bozuk fiyat ve saat kaydını atlar, okulu düşürmez',
        () {
      final u = Universite.fromJson(_okul('x', fiyatlar: [
        {'label': 'Öğrenci öğle', 'tl': null},
        {'label': 'Öğrenci akşam', 'tl': 40},
        'çöp',
      ], saatler: {
        'lunch': {'t': '11:30–14:00'},
        'dinner': {'t': null},
        'breakfast': 5,
      }));
      expect(u.fiyatlar.map((f) => f.tl), [40]);
      expect(u.saatler.keys, ['lunch']);
    });

    test(
        'tek bozuk okul kaydı bütün listeyi düşürmez; paketteki okullar yine eklenir',
        () async {
      final liste = {
        'version': 1,
        'universities': [
          _okul('iyi1'),
          {'id': 'adsiz'}, // name yok
          5, // okul bile değil
          _okul('iyi2', fiyatlar: [
            {'label': 'Öğrenci öğle', 'tl': null}
          ]),
        ]
      };
      final depo =
          Depo(istemci: MockClient((r) async => _json(jsonEncode(liste))));
      final uniler = await depo.universiteler();
      final idler = uniler.map((u) => u.id).toSet();
      expect(idler, containsAll(['iyi1', 'iyi2', 'ankara']));
      expect(idler, isNot(contains('adsiz')));
    });

    test(
        'uzaktaki liste beklenmedik biçimdeyse uygulamayla gelen listeye düşülür',
        () async {
      final depo = Depo(
          istemci:
              MockClient((r) async => _json(jsonEncode({'universities': 5}))));
      final uniler = await depo.universiteler();
      expect(uniler.map((u) => u.id), contains('ankara'));
    });
  });

  group('Bulgu 3: Firestore', () {
    // testWidgets sahte saatle çalışır: pump(süre) Future.timeout zamanlayıcısını da ilerletir
    testWidgets(
        'ağ takılırsa istek zaman aşımıyla hata verir (sonsuza dek beklemez)',
        (t) async {
      final kapi = Completer<http.Response>();
      final depo = FirestoreDepo('p', 'k', MockClient((r) => kapi.future));
      Object? hata;
      var bitti = false;
      // then<void>: tür belirtilmezse çıkarım bool olur ve onError null döndürdüğü için Dart ArgumentError atar
      depo.puanlar(['y_a_b']).then<void>((_) => bitti = true,
          onError: (Object e) {
        bitti = true;
        hata = e;
      });
      await t.pump(const Duration(minutes: 5));
      expect(bitti, isTrue, reason: 'zaman aşımı olmalı');
      expect(hata, isA<TimeoutException>());
    });

    test(
        'ilk açılışta eşzamanlı çağrılar tek anonim hesap açar ve aynı kullanıcı kimliğini görür',
        () async {
      var kayit = 0;
      final istemci = MockClient((r) async {
        final yol = r.url.toString();
        if (yol.contains('accounts:signUp')) {
          final n = ++kayit;
          await Future<void>.delayed(Duration(milliseconds: 10 * (4 - n)));
          return http.Response(
              jsonEncode({
                'idToken': 'tok$n',
                'refreshToken': 'ref$n',
                'localId': 'uid$n',
                'expiresIn': '3600'
              }),
              200);
        }
        if (yol.contains(':runQuery')) return http.Response('[]', 200);
        return http.Response('{}', 404);
      });
      final depo = FirestoreDepo('p', 'k', istemci);
      final sonuc = await Future.wait<Object?>([
        depo.puanlar(['y_a_b']),
        depo.yorumlar('s'),
        depo.kullaniciId()
      ]);
      expect(kayit, 1,
          reason: 'üç eşzamanlı çağrı tek oturum açmayı paylaşmalı');
      expect(sonuc[2], await depo.kullaniciId());
    });
  });
}
