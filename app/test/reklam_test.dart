// Rahatsız etmeyen reklam (Google AdMob yerel reklam): kurallar, yönetici ve ekran davranışı.
// Gerçek SDK / platform kanalı hiçbir testte kullanılmaz; SahteReklamServisi çağrıları sayar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/reklam/gec_yukleme.dart';
import 'package:yemekhane/reklam/gercek_reklam_servisi.dart';
import 'package:yemekhane/reklam/reklam_ayari.dart';
import 'package:yemekhane/reklam/reklam_karti.dart';
import 'package:yemekhane/reklam/reklam_servisi.dart';
import 'package:yemekhane/reklam/reklam_yoneticisi.dart';
import 'package:yemekhane/reklam/sahte_reklam_servisi.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

// ---- ortak yardımcılar -----------------------------------------------------------------------------------------

/// Pazartesi 2 Kasım 2026, 10:00 (Türkiye duvar saati).
DateTime _sabah() => DateTime.utc(2026, 11, 2, 10, 0);

/// Nezaket süresi çoktan bitmiş bir ilk açılış kaydı.
const _eskiKayit = {ilkAcilisAnahtari: '2026-10-20'};

ReklamStili _stil([Brightness b = Brightness.light]) =>
    ReklamStili.temadan(TemaAyari().tema(b));

ReklamYoneticisi _yonetici(SahteReklamServisi servis,
        {DateTime Function()? simdi, int oturum = oturumYuklemeSiniri}) =>
    ReklamYoneticisi(
        servis: servis, simdi: simdi ?? _sabah, oturumSiniri: oturum);

Finder get _kartListesi => find
    .descendant(of: find.byType(OgunKarti), matching: find.byType(Scrollable))
    .first;

Finder get _sahteReklam => find.byWidgetPredicate((w) =>
    w.key is ValueKey<String> &&
    (w.key! as ValueKey<String>).value.startsWith('sahte-reklam-'));

class _Depo extends Depo {
  _Depo(this.menuVeri);
  final Menu menuVeri;
  Completer<void>? kapi;
  @override
  Future<List<Universite>> universiteler() async => [
        Universite(
            id: 'ankara',
            ad: 'Ankara Üniversitesi',
            kisa: 'ankara',
            sehir: 'Ankara',
            kaynak: '',
            ogunler: const ['lunch', 'dinner'],
            fiyatlar: const [])
      ];
  @override
  Future<Menu> menu(String id) async {
    if (kapi != null) await kapi!.future;
    return menuVeri;
  }

  @override
  Future<String?> seciliUniversite() async => 'ankara';
  @override
  Future<void> universiteSec(String id) async {}
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  String? fotoUrl(String universiteId, String? foto) => null;
  @override
  String? yemekFotoUrl(String? img) => null;
}

Menu _menu() => Menu('ankara', null, {
      '2026-11-02': {
        'lunch': Ogun([
          YemekOgesi('Mercimek Çorbası', 120),
          YemekOgesi('Pirinç Pilavı', 300),
        ], 420),
        'dinner': Ogun([YemekOgesi('Fırın Makarna', 500)], 500),
      },
      '2026-11-03': {
        'lunch': Ogun([YemekOgesi('Ezogelin Çorbası', 120)], 120),
        'dinner': Ogun([YemekOgesi('Tavuk Sote', 400)], 400),
      },
      '2026-11-04': {
        'lunch': Ogun([], null, null, false, 'Tatil'),
        'dinner': Ogun([], null, null, false, 'Tatil'),
      },
    });

Future<void> _anaAc(WidgetTester t, ReklamYoneticisi y,
    {_Depo? depo,
    Size boyut = const Size(400, 1400),
    double yazi = 1.0,
    bool hareketKapali = false,
    bool bekle = true}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari();
  await t.pumpWidget(MaterialApp(
    theme: ayar.tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(yazi),
            disableAnimations: hareketKapali),
        child: w!),
    home: AnaSayfa(
        temaAyari: ayar,
        depo: depo ?? _Depo(_menu()),
        geriBildirim: YerelDepo(),
        simdi: _sabah,
        reklam: y),
  ));
  if (bekle) await t.pumpAndSettle();
}

