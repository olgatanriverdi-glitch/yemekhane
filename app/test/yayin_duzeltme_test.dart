// Tur 15 (yayın denetimi düzeltmeleri): topluluk kuralları, kişi bildirme, silme tutarlılığı, Firestore kuralları ve
// sunucu zamanlı yazmalar, rıza tercihi değişimi, reklam içerik derecesi, mağaza görselleri.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/reklam/gercek_reklam_servisi.dart';
import 'package:yemekhane/reklam/reklam_ayari.dart';
import 'package:yemekhane/reklam/reklam_yoneticisi.dart';
import 'package:yemekhane/reklam/sahte_reklam_servisi.dart';
import 'package:yemekhane/reklam/uzak_ayar.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/topluluk_kurallari.dart';

import '../tool/opak_png.dart';

// ---- Firestore sahte istemcisi --------------------------------------------------------------------------------------

class _Sunucu {
  final istekler =
      <({String yontem, String adres, Map<String, dynamic>? govde})>[];
  int commitKodu = 200;

  late final MockClient istemci = MockClient((r) async {
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
    istekler.add((
      yontem: r.method,
      adres: u,
      govde: r.body.isEmpty ? null : jsonDecode(r.body) as Map<String, dynamic>
    ));
    if (u.contains(':commit')) return http.Response('{}', commitKodu);
    if (u.contains(':runQuery')) {
      return http.Response(
          jsonEncode([
            {'readTime': 'x'}
          ]),
          200);
    }
    return http.Response('{}', 200);
  });

