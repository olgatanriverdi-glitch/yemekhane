// "Yorum ve puanlarımı sil" (Google Play veri silme gereksinimi), yorum bildirimi (Firestore), Ayarlar satırları
// (Engellenen kişiler, Gizlilik politikası) ve firestore.rules'taki reports kuralı.
import 'dart:convert';
import 'dart:io';

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
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/yorum_moderasyon.dart';

// --- sahte Firebase sunucusu ----------------------------------------------------------------------------------------

String _belgeAdi(String koleksiyon, int n) =>
    'projects/p/databases/(default)/documents/$koleksiyon/d$n';

/// Oturum, sorgu, toplu silme ve hesap silme isteklerini taklit eder. [belgeler]: koleksiyon -> kalan belge sayısı;
/// `commit` bu sayıdan silinen kadarını düşer.
class _Sunucu {
  final istekler = <String>[];
  final commitGovdeleri = <Map<String, dynamic>>[];
  final raporlar = <Map<String, dynamic>>[];
  final belgeler = <String, int>{'comments': 0, 'ratings': 0, 'reports': 0};
  int commitKodu = 200;
  int hesapSilmeKodu = 200;
  String hesapSilmeGovdesi = '{}';
  String? hesapSilmeToken;
  int raporKodu = 200;

  late final MockClient istemci = MockClient((r) async {
    final u = r.url.toString();
    istekler.add('${r.method} ${r.url.path}');
    if (u.contains('accounts:signUp')) {
      return http.Response(
          jsonEncode({
            'idToken': 'T1',
            'refreshToken': 'R1',
            'localId': 'U1',
            'expiresIn': '3600'
          }),
          200);
    }
    if (u.contains('securetoken')) {
      return http.Response(
          jsonEncode({
            'id_token': 'T2',
            'refresh_token': 'R2',
            'user_id': 'U1',
            'expires_in': '3600'
          }),
          200);
    }
    if (u.contains('accounts:delete')) {
      hesapSilmeToken = (jsonDecode(r.body) as Map)['idToken'] as String?;
      return http.Response(hesapSilmeGovdesi, hesapSilmeKodu);
    }
    if (u.contains(':runQuery')) {
      final sorgu = (jsonDecode(r.body) as Map)['structuredQuery'] as Map;
      final koleksiyon =
          ((sorgu['from'] as List).first as Map)['collectionId'] as String;
      final filtre = (sorgu['where'] as Map)['fieldFilter'] as Map;
      expect(filtre['field'], {'fieldPath': 'uid'});
      expect(filtre['value'], {'stringValue': 'U1'});
      final limit = sorgu['limit'] as int;
      final n = belgeler[koleksiyon]!;
      final donen = n < limit ? n : limit;
      return http.Response(
          jsonEncode(donen == 0
              ? [
                  {'readTime': 'x'}
                ]
              : [
                  for (var i = 0; i < donen; i++)
                    {
                      'document': {'name': _belgeAdi(koleksiyon, i)}
                    }
                ]),
          200);
    }
    if (u.contains(':commit')) {
      final govde = jsonDecode(r.body) as Map<String, dynamic>;
      final writes = govde['writes'] as List;
      if ((writes.first as Map).containsKey('update')) {
        // şikâyet yazımı (sunucu zamanlı commit): silme sayaçlarına karışmaz
        raporlar.add((writes.first as Map)['update'] as Map<String, dynamic>);
        return http.Response('{}', raporKodu);
      }
      commitGovdeleri.add(govde);
      if (commitKodu != 200) return http.Response('{}', commitKodu);
      final ad = (writes.first as Map)['delete'] as String;
      final koleksiyon = ad.split('/').reversed.elementAt(1);
      belgeler[koleksiyon] = belgeler[koleksiyon]! - writes.length;
      return http.Response('{}', 200);
    }
    if (u.contains('/reports')) {
      raporlar.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response('{}', raporKodu);
    }
    return http.Response('{}', 200);
  });

  int sayi(String parca) => istekler.where((i) => i.contains(parca)).length;
}