/// Tek bir ReklamKarti'nı bir listede açar.
Future<void> _kartAc(WidgetTester t, ReklamYoneticisi y,
    {String anahtar = '2026-11-02|lunch',
    bool hareketKapali = false,
    ThemeData? tema}) async {
  await t.pumpWidget(MaterialApp(
    theme: tema ?? TemaAyari().tema(Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: hareketKapali),
      child: Scaffold(
          body: ListView(children: [
        const Text('üst'),
        ReklamKarti(anahtar: anahtar, yonetici: y),
        const Text('alt'),
      ])),
    ),
  ));
}

double _kartYuksekligi(WidgetTester t) =>
    t.getSize(find.byType(ReklamKarti)).height;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(_eskiKayit));

  group('birim kimliği seçimi', () {
    String? sec(
            {String a = '',
            String i = '',
            bool web = false,
            TargetPlatform p = TargetPlatform.android,
            bool surum = false}) =>
        reklamBirimiSec(
            androidTanimli: a,
            iosTanimli: i,
            web: web,
            platform: p,
            surum: surum);

    test('debug / profile ve kimlik boş: Google test birimi', () {
      expect(sec(), testBirimAndroid);
      expect(sec(p: TargetPlatform.iOS), testBirimIos);
    });

    test(
        'release ve kimlik boş: reklam tamamen kapalı (test birimi asla çıkmaz)',
        () {
      expect(sec(surum: true), isNull);
      expect(sec(surum: true, p: TargetPlatform.iOS), isNull);
      expect(sec(surum: true, a: '   '), isNull);
    });

    test('kimlik verilmişse her derlemede o kullanılır; platforma göre ayrılır',
        () {
      expect(sec(a: 'ca-app-pub-1/2', surum: true), 'ca-app-pub-1/2');
      expect(sec(a: 'ca-app-pub-1/2'), 'ca-app-pub-1/2');
      expect(sec(i: 'ca-app-pub-1/9', p: TargetPlatform.iOS, surum: true),
          'ca-app-pub-1/9');
      expect(
          sec(a: 'ca-app-pub-1/2', p: TargetPlatform.iOS, surum: true), isNull);
    });

    test('web ve masaüstünde her zaman kapalı', () {
      expect(sec(web: true, a: 'x'), isNull);
      expect(sec(p: TargetPlatform.windows), isNull);
      expect(sec(p: TargetPlatform.macOS, a: 'x'), isNull);
    });

    test('kimliksiz gerçek servis kapalıdır ve platform kanalına dokunmaz',
        () async {
      final s = GercekReklamServisi.birimle(null);
      expect(s.kullanilabilir, isFalse);
      expect(await s.hazirla(), isFalse);
      expect(await s.yukle(_stil()), isNull);
      expect(await s.tercihGerekli(), isFalse);
      expect(
          GercekReklamServisi.birimle('ca-app-pub-1/2').kullanilabilir, isTrue);
    });

    test('bu test derlemesinde kimlik dart-define ile gelmez', () {
      // dart-define verilmeden alınan release'te de gecerliReklamBirimi null olur (yukarıdaki kural).
      expect(admobNativeAndroid, isEmpty);
      expect(admobNativeIos, isEmpty);
    });
  });

  group('yeni kullanıcı nezaketi (3 gün)', () {
    const ilk = '2026-10-30';
    test('sınır: üçüncü gün hâlâ reklamsız, dördüncü gün reklam', () {
      expect(reklamsizSureBitti(ilk, DateTime.utc(2026, 10, 30, 9)), isFalse);
      expect(
          reklamsizSureBitti(ilk, DateTime.utc(2026, 11, 1, 23, 59)), isFalse);
      expect(
          reklamsizSureBitti(ilk, DateTime.utc(2026, 11, 2, 23, 59)), isFalse);
      expect(reklamsizSureBitti(ilk, DateTime.utc(2026, 11, 3, 0, 1)), isTrue);
      expect(reklamsizSureBitti(ilk, DateTime.utc(2027, 3, 1)), isTrue);
    });

    test('bozuk, eksik ve gelecekteki kayıt reklamsız sayılır ve geçersizdir',
        () {
      final simdi = DateTime.utc(2026, 11, 2);
      for (final k in [
        null,
        '',
        'abc',
        5,
        true,
        '2026-02-31',
        '2026-13-01',
        '26-1-1',
        '2026-11-03'
      ]) {
        expect(reklamsizSureBitti(k, simdi), isFalse, reason: '$k');
        expect(ilkAcilisKaydiGecerli(k, simdi), isFalse, reason: '$k');
      }
      expect(ilkAcilisKaydiGecerli('2026-11-02', simdi), isTrue);
    });

    test('yönetici: kayıt yoksa bugünü yazar ve reklam göstermez', () async {
      SharedPreferences.setMockInitialValues({});
      final y = _yonetici(SahteReklamServisi());
      expect(await y.gosterilebilir(), isFalse);
      expect(
          (await SharedPreferences.getInstance()).getString(ilkAcilisAnahtari),
          '2026-11-02');
      y.dispose();
    });

    test('yönetici: bozuk kayıt bugünle değiştirilir; geçerli kayıt korunur',
        () async {
      SharedPreferences.setMockInitialValues({ilkAcilisAnahtari: 12345});
      final y = _yonetici(SahteReklamServisi());
      expect(await y.gosterilebilir(), isFalse);
      final p = await SharedPreferences.getInstance();
      expect(p.getString(ilkAcilisAnahtari), '2026-11-02');
      SharedPreferences.setMockInitialValues({ilkAcilisAnahtari: '2026-10-01'});
      expect(await y.gosterilebilir(), isTrue);
      expect(
          (await SharedPreferences.getInstance()).getString(ilkAcilisAnahtari),
          '2026-10-01');
      y.dispose();
    });

    test('reklam kapalı olsa da ilk açılış kaydedilir', () async {
      SharedPreferences.setMockInitialValues({});
      final y = _yonetici(SahteReklamServisi(kullanilabilir: false));
      await y.ilkAcilisiKaydet();
      expect(
          (await SharedPreferences.getInstance()).getString(ilkAcilisAnahtari),
          '2026-11-02');
      expect(await y.gosterilebilir(), isFalse);
      y.dispose();
    });
  });

  group('ReklamYoneticisi', () {
    test('kapalı servis: sıfır çağrı', () async {
      final s = SahteReklamServisi(kullanilabilir: false);
      final y = _yonetici(s);
      expect(y.acik, isFalse);
      expect(await y.iste('a', _stil()), isNull);
      expect(await y.tercihGerekli(), isFalse);
      expect(s.hazirlaSayisi + s.yukleSayisi, 0);
      y.dispose();
    });

    test('rıza yoksa istek atılmaz; kısa sürede yeniden denenmez', () async {
      final s = SahteReklamServisi(rizaVar: false);
      final y = _yonetici(s);
      expect(await y.iste('a', _stil()), isNull);
      expect(await y.iste('b', _stil()), isNull);
      expect(s.hazirlaSayisi, 1);
      expect(s.yukleSayisi, 0);
      y.dispose();
    });

    test(
        'oturum sınırı: en çok 10 yükleme, sonrası eldekiler yeniden kullanılır',
        () async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      for (var i = 0; i < 12; i++) {
        final n = await y.iste('k$i', _stil());
        expect(n == null, i >= 10, reason: 'k$i');
      }
      expect(s.yukleSayisi, 10);
      expect(y.yuklemeSayisi, 10);
      // bellekteki son reklam sınır dolunca da verilir, yeni yükleme olmaz
      expect(await y.iste('k9', _stil()), isNotNull);
      expect(s.yukleSayisi, 10);
      y.dispose();
    });

    test('LRU: en çok 3 reklam bellekte kalır, çıkan dispose edilir', () async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      for (final k in ['a', 'b', 'c']) {
        await y.iste(k, _stil());
      }
      await y.iste('a', _stil()); // a yeniden kullanıldı: en eski artık b
      await y.iste('d', _stil());
      expect(y.onbellekAdedi, 3);
      expect(s.acikReklam, 3);
      expect(y.nesne('b'), isNull);
      expect(y.nesne('a'), isNotNull);
      expect(s.yuklenenler[1].kapandi, isTrue); // b
      expect(s.yuklenenler[0].kapandi, isFalse);
      y.dispose();
      expect(s.acikReklam, 0);
    });

    test('gösterilen reklam atılmaz; bırakılınca bellek sınırı uygulanır',
        () async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      final sahip = Object();
      await y.iste('a', _stil());
      expect(y.sahiplen('a', sahip), isTrue);
      for (final k in ['b', 'c', 'd']) {
        await y.iste(k, _stil());
      }
      expect(y.nesne('a'), isNotNull);
      expect(s.yuklenenler[0].kapandi, isFalse);
      expect(y.onbellekAdedi, 3);
      y.birak('a', sahip);
      await y.iste('e', _stil());
      expect(y.onbellekAdedi, 3);
      expect(s.acikReklam, 3);
      y.dispose();
    });

    test('çift sahiplik: ikinci sahip alamaz, birincisi bırakınca alır',
        () async {
      final y = _yonetici(SahteReklamServisi());
      await y.iste('a', _stil());
      final bir = Object(), iki = Object();
      expect(y.sahiplen('a', bir), isTrue);
      expect(y.sahiplen('a', bir), isTrue); // aynı sahip tekrar: sorun yok
      expect(y.sahiplen('a', iki), isFalse);
      y.birak('a', iki); // sahibi olmayan bırakamaz
      expect(y.sahiplen('a', iki), isFalse);
      y.birak('a', bir);
      expect(y.sahiplen('a', iki), isTrue);
      expect(
          y.sahiplen('yok', bir), isFalse); // bellekte olmayan sahiplenilemez
      y.dispose();
    });

    test('eşzamanlı aynı anahtar tek yükleme paylaşır', () async {
      final s = SahteReklamServisi(gecikme: const Duration(milliseconds: 20));
      final y = _yonetici(s);
      final r = await Future.wait([y.iste('a', _stil()), y.iste('a', _stil())]);
      expect(identical(r[0], r[1]), isTrue);
      expect(s.yukleSayisi, 1);
      y.dispose();
    });

    test('yüklenemeyen anahtar 3 dakika yeniden denenmez, sonra denenir',
        () async {
      var an = _sabah();
      final s = SahteReklamServisi(basarili: false);
      final y = _yonetici(s, simdi: () => an);
      expect(await y.iste('a', _stil()), isNull);
      expect(await y.iste('a', _stil()), isNull);
      expect(s.yukleSayisi, 1);
      an = an.add(const Duration(minutes: 4));
      s.basarili = true;
      expect(await y.iste('a', _stil()), isNotNull);
      expect(s.yukleSayisi, 2);
      y.dispose();
    });

    test('bayat reklam (55 dk+) yeniden yüklenir, eskisi serbest bırakılır',
        () async {
      var an = _sabah();
      final s = SahteReklamServisi();
      final y = _yonetici(s, simdi: () => an);
      await y.iste('a', _stil());
      an = an.add(const Duration(minutes: 56));
      await y.iste('a', _stil());
      expect(s.yukleSayisi, 2);
      expect(s.yuklenenler[0].kapandi, isTrue);
      y.dispose();
    });

    test('bayat reklam gösterim yolunda da verilmez: taze() ve sahiplen()',
        () async {
      var an = _sabah();
      final s = SahteReklamServisi();
      final y = _yonetici(s, simdi: () => an);
      await y.iste('a', _stil());
      expect(y.taze('a'), isNotNull);
      an = an.add(const Duration(minutes: 56));
      // kimse göstermiyor: önbellekteki 56 dk'lık reklam sahiplenilemez, serbest bırakılır
      expect(y.sahiplen('a', Object()), isFalse);
      expect(s.yuklenenler[0].kapandi, isTrue);
      expect(y.taze('a'), isNull);
      // gösteren varsa (zaten ekranda) dokunulmaz
      await y.iste('b', _stil());
      final sahip = Object();
      expect(y.sahiplen('b', sahip), isTrue);
      an = an.add(const Duration(minutes: 56));
      expect(y.taze('b'), isNotNull);
      expect(y.sahiplen('b', sahip), isTrue);
      y.dispose();
    });

    test('rıza bilgisi güncellenince rizaSurumu artar', () async {
      final y = _yonetici(SahteReklamServisi());
      final surum = y.rizaSurumu.value;
      await y.iste('a', _stil());
      expect(y.rizaSurumu.value, greaterThan(surum));
      y.dispose();
    });

    test('servis hata atarsa yönetici hata atmaz', () async {
      final y = ReklamYoneticisi(servis: _Bozuk(), simdi: _sabah);
      expect(await y.iste('a', _stil()), isNull);
      expect(await y.tercihGerekli(), isFalse);
      await y.tercihleriAc();
      y.dispose();
    });

    test('tema değişince (görünüm imzası) farklı anahtar çıkar', () {
      final y = _yonetici(SahteReklamServisi());
      expect(y.anahtarOlustur('g|lunch', _stil(Brightness.light)),
          isNot(y.anahtarOlustur('g|lunch', _stil(Brightness.dark))));
      y.dispose();
    });
  });

  group('GecYuklemeKorumasi (zaman aşımından sonra gelen reklam)', () {
    test('zamanında gelen reklam teslim edilir, dispose edilmez', () async {
      final k = GecYuklemeKorumasi();
      final r = SahteReklamNesnesi(1);
      k.yuklendi(r);
      expect(await k.bekle(const Duration(seconds: 1)), same(r));
      expect(r.kapandi, isFalse);
    });

    test('zaman aşımında null döner; geç gelen reklam hemen dispose edilir',
        () async {
      final k = GecYuklemeKorumasi();
      final sonuc = await k.bekle(const Duration(milliseconds: 10));
      expect(sonuc, isNull);
      expect(k.zamanAsimiOldu, isTrue);
      final gec = SahteReklamNesnesi(2);
      k.yuklendi(gec);
      expect(gec.kapandi, isTrue);
    });

    test('başarısızlık null verir; sonradan gelen reklam yine dispose edilir',
        () async {
      final k = GecYuklemeKorumasi()..basarisiz();
      expect(await k.bekle(const Duration(seconds: 1)), isNull);
      final r = SahteReklamNesnesi(3);
      k.yuklendi(r);
      expect(r.kapandi, isTrue);
    });
  });

  group('ReklamKarti', () {
    testWidgets(
        'tema değişince reklam alt ağacı yenilenir (AdWidget eski reklamı tutmaz)',
        (t) async {
      final s = _SayacliServis();
      final y = _yonetici(s);
      await _kartAc(t, y);
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      expect(s.kurulan, 1);
      await _kartAc(t, y, tema: TemaAyari().tema(Brightness.dark));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      // ikinci reklam için YENİ durum nesnesi kuruldu (aynı öğe yeniden kullanılmadı)
      expect(s.kurulan, 2);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets(
        '55 dk sonra aynı öğüne dönülünce eski reklam gösterilmez, yenisi yüklenir',
        (t) async {
      var an = _sabah();
      final s = SahteReklamServisi();
      final y = _yonetici(s, simdi: () => an);
      await _kartAc(t, y, anahtar: 'a');
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      expect(s.yukleSayisi, 1);
      await _kartAc(t, y, anahtar: 'b'); // 'a' bırakılır, bellekte kalır
      await t.pump(const Duration(milliseconds: 100));
      an = an.add(const Duration(minutes: 56));
      await _kartAc(t, y, anahtar: 'a');
      await t.pump(const Duration(milliseconds: 100));
      expect(_sahteReklam, findsNothing); // bayat reklam hemen çizilmedi
      expect(s.yuklenenler[0].kapandi, isTrue);
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      expect(s.yukleSayisi, 2);
      expect(_sahteReklam, findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('2 sn dolmadan istek yok; dolunca bir istek, reklam açılır',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _kartAc(t, y);
      await t.pump(const Duration(milliseconds: 1900));
      expect(s.yukleSayisi, 0);
      expect(_sahteReklam, findsNothing);
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 400));
      expect(s.yukleSayisi, 1);
      expect(_sahteReklam, findsOneWidget);
      expect(find.text('Reklam'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('hızlı geçişte (2 sn dolmadan kapanınca) hiç istek gitmez',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _kartAc(t, y, anahtar: 'a');
      await t.pump(const Duration(seconds: 1));
      await _kartAc(t, y, anahtar: 'b'); // başka gün: bekleme yeniden başlar
      await t.pump(const Duration(milliseconds: 1500));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
      expect(s.hazirlaSayisi, 0);
      expect(s.yukleSayisi, 0);
      y.dispose();
    });

    testWidgets('kapalı servis: istek yok, yer kaplamaz', (t) async {
      final s = SahteReklamServisi(kullanilabilir: false);
      final y = _yonetici(s);
      await _kartAc(t, y);
      await t.pump(const Duration(seconds: 6));
      expect(s.hazirlaSayisi + s.yukleSayisi, 0);
      expect(_kartYuksekligi(t), 0);
      expect(find.text('Reklam'), findsNothing);
      y.dispose();
    });

    testWidgets('yönetici verilmezse hiçbir şey çizilmez', (t) async {
      await t.pumpWidget(const MaterialApp(
          home: Scaffold(body: ReklamKarti(anahtar: 'a', yonetici: null))));
      await t.pump(const Duration(seconds: 3));
      expect(t.getSize(find.byType(ReklamKarti)).height, 0);
    });

    testWidgets('rıza yok: istek atılmaz, yer kaplamaz', (t) async {
      final s = SahteReklamServisi(rizaVar: false);
      final y = _yonetici(s);
      await _kartAc(t, y);
      await t.pump(const Duration(seconds: 3));
      expect(s.hazirlaSayisi, 1);
      expect(s.yukleSayisi, 0);
      expect(_kartYuksekligi(t), 0);
      y.dispose();
    });

    testWidgets('nezaket süresi dolmadıysa istek atılmaz', (t) async {
      SharedPreferences.setMockInitialValues({ilkAcilisAnahtari: '2026-11-01'});
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _kartAc(t, y);
      await t.pump(const Duration(seconds: 5));
      expect(s.hazirlaSayisi + s.yukleSayisi, 0);
      expect(_kartYuksekligi(t), 0);
      y.dispose();
    });

    testWidgets('yüklenemezse boşluk bile bırakmaz', (t) async {
      final s = SahteReklamServisi(basarili: false);
      final y = _yonetici(s);
      await _kartAc(t, y);
      final altOnce = t.getTopLeft(find.text('alt')).dy;
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      expect(s.yukleSayisi, 1);
      expect(_kartYuksekligi(t), 0);
      expect(t.getTopLeft(find.text('alt')).dy, altOnce);
      expect(_sahteReklam, findsNothing);
      y.dispose();
    });

    testWidgets(
        'çift sahiplik: iki kart aynı reklamı çizmez; biri kalkınca öbürü alır',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      Widget iki({bool ilk = true}) => MaterialApp(
              home: Scaffold(
                  body: ListView(children: [
            if (ilk)
              ReklamKarti(key: const ValueKey('a'), anahtar: 'x', yonetici: y),
            ReklamKarti(key: const ValueKey('b'), anahtar: 'x', yonetici: y),
          ])));
      await t.pumpWidget(iki());
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(s.yukleSayisi, 1);
      expect(_sahteReklam, findsOneWidget);
      // birincisi (reklamı gösteren) kalkar: ikincisi devralır
      await t.pumpWidget(iki(ilk: false));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(_sahteReklam, findsOneWidget);
      expect(s.yukleSayisi, 1);
      await t.pumpWidget(const SizedBox());
      y.dispose();
      expect(s.acikReklam, 0);
    });

    testWidgets('erişilebilirlik: "Reklam" etiketi, kontrast kuralları',
        (t) async {
      final handle = t.ensureSemantics();
      final y = _yonetici(SahteReklamServisi());
      await _kartAc(t, y);
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('Reklam'), findsOneWidget);
      await expectLater(t, meetsGuideline(textContrastGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await t.pumpWidget(const SizedBox());
      y.dispose();
      handle.dispose();
    });

    testWidgets(
        'hareket azaltma açıkken kart anında açılır; kapalıyken yumuşakça',
        (t) async {
      final y = _yonetici(SahteReklamServisi());
      await _kartAc(t, y, hareketKapali: true);
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 50)); // yükleme biter
      await t.pump(const Duration(milliseconds: 16)); // kartı çizen kare
      final tam = _kartYuksekligi(t);
      expect(tam, greaterThan(90));
      await t.pumpWidget(const SizedBox());

      final y2 = _yonetici(SahteReklamServisi());
      await _kartAc(t, y2);
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(milliseconds: 60));
      expect(_kartYuksekligi(t), lessThan(tam)); // hâlâ açılıyor
      await t.pumpAndSettle();
      expect(_kartYuksekligi(t), tam);
      await t.pumpWidget(const SizedBox());
      y.dispose();
      y2.dispose();
    });

    testWidgets('tema değişince reklam yeni görünümle bir kez daha yüklenir',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _kartAc(t, y);
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      expect(s.yukleSayisi, 1);
      await _kartAc(t, y, tema: TemaAyari().tema(Brightness.dark));
      await t.pump(const Duration(milliseconds: 400)); // tema geçişi biter
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(s.yukleSayisi, 2);
      expect(t.takeException(), isNull);
      expect(_sahteReklam, findsOneWidget);
      await t.pumpWidget(const SizedBox());
      y.dispose();
      expect(s.acikReklam, 0);
    });
  });

  group('ana ekranda', () {
    Future<void> bekle(WidgetTester t) async {
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
    }

    testWidgets('reklam öğün kartının altında, "Öğün yorumları"ndan önce çıkar',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _anaAc(t, y);
      expect(_sahteReklam, findsNothing); // ilk saniyelerde yok
      await bekle(t);
      expect(_sahteReklam, findsOneWidget);
      expect(s.yukleSayisi, 1);
      final kart = t.getBottomLeft(find.text('Pirinç Pilavı')).dy;
      final reklam = t.getTopLeft(_sahteReklam).dy;
      final yorum = t.getTopLeft(find.text('Öğün yorumları')).dy;
      expect(reklam, greaterThan(kart));
      expect(yorum, greaterThan(t.getBottomLeft(_sahteReklam).dy));
      // reklam ile yorum bölümü arasında boşluk var
      expect(
          yorum - t.getBottomLeft(_sahteReklam).dy, greaterThanOrEqualTo(16));
      expect(find.byType(ReklamKarti), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('kapalı reklamda ana ekran aynı ve hiç çağrı yok', (t) async {
      final s = SahteReklamServisi(kullanilabilir: false);
      final y = _yonetici(s);
      await _anaAc(t, y);
      await bekle(t);
      expect(s.hazirlaSayisi + s.yukleSayisi, 0);
      expect(_sahteReklam, findsNothing);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('ilk açılışta (3 gün kuralı) reklam yok ve tarih kaydedilir',
        (t) async {
      SharedPreferences.setMockInitialValues({});
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _anaAc(t, y);
      await bekle(t);
      expect(s.hazirlaSayisi + s.yukleSayisi, 0);
      expect(_sahteReklam, findsNothing);
      expect(
          (await SharedPreferences.getInstance()).getString(ilkAcilisAnahtari),
          '2026-11-02');
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('yemek yok / tatil gününde ve iskeletteyken reklam yok',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      final depo = _Depo(_menu())..kapi = Completer<void>();
      await _anaAc(t, y, depo: depo, bekle: false);
      // menü gelmedi: iskelet
      await t.pump(const Duration(seconds: 3));
      expect(find.byType(IskeletGovde), findsOneWidget);
      expect(find.byType(ReklamKarti), findsNothing);
      depo.kapi!.complete();
      await t.pumpAndSettle();
      // tatil günü
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(find.text('Tatil'), findsWidgets);
      expect(find.byType(ReklamKarti), findsNothing);
      await bekle(t);
      expect(_sahteReklam, findsNothing);
      expect(s.yukleSayisi, 0);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('gün geçişinde (A-B-A hızlı) istisna yok, reklam tek yerde',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _anaAc(t, y);
      await bekle(t);
      expect(_sahteReklam, findsOneWidget);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pump(const Duration(milliseconds: 80));
      await t.tap(find.byTooltip('Önceki gün'));
      await t.pump(const Duration(milliseconds: 80));
      expect(t.takeException(), isNull);
      await t.pumpAndSettle();
      await bekle(t);
      expect(t.takeException(), isNull);
      expect(_sahteReklam, findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      y.dispose();
      expect(s.acikReklam, 0);
    });

    testWidgets('gün gezerken 2 sn dolmadan istek atılmaz', (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _anaAc(t, y);
      Future<void> git(String ok) async {
        await t.tap(find.byTooltip(ok));
        await t.pump(); // geçiş animasyonu bu karede başlar
        await t.pump(const Duration(milliseconds: 900));
      }

      // her günde 2 sn'den az kalınır: hiçbir gün için istek atılmaz
      await git('Sonraki gün');
      await git('Sonraki gün');
      await git('Önceki gün');
      expect(s.yukleSayisi, 0);
      // son günde 2 sn kalınca tek istek atılır
      await bekle(t);
      expect(s.yukleSayisi, 1);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets(
        'öğün değişince (öğle -> akşam) yeni gün+öğün için yeniden yüklenir',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _anaAc(t, y);
      await bekle(t);
      await t.tap(find.text('Akşam'));
      await t.pumpAndSettle();
      await bekle(t);
      expect(s.yukleSayisi, 2);
      expect(_sahteReklam, findsOneWidget);
      // öğleye dönülünce bellekteki reklam kullanılır: yeni istek yok
      await t.tap(find.text('Öğle'));
      await t.pumpAndSettle();
      await bekle(t);
      expect(s.yukleSayisi, 2);
      expect(_sahteReklam, findsOneWidget);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('diğer ekranlarda (favoriler, arama) reklam kartı yok',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _anaAc(t, y);
      await t.tap(find.byTooltip('Favoriler'));
      await t.pumpAndSettle();
      expect(find.byType(ReklamKarti), findsNothing);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Yemek ara'));
      await t.pumpAndSettle();
      expect(find.byType(ReklamKarti), findsNothing);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('320x640 ve 1.5x yazıda taşma yok (reklam açıkken)', (t) async {
      final y = _yonetici(SahteReklamServisi());
      await _anaAc(t, y, boyut: const Size(320, 640), yazi: 1.5);
      // küçük ekranda reklam alanı ekranın altında kalır; liste öğesi ekrana yaklaşınca kurulur (kaydırılmadan
      // görünmesi gerekmez): sona kaydırıp bekleyince açılır
      await t.dragUntilVisible(
          find.text('Öğün yorumları'), _kartListesi, const Offset(0, -80));
      await t.pumpAndSettle();
      await bekle(t);
      expect(_sahteReklam, findsOneWidget);
      expect(t.takeException(), isNull);
      await t.drag(_kartListesi, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });
  });

  group('Ayarlar > Reklam tercihleri', () {
    Future<void> ac(WidgetTester t, ReklamYoneticisi? y) async {
      final ayar = TemaAyari();
      await t.pumpWidget(MaterialApp(
          theme: ayar.tema(Brightness.light),
          home: AyarlarSayfasi(
              temaAyari: ayar,
              depo: Depo(),
              uniler: const [],
              uni: null,
              reklam: y,
              menuyuYenile: () async {})));
      await t.pumpAndSettle();
    }

    testWidgets('rıza kuralı gerektiriyorsa satır çıkar ve formu açar',
        (t) async {
      final s = SahteReklamServisi(tercih: true);
      final y = _yonetici(s);
      await ac(t, y);
      await t.scrollUntilVisible(find.text('Reklam tercihleri'), 200,
          scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Reklam tercihleri'));
      await t.pump();
      expect(s.tercihAcSayisi, 1);
      y.dispose();
    });

    testWidgets('UMP durumu Ayarlar açıkken değişirse satır sonradan çıkar',
        (t) async {
      final s = SahteReklamServisi(tercih: false);
      final y = _yonetici(s);
      await ac(t, y);
      await t.scrollUntilVisible(find.text('Açık kaynak lisansları'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Reklam tercihleri'), findsNothing);
      // rıza bilgisi sonradan güncellendi ve gerekli çıktı
      s.tercih = true;
      await y.iste('a', _stil());
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Reklam tercihleri'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Reklam tercihleri'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      y.dispose();
    });

    testWidgets('gerekmiyorsa ya da reklam yoksa satır görünmez', (t) async {
      final y = _yonetici(SahteReklamServisi());
      await ac(t, y);
      await t.scrollUntilVisible(find.text('Açık kaynak lisansları'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Reklam tercihleri'), findsNothing);
      y.dispose();
      await ac(t, null);
      expect(find.text('Reklam tercihleri'), findsNothing);
    });
  });
}

class _Bozuk implements ReklamServisi {
  @override
  bool get kullanilabilir => true;
  @override
  Future<bool> hazirla() => throw StateError('hazirla');
  @override
  Future<ReklamNesnesi?> yukle(ReklamStili stil) => throw StateError('yukle');
  @override
  Future<bool> tercihGerekli() => throw StateError('tercih');
  @override
  Future<void> tercihleriAc() => throw StateError('ac');
}

/// Her kurulan alt ağaç durumunu sayan sahte servis (AdWidget'ın initState'ini taklit eder).
class _SayacliServis extends SahteReklamServisi {
  int kurulan = 0;
  @override
  Future<ReklamNesnesi?> yukle(ReklamStili stil) async {
    yukleSayisi++;
    return _SayacliNesne(this);
  }
}

class _SayacliNesne implements ReklamNesnesi {
  _SayacliNesne(this.servis);
  final _SayacliServis servis;
  @override
  Widget olustur(BuildContext context) => _Prob(servis);
  @override
  void dispose() {}
}

class _Prob extends StatefulWidget {
  const _Prob(this.servis);
  final _SayacliServis servis;
  @override
  State<_Prob> createState() => _ProbState();
}

class _ProbState extends State<_Prob> {
  @override
  void initState() {
    super.initState();
    widget.servis.kurulan++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 91);
}