  Iterable<Map<String, dynamic>> get commitler =>
      istekler.where((i) => i.adres.contains(':commit')).map((i) => i.govde!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ---- Madde 4 (Firestore sunucu zamanı, oran sınırı) ---------------------------------------------------------------
  group('FirestoreDepo: sunucu zamanlı yazmalar', () {
    test('puanVer tek commit: updatedAt REQUEST_TIME dönüşümüyle yazılır',
        () async {
      final s = _Sunucu();
      await FirestoreDepo('p', 'K', s.istemci).puanVer('s1', 4);
      final w = s.commitler.single['writes'] as List;
      expect(w, hasLength(1));
      final yaz = (w.single as Map);
      expect((yaz['update'] as Map)['name'],
          'projects/p/databases/(default)/documents/ratings/s1_U1');
      final alanlar = (yaz['update'] as Map)['fields'] as Map;
      expect(alanlar.keys.toSet(), {'uid', 'slot', 'stars'});
      expect(yaz['updateTransforms'], [
        {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'}
      ]);
    });

    test(
        'yorumEkle tek commit ve iki yazma: yorum (createdAt sunucu zamanı) + limits/uid.lastCommentAt',
        () async {
      final s = _Sunucu();
      await FirestoreDepo('p', 'K', s.istemci)
          .yorumEkle('s1', 'Ali', 'Merhaba');
      expect(s.commitler, hasLength(1), reason: 'iki yazma tek istekte');
      final w = (s.commitler.single['writes'] as List).cast<Map>();
      expect(w, hasLength(2));
      final yorum = w[0], limit = w[1];
      expect((yorum['update'] as Map)['name'],
          matches(r'documents/comments/[A-Za-z0-9]{20}$'));
      expect(((yorum['update'] as Map)['fields'] as Map).keys.toSet(),
          {'uid', 'slot', 'name', 'text'});
      expect(yorum['updateTransforms'], [
        {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}
      ]);
      expect(yorum['currentDocument'], {'exists': false});
      expect((limit['update'] as Map)['name'],
          'projects/p/databases/(default)/documents/limits/U1');
      expect(limit['updateTransforms'], [
        {'fieldPath': 'lastCommentAt', 'setToServerValue': 'REQUEST_TIME'}
      ]);
    });

    test('yorumEkle: sunucu reddederse (oran sınırı, 403) hata fırlatır',
        () async {
      final s = _Sunucu()..commitKodu = 403;
      await expectLater(
          FirestoreDepo('p', 'K', s.istemci).yorumEkle('s', 'A', 'M'),
          throwsException);
    });

    test('yorum kimlikleri rastgele ve benzersiz', () async {
      final s = _Sunucu();
      final d = FirestoreDepo('p', 'K', s.istemci);
      await d.yorumEkle('s', 'A', 'bir');
      await d.yorumEkle('s', 'A', 'iki');
      final adlar = [
        for (final c in s.commitler)
          (((c['writes'] as List).first as Map)['update'] as Map)['name']
      ];
      expect(adlar.toSet(), hasLength(2));
    });
  });

  // ---- Madde 2 (kişi bildirme) -----------------------------------------------------------------------------------------
  group('FirestoreDepo.yorumBildir: hedef yazar ve metin kopyası', () {
    test('hedef uid, metin kopyası ve <bildiren>_<yorum> kimliği yazılır',
        () async {
      final s = _Sunucu();
      final y = Yorum('c9', 'HEDEF', 'Ayşe', 'Kötü bir yorum', DateTime(2026),
          slot: 'y_a_b');
      await FirestoreDepo('p', 'K', s.istemci)
          .yorumBildir(y, YorumBildirimNedeni.hakaret);
      final yaz = ((s.commitler.single['writes'] as List).single as Map);
      final u = yaz['update'] as Map;
      expect(u['name'], endsWith('/reports/U1_c9'));
      final f = u['fields'] as Map;
      expect(f['targetUid'], {'stringValue': 'HEDEF'});
      expect(f['targetText'], {'stringValue': 'Kötü bir yorum'});
      expect(yaz['currentDocument'], {'exists': false});
      expect(yaz['updateTransforms'], [
        {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}
      ]);
    });

    test('metin kopyası en çok 300 karakter', () async {
      final s = _Sunucu();
      final y = Yorum('c', 'H', 'A', 'x' * 450, DateTime(2026), slot: 's');
      await FirestoreDepo('p', 'K', s.istemci)
          .yorumBildir(y, YorumBildirimNedeni.spam);
      final f = ((((s.commitler.single['writes'] as List).single
          as Map)['update'] as Map)['fields'] as Map);
      expect(((f['targetText'] as Map)['stringValue'] as String).length, 300);
    });

    test('aynı yorum ikinci kez bildirilirse (409) hata sayılmaz', () async {
      final s = _Sunucu()..commitKodu = 409;
      final y = Yorum('c', 'H', 'A', 'M', DateTime(2026), slot: 's');
      await FirestoreDepo('p', 'K', s.istemci)
          .yorumBildir(y, YorumBildirimNedeni.diger);
    });

    test('diğer hatalarda (403) hata fırlatır', () async {
      final s = _Sunucu()..commitKodu = 403;
      final y = Yorum('c', 'H', 'A', 'M', DateTime(2026), slot: 's');
      await expectLater(
          FirestoreDepo('p', 'K', s.istemci)
              .yorumBildir(y, YorumBildirimNedeni.diger),
          throwsException);
    });
  });

  // ---- Madde 3 (silme tutarlılığı) -------------------------------------------------------------------------------------
  group('FirestoreDepo.verilerimiSil: kendi şikâyetleri ve oran sınırı', () {
    test(
        'comments, ratings ve reports sorgulanır; limits belgesi silinmeye çalışılır',
        () async {
      final s = _Sunucu();
      final d = FirestoreDepo('p', 'K', s.istemci);
      await d.kullaniciId();
      await d.verilerimiSil();
      final koleksiyonlar = [
        for (final i in s.istekler.where((i) => i.adres.contains(':runQuery')))
          ((i.govde!['structuredQuery'] as Map)['from'] as List)
              .first['collectionId']
      ];
      expect(koleksiyonlar, ['comments', 'ratings', 'reports']);
      expect(
          s.istekler.any(
              (i) => i.yontem == 'DELETE' && i.adres.endsWith('/limits/U1')),
          isTrue);
    });
  });

  // ---- Madde 1 (topluluk kuralları) ------------------------------------------------------------------------------------
  group('Topluluk kuralları', () {
    Widget sayfa(GeriBildirimDeposu d) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GeriBildirimBolumu(
                    depo: d, slot: 's1', puanGoster: false))));

    Future<void> gonder(WidgetTester t, String metin) async {
      await t.enterText(find.byType(TextField), metin);
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();
    }

    testWidgets(
        'ilk yorumdan önce kurallar çıkar; Vazgeç yorumu da takma ad sorusunu da engeller',
        (t) async {
      final d = YerelDepo();
      await t.pumpWidget(sayfa(d));
      await t.pumpAndSettle();
      await gonder(t, 'Merhaba');
      expect(find.text('Topluluk kuralları'), findsOneWidget);
      expect(find.text('Kabul ediyorum'), findsOneWidget);
      for (final m in toplulukKurallariYasaklar) {
        expect(find.text(m), findsOneWidget);
      }
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(find.text('Takma adın'), findsNothing);
      expect(await d.yorumlar('s1'), isEmpty);
      expect(await toplulukKurallariKabulEdildi(), isFalse);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
          'Merhaba',
          reason: 'yazılan yorum kutuda kalır');
    });

