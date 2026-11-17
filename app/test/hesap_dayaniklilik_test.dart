// Parça F-b: hesap silmede limits/<uid> kaydı ve devre dışı (USER_DISABLED) hesapta yeni kimlik açılmaması.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';

class _Sunucu {
  final istekler = <String>[];
  final beklemeler = <Duration>[];
  int limitsKodu = 200;
  int limitsRedSayisi = 0; // ilk N DELETE reddedilir (403), sonra limitsKodu
  int limitsDenemesi = 0;
  bool yorumVar = true;
  int yenilemeKodu = 200;
  String yenilemeGovdesi = '';

  late final MockClient istemci = MockClient((r) async {
    final u = r.url.toString();
    istekler.add('${r.method} ${r.url.path}');
    if (u.contains('securetoken')) {
      if (yenilemeKodu != 200) {
        return http.Response(yenilemeGovdesi, yenilemeKodu);
      }
      return http.Response(
          jsonEncode({
            'id_token': 'T2',
            'refresh_token': 'R2',
            'user_id': 'U1',
            'expires_in': '3600'
          }),
          200);
    }
    if (u.contains('accounts:signUp')) {
      return http.Response(
          jsonEncode({
            'idToken': 'T9',
            'refreshToken': 'R9',
            'localId': 'U9',
            'expiresIn': '3600'
          }),
          200);
    }
    if (u.contains('accounts:delete')) return http.Response('{}', 200);
    if (u.contains(':runQuery')) {
      final k = ((jsonDecode(r.body)['structuredQuery']['from'] as List).first
          as Map)['collectionId'];
      final var_ = k == 'comments' && yorumVar;
      yorumVar = k == 'comments' ? false : yorumVar; // ikinci sayfa boş
      return http.Response(
          jsonEncode(var_
              ? [
                  {
                    'document': {
                      'name':
                          'projects/p/databases/(default)/documents/comments/d0'
                    }
                  }
                ]
              : [
                  {'readTime': 'x'}
                ]),
          200);
    }
    if (u.contains(':commit')) return http.Response('{}', 200);
    if (r.method == 'DELETE' && u.contains('/limits/')) {
      limitsDenemesi++;
      if (limitsDenemesi <= limitsRedSayisi) {
        return http.Response('{"error":{"status":"PERMISSION_DENIED"}}', 403);
      }
      return http.Response('{}', limitsKodu);
    }
    return http.Response('{}', 200);
  });

  FirestoreDepo depo() =>
      FirestoreDepo('p', 'K', istemci, bekle: (d) async => beklemeler.add(d));

  int sayi(String parca) => istekler.where((i) => i.contains(parca)).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(
      {'fb_yenile': 'R0', 'fb_uid': 'U1'}));

  group('limits/<uid> silme', () {
    test(
        '403 ise 20 sn dolana kadar bekleyip yeniden dener, sonra hesabı siler',
        () async {
      final s = _Sunucu()..limitsRedSayisi = 2;
      await s.depo().verilerimiSil();
      expect(s.limitsDenemesi, 3);
      expect(s.beklemeler, hasLength(2));
      expect(s.sayi('accounts:delete'), 1);
      expect((await SharedPreferences.getInstance()).getString('fb_yenile'),
          isNull);
    });

    test('hiç dolmazsa en çok ~22 sn beklenir, hata fırlar, hesap silinmez',
        () async {
      final s = _Sunucu()..limitsRedSayisi = 99;
      await expectLater(s.depo().verilerimiSil(), throwsException);
      final toplam = s.beklemeler.fold(Duration.zero, (a, b) => a + b);
      expect(toplam, const Duration(seconds: 22));
      expect(s.sayi('accounts:delete'), 0);
      expect((await SharedPreferences.getInstance()).getString('fb_yenile'),
          isNotNull,
          reason: 'yeniden denenebilsin');
    });

    test('404 (kayıt yok) başarıdır', () async {
      final s = _Sunucu()..limitsKodu = 404;
      await s.depo().verilerimiSil();
      expect(s.beklemeler, isEmpty);
      expect(s.sayi('accounts:delete'), 1);
    });

    test('beklenmedik hata (500) fırlatılır, hesap silinmez', () async {
      final s = _Sunucu()..limitsKodu = 500;
      await expectLater(s.depo().verilerimiSil(), throwsException);
      expect(s.sayi('accounts:delete'), 0);
    });

    test('hiç yorum yoksa 403 "kayıt yok" sayılır, beklenmez', () async {
      final s = _Sunucu()
        ..yorumVar = false
        ..limitsRedSayisi = 99;
      await s.depo().verilerimiSil();
      expect(s.beklemeler, isEmpty);
      expect(s.sayi('accounts:delete'), 1);
    });
  });

  group('USER_DISABLED', () {
    Future<void> hata(_Sunucu s, String kod) async {
      s.yenilemeKodu = 400;
      s.yenilemeGovdesi = jsonEncode({
        'error': {'code': 400, 'message': kod}
      });
    }

    test('yeni anonim hesap açılmaz, yazma devre dışı hatasıyla durur',
        () async {
      final s = _Sunucu();
      await hata(s, 'USER_DISABLED');
      final d = s.depo();
      await expectLater(
          d.puanVer('s', 4), throwsA(isA<HesapDevreDisiHatasi>()));
      await expectLater(
          d.yorumEkle('s', 'A', 'M'), throwsA(isA<HesapDevreDisiHatasi>()));
      expect(s.sayi('accounts:signUp'), 0);
      expect(
          (await SharedPreferences.getInstance()).getString('fb_yenile'), 'R0',
          reason: 'hesap yeniden açılırsa aynı kimlik sürer');
    });

    test('ek metinli kod (USER_DISABLED : ayrıntı) de tanınır', () async {
      final s = _Sunucu();
      await hata(s, 'USER_DISABLED : The user account has been disabled');
      await expectLater(
          s.depo().kullaniciId(), throwsA(isA<HesapDevreDisiHatasi>()));
      expect(s.sayi('accounts:signUp'), 0);
    });

    for (final kod in [
      'TOKEN_EXPIRED',
      'USER_NOT_FOUND',
      'INVALID_REFRESH_TOKEN'
    ]) {
      test('$kod: bugünkü davranış, yeni anonim hesap açılır', () async {
        final s = _Sunucu();
        await hata(s, kod);
        expect(await s.depo().kullaniciId(), 'U9');
        expect(s.sayi('accounts:signUp'), 1);
      });
    }

    test('gövde JSON değilse yeni hesap açılır (kalıcı ret)', () async {
      final s = _Sunucu()
        ..yenilemeKodu = 400
        ..yenilemeGovdesi = 'bozuk';
      expect(await s.depo().kullaniciId(), 'U9');
    });

    test('hataMesaji: devre dışı ise özel metin, değilse yedek', () {
      expect(hataMesaji(const HesapDevreDisiHatasi(), 'x'),
          'Hesabın devre dışı bırakıldı');
      expect(hataMesaji(Exception('a'), 'x'), 'x');
    });
  });
}