Future<FirestoreDepo> _girisYapmis(_Sunucu s) async {
  final depo = FirestoreDepo('p', 'K', s.istemci);
  await depo.kullaniciId(); // anonim hesap açılır, prefs'e yazılır
  s.istekler.clear();
  return depo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FirestoreDepo.verilerimiSil', () {
    test('yorum ve puanlar silinir, hesap kapatılır, yerel oturum temizlenir',
        () async {
      SharedPreferences.setMockInitialValues({'yorum_adi': 'Ali'});
      final s = _Sunucu()
        ..belgeler['comments'] = 3
        ..belgeler['ratings'] = 2;
      final depo = await _girisYapmis(s);
      await depo.verilerimiSil();

      expect(s.belgeler, {'comments': 0, 'ratings': 0, 'reports': 0});
      expect(s.commitGovdeleri, hasLength(2));
      expect(
          (s.commitGovdeleri[0]['writes'] as List)
              .map((w) => (w as Map)['delete']),
          [for (var i = 0; i < 3; i++) _belgeAdi('comments', i)]);
      expect(s.sayi('accounts:delete'), 1);
      expect(s.hesapSilmeToken, 'T1');
      final p = await SharedPreferences.getInstance();
      expect(p.getString('fb_yenile'), isNull);
      expect(p.getString('fb_uid'), isNull);
      expect(p.getString('yorum_adi'), isNull);
    });

    test('sorgular yalnızca kullanıcının kendi uid belgelerini ister',
        () async {
      // _Sunucu içindeki expect'ler uid == U1 filtresini doğrular; burada sorgu sayısı da denetlenir
      final s = _Sunucu()..belgeler['comments'] = 1;
      final depo = await _girisYapmis(s);
      await depo.verilerimiSil();
      expect(s.sayi(':runQuery'), 3); // comments + ratings + reports
    });

    test('100\'den fazla belge sayfa sayfa silinir', () async {
      final s = _Sunucu()
        ..belgeler['comments'] = 250
        ..belgeler['ratings'] = 100;
      final depo = await _girisYapmis(s);
      await depo.verilerimiSil();
      expect(s.belgeler, {'comments': 0, 'ratings': 0, 'reports': 0});
      // yorumlar: 100 + 100 + 50; puanlar: 100 (tam sayfa) + boş sorgu
      expect(s.commitGovdeleri.map((g) => (g['writes'] as List).length),
          [100, 100, 50, 100]);
      expect(s.sayi('accounts:delete'), 1);
    });

    test('silme hatasında hata fırlatılır, oturum korunur, hesap kapatılmaz',
        () async {
      final s = _Sunucu()
        ..belgeler['comments'] = 2
        ..commitKodu = 403;
      final depo = await _girisYapmis(s);
      await expectLater(depo.verilerimiSil(), throwsException);
      expect(s.sayi('accounts:delete'), 0);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('fb_yenile'), 'R1',
          reason: 'yeniden denenebilsin: aynı kimlik korunur');
      expect(p.getString('fb_uid'), 'U1');
    });

    test('hesap silinemezse hata fırlatılır ve oturum korunur', () async {
      final s = _Sunucu()..hesapSilmeKodu = 500;
      final depo = await _girisYapmis(s);
      await expectLater(depo.verilerimiSil(), throwsException);
      expect(
          (await SharedPreferences.getInstance()).getString('fb_yenile'), 'R1');
    });

    test('hesap zaten yoksa (USER_NOT_FOUND) işlem başarılı sayılır', () async {
      final s = _Sunucu()
        ..hesapSilmeKodu = 400
        ..hesapSilmeGovdesi = '{"error":{"message":"USER_NOT_FOUND"}}';
      final depo = await _girisYapmis(s);
      await depo.verilerimiSil();
      expect((await SharedPreferences.getInstance()).getString('fb_yenile'),
          isNull);
    });

    test('hiç oturum açılmamışsa ağa gidilmez, yalnızca yerel kayıt temizlenir',
        () async {
      SharedPreferences.setMockInitialValues({'yorum_adi': 'Ali'});
      final s = _Sunucu();
      final depo = FirestoreDepo('p', 'K', s.istemci);
      await depo.verilerimiSil();
      expect(s.istekler, isEmpty);
      expect((await SharedPreferences.getInstance()).getString('yorum_adi'),
          isNull);
    });

    test('silindikten sonra yeni kullanım yeni anonim hesap açar', () async {
      final s = _Sunucu();
      final depo = await _girisYapmis(s);
      await depo.verilerimiSil();
      s.istekler.clear();
      await depo.kullaniciId();
      expect(s.sayi('accounts:signUp'), 1);
    });
  });

  group('FirestoreDepo.yorumBildir', () {
    test('reports koleksiyonuna geçerli alanlarla yazar', () async {
      final s = _Sunucu();
      final depo = await _girisYapmis(s);
      final y = Yorum('abc123', 'baska', 'Ayşe', 'Metin', DateTime(2026, 11, 2),
          slot: 'y_ankara_manti');
      await depo.yorumBildir(y, YorumBildirimNedeni.hakaret);
      expect(s.raporlar, hasLength(1));
      final f = s.raporlar.single['fields'] as Map;
      // createdAt istemci saatiyle değil sunucu zamanıyla (REQUEST_TIME dönüşümü) yazılır
      expect(f.keys.toSet(),
          {'uid', 'commentId', 'slot', 'reason', 'targetUid', 'targetText'});
      expect(f['targetUid'], {'stringValue': 'baska'});
      expect(f['targetText'], {'stringValue': 'Metin'});
      expect(s.raporlar.single['name'], endsWith('/reports/U1_abc123'));
      expect(f['uid'], {'stringValue': 'U1'});
      expect(f['commentId'], {'stringValue': 'abc123'});
      expect(f['slot'], {'stringValue': 'y_ankara_manti'});
      expect(f['reason'], {'stringValue': 'hakaret'});
    });

    test('kurallar reddederse (403) hata fırlatır', () async {
      final s = _Sunucu()..raporKodu = 403;
      final depo = await _girisYapmis(s);
      final y = Yorum('c', 'u', 'A', 'M', DateTime(2026, 11, 2));
      await expectLater(
          depo.yorumBildir(y, YorumBildirimNedeni.spam), throwsException);
    });

    test('yorumlar() slotu Yorum nesnesine koyar', () async {
      final istemci = MockClient((r) async {
        final u = r.url.toString();
        if (u.contains('accounts:signUp')) {
          return http.Response(
              jsonEncode({
                'idToken': 'T',
                'refreshToken': 'R',
                'localId': 'U1',
                'expiresIn': '3600'
              }),
              200);
        }
        return http.Response(
            jsonEncode([
              {
                'document': {
                  'name': 'x/comments/c1',
                  'fields': {
                    'uid': {'stringValue': 'U2'},
                    'slot': {'stringValue': 's9'},
                    'name': {'stringValue': 'Ayse'},
                    'text': {'stringValue': 'Merhaba'},
                    'createdAt': {'timestampValue': '2026-11-02T10:00:00Z'},
                  }
                }
              }
            ]),
            200);
      });
      final l = await FirestoreDepo('p', 'K', istemci).yorumlar('s9');
      expect(l.single.slot, 's9');
      expect(l.single.id, 'c1');
    });
  });

  group('YerelDepo ve önbellek', () {
    test('YerelDepo.verilerimiSil yerel puan, yorum, kimlik ve adı siler',
        () async {
      SharedPreferences.setMockInitialValues({'yorum_adi': 'Ali', 'tema': 'x'});
      final d = YerelDepo();
      await d.puanVer('s', 4);
      await d.yorumEkle('s', 'Ali', 'Merhaba');
      await d.kullaniciId();
      await d.verilerimiSil();
      final p = await SharedPreferences.getInstance();
      expect(p.getKeys(), {'tema'}); // başka ayarlara dokunulmaz
      expect(await d.benimPuanim('s'), isNull);
      expect(await d.yorumlar('s'), isEmpty);
    });

    test('OnbellekliGeriBildirim: bildirimi iletir, silmede önbelleği boşaltır',
        () async {
      final ic = _SayacDepo();
      final depo = OnbellekliGeriBildirim(ic);
      await depo.yorumlar('s');
      await depo.yorumlar('s');
      expect(ic.yorumlarCagri, 1); // ikincisi önbellekten

      final y = Yorum('c', 'u', 'A', 'M', DateTime(2026, 11, 2));
      await depo.yorumBildir(y, YorumBildirimNedeni.diger);
      expect(ic.bildirilen, [YorumBildirimNedeni.diger]);
      await depo.yorumlar('s');
      expect(ic.yorumlarCagri, 1, reason: 'bildirim önbelleği bozmaz');

      await depo.verilerimiSil();
      expect(ic.silindi, 1);
      await depo.yorumlar('s');
      expect(ic.yorumlarCagri, 2);
    });

    test('silme hata verse de önbellek boşaltılır ve hata iletilir', () async {
      final ic = _SayacDepo()..silmeHatasi = true;
      final depo = OnbellekliGeriBildirim(ic);
      await depo.yorumlar('s');
      await expectLater(depo.verilerimiSil(), throwsException);
      await depo.yorumlar('s');
      expect(ic.yorumlarCagri, 2);
    });
  });

  group('Ayarlar', () {
    final uni = Universite(
        id: 'ankara',
        ad: 'Ankara Üniversitesi',
        kisa: 'AÜ',
        sehir: 'Ankara',
        kaynak: 'https://ankara.example/menu',
        ogunler: const ['lunch'],
        fiyatlar: const []);

    Future<void> ac(WidgetTester t,
        {GeriBildirimDeposu? gb, Future<void> Function()? yenile}) async {
      final ayar = TemaAyari();
      await t.pumpWidget(MaterialApp(
          theme: ayar.tema(Brightness.light),
          home: AyarlarSayfasi(
              temaAyari: ayar,
              depo: Depo(),
              uniler: [uni],
              uni: uni,
              geriBildirim: gb,
              menuyuYenile: yenile ?? () async {})));
      await t.pumpAndSettle();
    }

    Future<void> kaydir(WidgetTester t, String metin) async {
      await t.scrollUntilVisible(find.text(metin), 200,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
    }

    testWidgets('"Yorum ve puanlarımı sil": onay, silme, bilgi, menü yenileme',
        (t) async {
      final gb = _SayacDepo();
      var yenilendi = 0;
      await ac(t, gb: gb, yenile: () async => yenilendi++);
      await kaydir(t, 'Yorum ve puanlarımı sil');
      await t.tap(find.text('Yorum ve puanlarımı sil'));
      await t.pumpAndSettle();
      expect(find.text('Yorum ve puanların silinsin mi?'), findsOneWidget);
      expect(gb.silindi, 0, reason: 'onaydan önce silinmez');
      await t.tap(find.text('Sil'));
      await t.pumpAndSettle();
      expect(gb.silindi, 1);
      expect(find.text('Yorum ve puanların silindi'), findsOneWidget);
      expect(yenilendi, 1);
    });

    testWidgets('onay penceresinde Vazgeç hiçbir şey silmez', (t) async {
      final gb = _SayacDepo();
      await ac(t, gb: gb);
      await kaydir(t, 'Yorum ve puanlarımı sil');
      await t.tap(find.text('Yorum ve puanlarımı sil'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(gb.silindi, 0);
    });

    testWidgets('hata olursa açık hata metni gösterilir ve menü yenilenmez',
        (t) async {
      final gb = _SayacDepo()..silmeHatasi = true;
      var yenilendi = 0;
      await ac(t, gb: gb, yenile: () async => yenilendi++);
      await kaydir(t, 'Yorum ve puanlarımı sil');
      await t.tap(find.text('Yorum ve puanlarımı sil'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sil'));
      await t.pumpAndSettle();
      expect(
          find.text(
              'Veriler silinemedi. İnternet bağlantını kontrol edip tekrar dene.'),
          findsOneWidget);
      expect(yenilendi, 0);
      expect(find.text('Yorum ve puanların silindi'), findsNothing);
    });

    testWidgets('geri bildirim deposu verilmezse silme satırı yoktur',
        (t) async {
      await ac(t);
      await t.scrollUntilVisible(find.text('Açık kaynak lisansları'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Yorum ve puanlarımı sil'), findsNothing);
    });

    testWidgets('"Gizlilik politikası" adresi panoya kopyalar', (t) async {
      final pano = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'Clipboard.setData') {
          pano.add((c.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await ac(t);
      await kaydir(t, 'Gizlilik politikası');
      await t.tap(find.text('Gizlilik politikası'));
      await t.pumpAndSettle();
      expect(pano,
          ['https://olgatanriverdi-glitch.github.io/yemekhane/gizlilik.html']);
      expect(gizlilikAdresi, pano.single);
      expect(find.text('Bağlantı panoya kopyalandı'), findsOneWidget);
    });

    testWidgets('"Engellenen kişiler (N)" satırı sayıyı gösterir ve temizler',
        (t) async {
      SharedPreferences.setMockInitialValues({
        YorumModerasyonu.engellenenAnahtari: ['u1', 'u2'],
      });
      await ac(t);
      await kaydir(t, 'Engellenen kişiler (2)');
      expect(find.text('Engellenen kişiler (2)'), findsOneWidget);
      await t.tap(find.text('Engellenen kişiler (2)'));
      await t.pumpAndSettle();
      expect(find.text('Engeller kaldırılsın mı?'), findsOneWidget);
      await t.tap(find.text('Engelleri kaldır'));
      await t.pumpAndSettle();
      expect(find.text('Engellenen kişiler (0)'), findsOneWidget);
      expect(await const YorumModerasyonu().engellenenler(), isEmpty);
    });

    testWidgets('kimse engelli değilken bilgi verir', (t) async {
      await ac(t);
      await kaydir(t, 'Engellenen kişiler (0)');
      await t.tap(find.text('Engellenen kişiler (0)'));
      await t.pumpAndSettle();
      expect(find.text('Engellediğin kimse yok'), findsOneWidget);
    });
  });

  group('firestore.rules', () {
    final kurallar = File('../firestore.rules').readAsStringSync();

    test(
        'reports: yalnızca geçerli alanlarla create, okuma / güncelleme / silme yok',
        () {
      expect(kurallar, contains('match /reports/{id}'));
      final bolum = kurallar.substring(kurallar.indexOf('match /reports/{id}'));
      expect(bolum, contains('allow create: if request.auth != null'));
      expect(bolum, contains('request.resource.data.uid == request.auth.uid'));
      expect(
          bolum,
          contains(
              "keys().hasOnly(['uid', 'commentId', 'slot', 'reason', 'targetUid', 'targetText', 'createdAt'])"));
      // bildiren yalnızca KENDİ bildirimini okuyabilir / silebilir; güncelleme yok; herkese açık okuma yok
      expect(
          bolum,
          contains(
              'allow read, delete: if request.auth != null && resource.data.uid == request.auth.uid;'));
      expect(bolum, contains('allow update: if false;'));
      expect(bolum, isNot(contains('allow read: if true')));
    });

    test('reason listesi YorumBildirimNedeni kodlarıyla aynı', () {
      final bolum = kurallar.substring(kurallar.indexOf('match /reports/{id}'));
      final eslesme = RegExp(r"reason in \[([^\]]*)\]").firstMatch(bolum)!;
      final kodlar = eslesme
          .group(1)!
          .split(',')
          .map((e) => e.trim().replaceAll("'", ''))
          .toSet();
      expect(kodlar, YorumBildirimNedeni.values.map((n) => n.kod).toSet());
    });
  });
}

/// Sayaçlı bellek içi depo (Ayarlar ve önbellek testleri için).
class _SayacDepo implements GeriBildirimDeposu {
  int yorumlarCagri = 0, silindi = 0;
  final bildirilen = <YorumBildirimNedeni>[];
  bool silmeHatasi = false;

  @override
  bool get cevrimici => true;
  @override
  Future<String> kullaniciId() async => 'u1';
  @override
  Future<PuanOzeti> puanOzeti(String slot) async => const PuanOzeti(null, 0);
  @override
  Future<int?> benimPuanim(String slot) async => null;
  @override
  Future<YemekPuanlari> puanlar(List<String> slotlar) async =>
      const YemekPuanlari({}, {});
  @override
  Future<void> puanVer(String slot, int yildiz) async {}
  @override
  Future<List<Yorum>> yorumlar(String slot) async {
    yorumlarCagri++;
    return [];
  }

  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async {}
  @override
  Future<void> yorumSil(Yorum y) async {}
  @override
  Future<void> yorumBildir(Yorum y, YorumBildirimNedeni neden) async =>
      bildirilen.add(neden);
  @override
  Future<void> verilerimiSil() async {
    if (silmeHatasi) throw Exception('ağ yok');
    silindi++;
  }
}