    testWidgets(
        'Kabul sürümü kaydeder, takma ad sorulur ve yorum gider; ikinci yorumda kural sorulmaz',
        (t) async {
      final d = YerelDepo();
      await t.pumpWidget(sayfa(d));
      await t.pumpAndSettle();
      await gonder(t, 'Birinci');
      await t.tap(find.text('Kabul ediyorum'));
      await t.pumpAndSettle();
      expect(find.text('Takma adın'), findsOneWidget);
      await t.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Ayşe');
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      expect((await d.yorumlar('s1')).map((y) => y.metin), ['Birinci']);
      expect(
          (await SharedPreferences.getInstance())
              .getInt(toplulukKurallariAnahtar),
          toplulukKurallariSurum);

      await gonder(t, 'İkinci');
      expect(find.text('Topluluk kuralları'), findsNothing);
      expect(await d.yorumlar('s1'), hasLength(2));
    });

    testWidgets('kural sürümü yükselirse yeniden sorulur', (t) async {
      SharedPreferences.setMockInitialValues({
        'yorum_adi': 'Ali',
        toplulukKurallariAnahtar: toplulukKurallariSurum - 1,
      });
      final d = YerelDepo();
      await t.pumpWidget(sayfa(d));
      await t.pumpAndSettle();
      await gonder(t, 'Merhaba');
      expect(find.text('Topluluk kuralları'), findsOneWidget);
    });

    testWidgets('güncel sürüm kabul edilmişse diyalog çıkmaz', (t) async {
      SharedPreferences.setMockInitialValues({
        'yorum_adi': 'Ali',
        toplulukKurallariAnahtar: toplulukKurallariSurum,
      });
      final d = YerelDepo();
      await t.pumpWidget(sayfa(d));
      await t.pumpAndSettle();
      await gonder(t, 'Merhaba');
      expect(find.text('Topluluk kuralları'), findsNothing);
      expect(await d.yorumlar('s1'), hasLength(1));
    });

