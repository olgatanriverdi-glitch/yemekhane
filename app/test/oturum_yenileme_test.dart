// P4 ek testleri: Firebase oturum yenilemesi. Yenileme jetonu yalnızca KALICI reddedilirse (400/401/403) yeni anonim
// hesap açılır; geçici hatada (5xx, 429, ağ) kullanıcının kimliği değişmez, hata fırlatılır ve sonraki çağrı yeniden
// dener. Kimlik değişirse kullanıcının kendi yorumundaki "Sil" kaybolur ve puanı sıfırlanır.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';

/// Sahte Firebase: yenileme ([yenileme]) ve anonim kayıt ([kayit]) ayrı ayrı yanıtlanır; her istek sayılır.
class _Sunucu {
  /// Yenileme isteğine verilecek yanıt; varsayılan: başarı (eski kullanıcı, yeni jeton).
  Future<http.Response> Function() yenileme = () async => _yenilemeBasarili();

  /// Anonim kayıt yanıtı; her çağrıda yeni bir hesap açar (uidYeni1, uidYeni2...).
  int kayitSayisi = 0;
  int yenilemeSayisi = 0;
  final List<String> yenilemeGovdeleri = [];

  late final MockClient istemci = MockClient((r) async {
    final adres = r.url.toString();
    if (adres.contains('securetoken.googleapis.com')) {
      yenilemeSayisi++;
      yenilemeGovdeleri.add(r.body);
      return yenileme();
    }
    if (adres.contains('accounts:signUp')) {
      final n = ++kayitSayisi;
      return http.Response(
          jsonEncode({
            'idToken': 'tokYeni$n',
            'refreshToken': 'yenileYeni$n',
            'localId': 'uidYeni$n',
            'expiresIn': '3600'
          }),
          200);
    }
    return http.Response('[]', 200); // Firestore sorguları: boş sonuç
  });
}

http.Response _yenilemeBasarili({String uid = 'uidEski'}) => http.Response(
    jsonEncode({
      'id_token': 'tokYenilendi',
      'refresh_token': 'yenileYenilendi',
      'user_id': uid,
      'expires_in': '3600'
    }),
    200);

String _hata(String mesaj, int kod) => jsonEncode({
      'error': {'code': kod, 'message': mesaj}
    });

/// Cihazda kayıtlı eski bir oturum var.
void _kayitliOturum() => SharedPreferences.setMockInitialValues(
    {'fb_yenile': 'eskiYenile', 'fb_uid': 'uidEski', 'yorum_adi': 'Ali'});

Future<void> _kayitliKimlik(String yenile, String uid) async {
  final p = await SharedPreferences.getInstance();
  expect(p.getString('fb_yenile'), yenile);
  expect(p.getString('fb_uid'), uid);
}

void main() {
  setUp(_kayitliOturum);

  group('geçici hata: kimlik değişmez', () {
    for (final kod in [500, 502, 503, 504, 429, 408]) {
      test(
          'yenileme $kod verirse yeni hesap açılmaz, hata fırlar; sunucu düzelince aynı kimlik sürer',
          () async {
        final sunucu = _Sunucu()
          ..yenileme = () async => http.Response('{}', kod);
        final depo = FirestoreDepo('p', 'k', sunucu.istemci);

        await expectLater(depo.kullaniciId(), throwsA(isA<Exception>()));
        expect(sunucu.kayitSayisi, 0,
            reason: 'geçici hata yeni anonim hesap açtırmamalı');
        expect(sunucu.yenilemeSayisi, 1);
        await _kayitliKimlik('eskiYenile', 'uidEski');

        // sunucu düzeldi: tek uçuş sıfırlanmıştır, yeniden denenir ve aynı kullanıcı döner
        sunucu.yenileme = () async => _yenilemeBasarili();
        expect(await depo.kullaniciId(), 'uidEski');
        expect(sunucu.kayitSayisi, 0);
        expect(sunucu.yenilemeSayisi, 2);
        expect(sunucu.yenilemeGovdeleri.last, contains('eskiYenile'));
        await _kayitliKimlik('yenileYenilendi', 'uidEski');
      });
    }

    test('ağ hatası (bağlantı kopması) da yeni hesap açtırmaz', () async {
      final sunucu = _Sunucu()
        ..yenileme = () async => throw http.ClientException('ağ yok');
      final depo = FirestoreDepo('p', 'k', sunucu.istemci);
      await expectLater(depo.kullaniciId(), throwsA(isA<Exception>()));
      expect(sunucu.kayitSayisi, 0);
      await _kayitliKimlik('eskiYenile', 'uidEski');
    });

    test(
        'yenileme 200 döner ama gövde bozuksa (ör. giriş sayfası) yeni hesap açılmaz',
        () async {
      final sunucu = _Sunucu()
        ..yenileme = () async => http.Response('<html>giriş yapın</html>', 200);
      final depo = FirestoreDepo('p', 'k', sunucu.istemci);
      await expectLater(depo.kullaniciId(), throwsA(anything));
      expect(sunucu.kayitSayisi, 0);
      await _kayitliKimlik('eskiYenile', 'uidEski');
    });

    test(
        'eşzamanlı çağrılar tek yenileme isteğini paylaşır, hepsi hata alır, yeni hesap açılmaz',
        () async {
      final sunucu = _Sunucu()..yenileme = () async => http.Response('{}', 503);
      final depo = FirestoreDepo('p', 'k', sunucu.istemci);
      final sonuclar = await Future.wait<Object?>([
        depo.kullaniciId().then<Object?>((v) => v, onError: (Object e) => e),
        depo.yorumlar('s').then<Object?>((v) => v, onError: (Object e) => e),
        depo.puanlar(['y_a_b']).then<Object?>((v) => v,
            onError: (Object e) => e),
      ]);
      expect(sonuclar.every((s) => s is Exception), isTrue);
      expect(sunucu.yenilemeSayisi, 1);
      expect(sunucu.kayitSayisi, 0);
      await _kayitliKimlik('eskiYenile', 'uidEski');
    });

    test(
        'sonraki çağrı yenilemeyi yeniden dener; art arda hata hesabı değiştirmez',
        () async {
      final sunucu = _Sunucu()..yenileme = () async => http.Response('{}', 503);
      final depo = FirestoreDepo('p', 'k', sunucu.istemci);
      for (var i = 0; i < 3; i++) {
        await expectLater(depo.kullaniciId(), throwsA(isA<Exception>()));
      }
      expect(sunucu.yenilemeSayisi, 3);
      expect(sunucu.kayitSayisi, 0);
      await _kayitliKimlik('eskiYenile', 'uidEski');
    });
  });

  group('kalıcı ret: yeni anonim hesap açılır', () {
    final reddedilenler = <String, (int, String)>{
      '400 INVALID_REFRESH_TOKEN': (400, _hata('INVALID_REFRESH_TOKEN', 400)),
      '400 TOKEN_EXPIRED': (400, _hata('TOKEN_EXPIRED', 400)),
      '400 USER_NOT_FOUND': (400, _hata('USER_NOT_FOUND', 400)),
      '400 USER_DISABLED': (400, _hata('USER_DISABLED', 400)),
      '400 gövdesiz': (400, ''),
      '401': (401, _hata('UNAUTHENTICATED', 401)),
      '403': (403, _hata('PERMISSION_DENIED', 403)),
    };
    for (final e in reddedilenler.entries) {
      test('${e.key}: yeni hesap açılır, kimlik ve jeton kaydedilir', () async {
        final (kod, govde) = e.value;
        final sunucu = _Sunucu()
          ..yenileme = () async => http.Response(govde, kod);
        final depo = FirestoreDepo('p', 'k', sunucu.istemci);

        expect(await depo.kullaniciId(), 'uidYeni1');
        expect(sunucu.yenilemeSayisi, 1);
        expect(sunucu.kayitSayisi, 1);
        await _kayitliKimlik('yenileYeni1', 'uidYeni1');

        // jeton geçerli: yeniden yenileme ya da kayıt yok
        expect(await depo.kullaniciId(), 'uidYeni1');
        expect(sunucu.yenilemeSayisi, 1);
        expect(sunucu.kayitSayisi, 1);
      });
    }

    test(
        'eşzamanlı çağrılar kalıcı retten sonra tek hesap açar ve aynı kimliği görür',
        () async {
      final sunucu = _Sunucu()
        ..yenileme =
            () async => http.Response(_hata('TOKEN_EXPIRED', 400), 400);
      final depo = FirestoreDepo('p', 'k', sunucu.istemci);
      final ids = await Future.wait([
        depo.kullaniciId(),
        depo.kullaniciId(),
        depo.yorumlar('s').then((_) => 'uidYeni1'),
      ]);
      expect(ids, ['uidYeni1', 'uidYeni1', 'uidYeni1']);
      expect(sunucu.kayitSayisi, 1);
      expect(sunucu.yenilemeSayisi, 1);
    });

    test(
        'kayıtlı oturum yokken doğrudan yeni hesap açılır (yenileme isteği yok)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final sunucu = _Sunucu();
      final depo = FirestoreDepo('p', 'k', sunucu.istemci);
      expect(await depo.kullaniciId(), 'uidYeni1');
      expect(sunucu.yenilemeSayisi, 0);
      expect(sunucu.kayitSayisi, 1);
    });

    test('kalıcı retten sonra anonim kayıt da geçici hata verirse hata fırlar',
        () async {
      final istemci = MockClient((r) async =>
          r.url.toString().contains('accounts:signUp')
              ? http.Response('{}', 503)
              : http.Response(_hata('USER_NOT_FOUND', 400), 400));
      final depo = FirestoreDepo('p', 'k', istemci);
      await expectLater(depo.kullaniciId(), throwsA(isA<Exception>()));
      await _kayitliKimlik(
          'eskiYenile', 'uidEski'); // hesap açılamadı: kayıt değişmedi
    });
  });

  group('ekranda görünen sonuç', () {
    Widget sayfa(GeriBildirimDeposu depo) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GeriBildirimBolumu(
                    depo: depo, slot: 's1', puanGoster: false))));

    /// Kendi yorumunu ('uidEski') ve başkasının yorumunu döndüren Firestore yanıtı.
    String yorumlarYaniti() => jsonEncode([
          for (final (id, uid, ad) in [
            ('C1', 'uidEski', 'Ali'),
            ('C2', 'baskasi', 'Ayse')
          ])
            {
              'document': {
                'name': 'projects/p/databases/(default)/documents/comments/$id',
                'fields': {
                  'uid': {'stringValue': uid},
                  'name': {'stringValue': ad},
                  'text': {'stringValue': 'Yorum $ad'},
                  'createdAt': {'timestampValue': '2026-10-02T10:00:00Z'}
                }
              }
            }
        ]);

    testWidgets(
        'sunucu geçici hata verip düzelince kullanıcı kendi yorumunun "Sil" düğmesini görür (kimlik değişmedi)',
        (t) async {
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var yenilemeSaglam = false;
      var kayit = 0;
      final istemci = MockClient((r) async {
        final adres = r.url.toString();
        if (adres.contains('securetoken.googleapis.com')) {
          return yenilemeSaglam
              ? _yenilemeBasarili()
              : http.Response('{}', 503);
        }
        if (adres.contains('accounts:signUp')) {
          kayit++;
          return http.Response(
              jsonEncode({
                'idToken': 'tokYeni',
                'refreshToken': 'yenileYeni',
                'localId': 'uidYeni',
                'expiresIn': '3600'
              }),
              200);
        }
        return http.Response(yorumlarYaniti(), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final depo = FirestoreDepo('p', 'k', istemci);
      await t.pumpWidget(sayfa(depo));
      await t.pumpAndSettle();
      expect(find.text('Yorumlar yüklenemedi.'), findsOneWidget);
      expect(kayit, 0, reason: 'geçici hata yeni kimlik üretmemeli');

      yenilemeSaglam = true;
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(find.text('Yorum Ali'), findsOneWidget);
      expect(find.text('Yorum Ayse'), findsOneWidget);
      expect(find.byTooltip('Sil'), findsOneWidget,
          reason: 'yalnızca kullanıcının kendi yorumunda "Sil" görünür');
      expect(kayit, 0);
      expect(t.takeException(), isNull);
    });
  });
}