    testWidgets(
        'Ayarlar > Hakkında: "Topluluk kuralları" satırı metni gösterir',
        (t) async {
      t.view.physicalSize = const Size(800, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          home: AyarlarSayfasi(
              temaAyari: TemaAyari(),
              depo: Depo(),
              uniler: const [],
              uni: null,
              menuyuYenile: () async {})));
      await t.pumpAndSettle();
      final satir = find.text('Topluluk kuralları');
      await t.scrollUntilVisible(satir, 300,
          scrollable: find.byType(Scrollable).first);
      await t.tap(satir);
      await t.pumpAndSettle();
      expect(find.text(toplulukKurallariKaldirma), findsOneWidget);
      expect(find.text('Kabul ediyorum'), findsNothing,
          reason: 'yalnızca gösterim: onay düğmesi yok');
      expect(find.text('Kapat'), findsOneWidget);
    });

    test('site/kurallar.html uygulamadaki metinle aynı maddeleri taşır', () {
      final html = File('../site/kurallar.html').readAsStringSync();
      for (final m in [
        toplulukKurallariGiris,
        ...toplulukKurallariYasaklar,
        toplulukKurallariKaldirma,
        toplulukKurallariEngelleme,
        toplulukKurallariBildirimYolu,
      ]) {
        expect(html, contains(m));
      }
      for (final sayfa in ['gizlilik.html', 'hesap-silme.html']) {
        expect(File('../site/$sayfa').readAsStringSync(),
            contains('kurallar.html'));
      }
    });
  });

  // ---- Madde 2, 3, 4 (kurallar dosyası) ---------------------------------------------------------------------------
  group('firestore.rules (metin denetimi; emülatör yok)', () {
    final k = File('../firestore.rules').readAsStringSync();
    String bolum(String ad) {
      final a = k.indexOf('match /$ad/');
      expect(a, greaterThan(-1), reason: ad);
      final b = k.indexOf('\n    match /', a + 5);
      return k.substring(a, b == -1 ? k.length : b);
    }

    test('yorum: createdAt == request.time ve oran sınırı getAfter ile', () {
      final c = bolum('comments');
      expect(c, contains('request.resource.data.createdAt == request.time'));
      expect(c, contains('existsAfter('));
      expect(c, contains('getAfter('));
      expect(c, contains('lastCommentAt == request.time'));
      expect(c, contains("duration.value(20, 's')"));
    });

    test('puan: updatedAt == request.time', () {
      expect(bolum('ratings'),
          contains('request.resource.data.updatedAt == request.time'));
    });

    test('limits: yalnızca lastCommentAt, sunucu zamanı, okunamaz', () {
      final l = bolum('limits');
      expect(l, contains("hasOnly(['lastCommentAt'])"));
      expect(l, contains('lastCommentAt == request.time'));
      expect(l, contains('allow read: if false;'));
      expect(l, contains('request.auth.uid == uid'));
    });

    test(
        'reports: kimlik <uid>_<yorumId>, yorum varlığı, slot/yazar/metin eşleşmesi',
        () {
      final r = bolum('reports');
      expect(
          r,
          contains(
              "id == request.auth.uid + '_' + request.resource.data.commentId"));
      expect(r, contains('exists(/databases/\$(database)/documents/comments/'));
      expect(r, contains('.data.slot == request.resource.data.slot'));
      expect(r, contains('.data.uid == request.resource.data.targetUid'));
      expect(
          r, contains('request.resource.data.targetUid != request.auth.uid'));
      expect(r, contains('request.resource.data.createdAt == request.time'));
      // bildiren kendi şikâyetlerini silebilir ("Yorum ve puanlarımı sil")
      expect(
          r,
          contains(
              'allow read, delete: if request.auth != null && resource.data.uid == request.auth.uid'));
    });

    test('küme parantezleri dengeli', () {
      expect('{'.allMatches(k).length, '}'.allMatches(k).length);
      expect('('.allMatches(k).length, ')'.allMatches(k).length);
    });
  });

  // ---- Madde 5 (UMP tercihi) -----------------------------------------------------------------------------------------
  group('Rıza tercihi değişince reklam hazırlığı yenilenir', () {
    final stil = ReklamStili.temadan(TemaAyari().tema(Brightness.light));
    DateTime sabah() => DateTime.utc(2026, 11, 2, 10);

    ReklamYoneticisi yonetici(SahteReklamServisi s,
            {Future<UzakReklamAyari> Function()? ayar}) =>
        ReklamYoneticisi(servis: s, simdi: sabah, ayarGetir: ayar);

    test(
        'tercih formu kapanınca hazırlık sonucu sıfırlanır, bir sonraki istek rızayı yeniden denetler',
        () async {
      final s = SahteReklamServisi();
      final y = yonetici(s);
      await y.iste('a', stil);
      await y.iste('b', stil);
      expect(s.hazirlaSayisi, 1, reason: 'hazırlık önbellekte');
      await y.tercihleriAc();
      expect(s.tercihAcSayisi, 1);
      await y.iste('c', stil);
      expect(s.hazirlaSayisi, 2,
          reason: 'tercih değişti: rıza yeniden denetlendi');
      y.dispose();
    });

    test('bellekteki gösterilmeyen reklamlar hemen serbest bırakılır',
        () async {
      final s = SahteReklamServisi();
      final y = yonetici(s);
      await y.iste('a', stil);
      await y.iste('b', stil);
      expect(s.acikReklam, 2);
      y.tercihDegisti();
      expect(s.acikReklam, 0);
      expect(y.onbellekAdedi, 0);
      y.dispose();
    });

    test('gösterilen reklam bırakılana dek durur, sonra yeniden kullanılmaz',
        () async {
      final s = SahteReklamServisi();
      final y = yonetici(s);
      await y.iste('a', stil);
      final sahip = Object();
      expect(y.sahiplen('a', sahip), isTrue);
      y.tercihDegisti();
      expect(s.acikReklam, 1, reason: 'ekranda: çizilirken serbest bırakılmaz');
      y.birak('a', sahip);
      expect(y.taze('a'), isNull,
          reason: 'eski rızayla istenen reklam kullanılmaz');
      expect(s.acikReklam, 0);
      y.dispose();
    });

    test('yükleme sürerken tercih değişirse gelen reklam atılır', () async {
      final s = SahteReklamServisi(gecikme: const Duration(milliseconds: 40));
      final y = yonetici(s);
      final f = y.iste('a', stil);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      y.tercihDegisti();
      expect(await f, isNull);
      expect(s.acikReklam, 0);
      expect(y.onbellekAdedi, 0);
      y.dispose();
    });

    test('rıza geri alındıysa (canRequestAds false) yeni istek atılmaz',
        () async {
      final s = SahteReklamServisi()..hazirlaSonuclari.addAll([true, false]);
      final y = yonetici(s);
      await y.iste('a', stil);
      expect(s.yukleSayisi, 1);
      y.tercihDegisti();
      expect(await y.iste('b', stil), isNull);
      expect(s.hazirlaSayisi, 2);
      expect(s.yukleSayisi, 1, reason: 'rıza yok: reklam isteği atılmadı');
      y.dispose();
    });

    test('rıza bilgisi sürümü artar (Ayarlar satırı yeniden değerlendirilir)',
        () async {
      final y = yonetici(SahteReklamServisi());
      final onceki = y.rizaSurumu.value;
      y.tercihDegisti();
      expect(y.rizaSurumu.value, greaterThan(onceki));
      y.dispose();
    });
  });

  // ---- Madde 6 (içerik derecesi) -----------------------------------------------------------------------------------------
  group('Reklam içerik derecesi', () {
    test('varsayılan G; G/PG/T geçerli, bozuk değer G', () {
      expect(UzakReklamAyari.varsayilan.maxIcerik, 'G');
      for (final d in ['G', 'PG', 'T']) {
        expect(
            UzakReklamAyari.fromJson({
              'reklam': {'maxIcerik': d}
            }).maxIcerik,
            d);
      }
      expect(
          UzakReklamAyari.fromJson({
            'reklam': {'maxIcerik': 'pg'}
          }).maxIcerik,
          'PG');
      for (final bozuk in [
        'MA',
        '',
        5,
        null,
        true,
        ['T']
      ]) {
        expect(
            UzakReklamAyari.fromJson({
              'reklam': {'maxIcerik': bozuk}
            }).maxIcerik,
            'G',
            reason: '$bozuk');
      }
      expect(UzakReklamAyari.fromJson('bozuk').maxIcerik, 'G');
    });

    test('SDK sabiti: G varsayılan, bilinmeyen değer G', () {
      expect(GercekReklamServisi.icerikDerecesiSabiti('G'), 'G');
      expect(GercekReklamServisi.icerikDerecesiSabiti('PG'), 'PG');
      expect(GercekReklamServisi.icerikDerecesiSabiti('T'), 'T');
      expect(GercekReklamServisi.icerikDerecesiSabiti('X'), 'G');
    });

    test('paket ve uzak ayar dosyaları maxIcerik: G taşır ve birbirinin aynısı',
        () {
      final a = File('../data/ayarlar.json').readAsStringSync();
      final b = File('assets/data/ayarlar.json').readAsStringSync();
      expect(a, b);
      expect((jsonDecode(a) as Map)['reklam']['maxIcerik'], 'G');
    });

    test('yönetici derecesi servise hazırlıktan önce verir', () async {
      SharedPreferences.setMockInitialValues({ilkAcilisAnahtari: '2026-10-20'});
      final s = SahteReklamServisi();
      final y = ReklamYoneticisi(
          servis: s,
          simdi: () => DateTime.utc(2026, 11, 2, 10),
          ayarGetir: () async => const UzakReklamAyari(maxIcerik: 'PG'));
      await y.ayarYukle();
      await y.iste(
          'a', ReklamStili.temadan(TemaAyari().tema(Brightness.light)));
      expect(s.hazirlaDereceleri, ['PG']);
      y.dispose();
    });

    test('ayar yüklenmeden önce hazırlık en sıkı derece (G) ile yapılır',
        () async {
      final s = SahteReklamServisi();
      final y = ReklamYoneticisi(
          servis: s, simdi: () => DateTime.utc(2026, 11, 2, 10));
      await y.iste(
          'a', ReklamStili.temadan(TemaAyari().tema(Brightness.light)));
      expect(s.hazirlaDereceleri, ['G']);
      y.dispose();
    });
  });

  // ---- Madde 10 (mağaza görselleri) -----------------------------------------------------------------------------------
  group('Mağaza görselleri alfasız 24 bit PNG', () {
    test(
        'opakPng RGBA girdisinden renk tipi 2 (RGB) üretir ve zemine birleştirir',
        () {
      final rgba = ByteData(2 * 4)
        ..setUint8(0, 10)
        ..setUint8(1, 20)
        ..setUint8(2, 30)
        ..setUint8(3, 255) // opak
        ..setUint8(4, 0)
        ..setUint8(5, 0)
        ..setUint8(6, 0)
        ..setUint8(7, 0); // tam saydam -> beyaz
      final png = opakPng(2, 1, rgba);
      final bilgi = pngRenkBilgisi(png);
      expect(bilgi.renkTipi, 2);
      expect(bilgi.bitDerinligi, 8);
      final ham = zlib.decode(_idat(png));
      expect(ham, [0, 10, 20, 30, 255, 255, 255]);
    });

    test('magaza/ekranlar ve öne çıkan görsel: renk tipi 2, 8 bit', () {
      final dosyalar = [
        ...Directory('../magaza/ekranlar')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png')),
        File('../magaza/gorseller/one-cikan-gorsel-1024x500.png'),
      ];
      expect(dosyalar.length, greaterThanOrEqualTo(8));
      for (final f in dosyalar) {
        final b = f.readAsBytesSync();
        expect(b.sublist(1, 4), [0x50, 0x4E, 0x47], reason: f.path);
        final bilgi = pngRenkBilgisi(b);
        expect(bilgi.renkTipi, 2, reason: '${f.path}: alfasız RGB olmalı');
        expect(bilgi.bitDerinligi, 8, reason: f.path);
      }
    });
  });
}

/// PNG'nin IDAT parçalarını birleştirir (yalnızca test için).
List<int> _idat(List<int> png) {
  final cikti = <int>[];
  var i = 8;
  while (i < png.length) {
    final n = ByteData.sublistView(Uint8List.fromList(png.sublist(i, i + 4)))
        .getUint32(0);
    final tur = String.fromCharCodes(png.sublist(i + 4, i + 8));
    if (tur == 'IDAT') cikti.addAll(png.sublist(i + 8, i + 8 + n));
    i += 12 + n;
  }
  return cikti;
}
