// Reklam v2: yerleşimler (ana / hafta / arama / detay), tema bağlı görünüm, ödüllü "Reklamsız gün", uzaktan ayar.
// Gerçek SDK / platform kanalı kullanılmaz; SahteReklamServisi çağrıları sayar.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/paylasim.dart';
import 'package:yemekhane/reklam/gercek_reklam_servisi.dart';
import 'package:yemekhane/reklam/reklam_ayari.dart';
import 'package:yemekhane/reklam/reklam_karti.dart';
import 'package:yemekhane/reklam/reklam_servisi.dart';
import 'package:yemekhane/reklam/reklam_yoneticisi.dart';
import 'package:yemekhane/reklam/reklamsiz_gun.dart';
import 'package:yemekhane/reklam/sahte_reklam_servisi.dart';
import 'package:yemekhane/reklam/uzak_ayar.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/screens/hafta.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/yemek_ara.dart';
import 'package:yemekhane/screens/yemek_detay.dart';
import 'package:yemekhane/tema.dart';

// ---- ortak yardımcılar -----------------------------------------------------------------------------------------

/// Pazartesi 2 Kasım 2026, 10:00 (Türkiye duvar saati).
DateTime _sabah() => DateTime.utc(2026, 11, 2, 10, 0);

/// Nezaket süresi çoktan bitmiş bir ilk açılış kaydı.
const _eskiKayit = {ilkAcilisAnahtari: '2026-10-20'};

Finder get _sahteReklam => find.byWidgetPredicate((w) =>
    w.key is ValueKey<String> &&
    (w.key! as ValueKey<String>).value.startsWith('sahte-reklam-'));

Finder get _odulluDugme => find.text('Reklamları 24 saat kapat');

ReklamStili _stil({bool buyuk = false}) =>
    ReklamStili.temadan(TemaAyari().tema(Brightness.light), buyuk: buyuk);

ReklamYoneticisi _yonetici(SahteReklamServisi s,
        {DateTime Function()? simdi,
        Future<UzakReklamAyari> Function()? ayar}) =>
    ReklamYoneticisi(servis: s, simdi: simdi ?? _sabah, ayarGetir: ayar);

Universite _uni() => Universite(
    id: 'ankara',
    ad: 'Ankara Üniversitesi',
    kisa: 'AÜ',
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch', 'dinner'],
    fiyatlar: const []);

class _Depo extends Depo {
  _Depo(this.menuVeri);
  final Menu menuVeri;
  @override
  Future<List<Universite>> universiteler() async => [_uni()];
  @override
  Future<Menu> menu(String id) async => menuVeri;
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
  @override
  Future<UzakReklamAyari> reklamAyari() async => UzakReklamAyari.varsayilan;
}

class _SahtePaylasim implements PaylasimServisi {
  @override
  Future<void> paylas(String metin, {String? konu}) async {}
}

/// 2 - 8 Kasım haftasının her günü öğle yemeği olan menü.
Menu _haftaMenusu() => Menu('ankara', null, {
      for (var d = 2; d <= 8; d++)
        '2026-11-${d.toString().padLeft(2, '0')}': {
          'lunch': Ogun([
            YemekOgesi('Mercimek Çorbası $d', 120),
            YemekOgesi('Pirinç Pilavı', 300),
          ], 420),
        },
    });

Future<void> _bekle(WidgetTester t, {int kez = 1}) async {
  for (var i = 0; i < kez; i++) {
    await t.pump(const Duration(milliseconds: 2100));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  await t.pumpAndSettle();
}

Widget _uygulama(Widget home,
        {double yazi = 1.0, Brightness parlaklik = Brightness.light}) =>
    MaterialApp(
      theme: TemaAyari().tema(parlaklik),
      builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(yazi)),
          child: w!),
      home: home,
    );

void _boyut(WidgetTester t, Size boyut) {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _anaAc(WidgetTester t, ReklamYoneticisi y,
    {Size boyut = const Size(400, 1400), double yazi = 1.0}) async {
  _boyut(t, boyut);
  final ayar = TemaAyari();
  await t.pumpWidget(MaterialApp(
    theme: ayar.tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(yazi)),
        child: w!),
    home: AnaSayfa(
        temaAyari: ayar,
        depo: _Depo(Menu('ankara', null, {
          '2026-11-02': {
            'lunch': Ogun([
              YemekOgesi('Mercimek Çorbası', 120),
              YemekOgesi('Pirinç Pilavı', 300),
            ], 420),
          },
        })),
        geriBildirim: YerelDepo(),
        simdi: _sabah,
        reklam: y),
  ));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(_eskiKayit));

  // ---------------------------------------------------------------------------------------------------------------
  group('uzaktan ayar (UzakReklamAyari)', () {
    test(
        'varsayılanlar: açık, 2 gün lütuf, oturumda 20, tüm yerleşimler, büyük ana, ödüllü',
        () {
      const a = UzakReklamAyari.varsayilan;
      expect(a.aktif, isTrue);
      expect(a.lutufGun, 2);
      expect(a.oturumSiniri, 20);
      expect(a.anaBuyuk, isTrue);
      expect(a.odullu, isTrue);
      for (final y in reklamYerlesimleri) {
        expect(a.yerlesimAcik(y), isTrue, reason: y);
      }
      expect(reklamsizGunSayisi, 2);
    });

    test('her alan okunur (kök "reklam" nesnesi)', () {
      final a = UzakReklamAyari.fromJson(jsonDecode('''
        {"reklam": {"aktif": false, "lutufGun": 5, "oturumSiniri": 7,
         "yerlesimler": {"ana": false, "hafta": true, "arama": false, "detay": true},
         "anaBuyuk": false, "odullu": false}, "updated": "x"}'''));
      expect(a.aktif, isFalse);
      expect(a.lutufGun, 5);
      expect(a.oturumSiniri, 7);
      expect(a.yerlesimAcik('ana'), isFalse);
      expect(a.yerlesimAcik('hafta'), isTrue);
      expect(a.yerlesimAcik('arama'), isFalse);
      expect(a.yerlesimAcik('detay'), isTrue);
      expect(a.anaBuyuk, isFalse);
      expect(a.odullu, isFalse);
    });

    test('doğrudan "reklam" nesnesi de çözülür; belirtilmeyen yerleşim açık',
        () {
      final a = UzakReklamAyari.fromJson({
        'aktif': true,
        'yerlesimler': {'hafta': false}
      });
      expect(a.yerlesimAcik('hafta'), isFalse);
      expect(a.yerlesimAcik('ana'), isTrue);
      expect(a.yerlesimAcik('bilinmeyen'), isTrue);
    });

    test('bozuk, eksik ve yanlış türlü alanlar varsayılana düşer, hata atmaz',
        () {
      const v = UzakReklamAyari.varsayilan;
      for (final j in <Object?>[
        null,
        'metin',
        5,
        <Object?>[],
        <String, Object?>{},
        {'reklam': 'x'},
        {'reklam': null},
        {'reklam': []},
      ]) {
        final a = UzakReklamAyari.fromJson(j);
        expect(a.aktif, v.aktif, reason: '$j');
        expect(a.lutufGun, v.lutufGun, reason: '$j');
        expect(a.oturumSiniri, v.oturumSiniri, reason: '$j');
      }
      final a = UzakReklamAyari.fromJson({
        'reklam': {
          'aktif': 'hayır',
          'lutufGun': 'iki',
          'oturumSiniri': -4,
          'yerlesimler': [1, 2],
          'anaBuyuk': 3,
          'odullu': null
        }
      });
      expect(a.aktif, isTrue);
      expect(a.lutufGun, 2);
      expect(a.oturumSiniri, 20);
      expect(a.yerlesimAcik('ana'), isTrue);
      expect(a.anaBuyuk, isTrue);
      expect(a.odullu, isTrue);
      // aralık dışı sayılar
      expect(
          UzakReklamAyari.fromJson({
            'reklam': {'lutufGun': 99, 'oturumSiniri': 100000}
          }).lutufGun,
          2);
      expect(
          UzakReklamAyari.fromJson({
            'reklam': {'lutufGun': 0, 'oturumSiniri': 0}
          }).lutufGun,
          0);
      expect(
          UzakReklamAyari.fromJson({
            'reklam': {'lutufGun': 3.0}
          }).lutufGun,
          3);
    });

    test('depo: ağdan gelen ayar okunur', () async {
      final d = Depo(
          istemci: MockClient((r) async => http.Response(
              jsonEncode({
                'reklam': {'aktif': false, 'lutufGun': 4}
              }),
              200)));
      final a = await d.reklamAyari();
      expect(a.aktif, isFalse);
      expect(a.lutufGun, 4);
    });

    test('depo: ağ bozuk ya da 404 ise paket kopyası, o da yoksa varsayılan',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final bozuk =
          Depo(istemci: MockClient((r) async => http.Response('{bozuk', 200)));
      // bozuk gövde önbelleğe yazılmaz; paketteki ayarlar.json (aktif: true) kullanılır
      final a = await bozuk.reklamAyari();
      expect(a.aktif, isTrue);
      expect(a.lutufGun, 2);
      final hata = Depo(
          istemci: MockClient((r) async => throw const SocketException('x')));
      expect((await hata.reklamAyari()).oturumSiniri, 20);
    });

    test(
        'paketteki ve depodaki ayarlar.json geçerli, aynı ve varsayılanla uyumlu',
        () {
      final paket = File('assets/data/ayarlar.json').readAsStringSync();
      final depo = File('../data/ayarlar.json').readAsStringSync();
      expect(jsonDecode(paket), jsonDecode(depo));
      final j = jsonDecode(paket) as Map;
      expect(j['updated'], isA<String>());
      final a = UzakReklamAyari.fromJson(j);
      expect(a.aktif, isTrue);
      expect(a.lutufGun, 2);
      expect(a.oturumSiniri, 20);
      expect(a.anaBuyuk, isTrue);
      expect(a.odullu, isTrue);
      for (final y in reklamYerlesimleri) {
        expect((j['reklam'] as Map)['yerlesimler'][y], isTrue, reason: y);
      }
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('yönetici: uzaktan ayar kararları', () {
    test('aktif=false: SDK hiç başlatılmaz, istek yok', () async {
      final s = SahteReklamServisi();
      final y =
          _yonetici(s, ayar: () async => const UzakReklamAyari(aktif: false));
      expect(await y.gosterilebilir(yerlesim: 'ana'), isFalse);
      expect(y.acik, isFalse);
      expect(await y.iste('a', _stil()), isNull);
      expect(s.hazirlaSayisi, 0);
      expect(s.yukleSayisi, 0);
      y.dispose();
    });

    test('kapalı yerleşim: yalnız o yerleşim gösterilmez', () async {
      final s = SahteReklamServisi();
      final y = _yonetici(s,
          ayar: () async => const UzakReklamAyari(
              yerlesimler: {'hafta': false, 'detay': false}));
      expect(await y.gosterilebilir(yerlesim: 'hafta'), isFalse);
      expect(await y.gosterilebilir(yerlesim: 'detay'), isFalse);
      expect(await y.gosterilebilir(yerlesim: 'ana'), isTrue);
      expect(await y.gosterilebilir(yerlesim: 'arama'), isTrue);
      expect(s.hazirlaSayisi, 0, reason: 'gosterilebilir istek atmaz');
      y.dispose();
    });

    test('ayar okunamazsa (hata) güvenli varsayılan: reklam açık', () async {
      final y = _yonetici(SahteReklamServisi(),
          ayar: () async => throw StateError('ağ'));
      expect(await y.gosterilebilir(yerlesim: 'ana'), isTrue);
      expect(y.ayar.aktif, isTrue);
      y.dispose();
    });

    test('ayarGetir yoksa varsayılan', () async {
      final y = _yonetici(SahteReklamServisi());
      expect(await y.gosterilebilir(yerlesim: 'ana'), isTrue);
      expect(y.oturumSiniri, 20);
      y.dispose();
    });

    test('oturumSiniri uzaktan gelir; yapıcıdaki değer onu ezer', () async {
      final s = SahteReklamServisi();
      final y = _yonetici(s,
          ayar: () async => const UzakReklamAyari(oturumSiniri: 2));
      await y.gosterilebilir();
      expect(y.oturumSiniri, 2);
      expect(await y.iste('a', _stil()), isNotNull);
      expect(await y.iste('b', _stil()), isNotNull);
      expect(await y.iste('c', _stil()), isNull);
      expect(s.yukleSayisi, 2);
      y.dispose();
      final z = ReklamYoneticisi(
          servis: SahteReklamServisi(),
          oturumSiniri: 5,
          ayarGetir: () async => const UzakReklamAyari(oturumSiniri: 2));
      await z.gosterilebilir();
      expect(z.oturumSiniri, 5);
      z.dispose();
    });

    test('lütuf: ilk gün + 2 gün reklamsız (sınırlar)', () async {
      Future<bool> dene(DateTime an, {int? lutuf}) async {
        SharedPreferences.setMockInitialValues(
            {ilkAcilisAnahtari: '2026-10-30'});
        final y = _yonetici(SahteReklamServisi(),
            simdi: () => an,
            ayar: lutuf == null
                ? null
                : () async => UzakReklamAyari(lutufGun: lutuf));
        final r = await y.gosterilebilir();
        y.dispose();
        return r;
      }

      expect(await dene(DateTime.utc(2026, 10, 30, 9)), isFalse);
      expect(await dene(DateTime.utc(2026, 10, 31, 23, 59)), isFalse);
      expect(await dene(DateTime.utc(2026, 11, 1, 23, 59)), isFalse);
      expect(await dene(DateTime.utc(2026, 11, 2, 0, 1)), isTrue);
      // uzaktan değiştirilen lütuf: 5 gün
      expect(await dene(DateTime.utc(2026, 11, 3), lutuf: 5), isFalse);
      expect(await dene(DateTime.utc(2026, 11, 4, 12), lutuf: 5), isFalse);
      expect(await dene(DateTime.utc(2026, 11, 5, 0, 1), lutuf: 5), isTrue);
      // 0 gün: ertesi gün başlar, ilk gün yine reklamsız
      expect(await dene(DateTime.utc(2026, 10, 30, 23), lutuf: 0), isFalse);
      expect(await dene(DateTime.utc(2026, 10, 31, 1), lutuf: 0), isTrue);
    });

    test('ilk açılış gününde uzaktan ayar bile istenmez', () async {
      SharedPreferences.setMockInitialValues({});
      var istek = 0;
      final y = _yonetici(SahteReklamServisi(), ayar: () async {
        istek++;
        return UzakReklamAyari.varsayilan;
      });
      expect(await y.gosterilebilir(), isFalse);
      await y.ayarYukle();
      expect(istek, 0);
      y.dispose();
    });

    test('kapalı servis (web / kimliksiz release): ayar dosyası istenmez',
        () async {
      var istek = 0;
      final y =
          _yonetici(SahteReklamServisi(kullanilabilir: false), ayar: () async {
        istek++;
        return UzakReklamAyari.varsayilan;
      });
      await y.baslat();
      await y.ayarYukle();
      expect(await y.gosterilebilir(), isFalse);
      expect(istek, 0);
      y.dispose();
    });

    test('ayar bir kez istenir', () async {
      var istek = 0;
      final y = _yonetici(SahteReklamServisi(), ayar: () async {
        istek++;
        return UzakReklamAyari.varsayilan;
      });
      await y.gosterilebilir();
      await y.gosterilebilir(yerlesim: 'hafta');
      await y.ayarYukle();
      expect(istek, 1);
      y.dispose();
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('birim kimliği: ödüllü', () {
    String? sec(
            {String a = '',
            String i = '',
            bool web = false,
            TargetPlatform p = TargetPlatform.android,
            bool surum = false}) =>
        odulluBirimiSec(
            androidTanimli: a,
            iosTanimli: i,
            web: web,
            platform: p,
            surum: surum);

    test('kimlik yok: debug/profile Google ödüllü test birimi, release gizli',
        () {
      expect(sec(), 'ca-app-pub-3940256099942544/5224354917');
      expect(sec(p: TargetPlatform.iOS), testOdulluIos);
      expect(sec(surum: true), isNull);
      expect(sec(p: TargetPlatform.iOS, surum: true), isNull);
      expect(sec(a: '   ', surum: true), isNull);
    });

    test(
        'kimlik verilince her derlemede o; platforma göre; web ve diğerlerinde yok',
        () {
      expect(sec(a: 'ca-app-pub-1/2', surum: true), 'ca-app-pub-1/2');
      expect(sec(i: 'ca-app-pub-3/4', p: TargetPlatform.iOS, surum: true),
          'ca-app-pub-3/4');
      expect(
          sec(a: 'ca-app-pub-1/2', p: TargetPlatform.iOS, surum: true), isNull);
      expect(sec(a: 'x', web: true), isNull);
      expect(sec(p: TargetPlatform.windows), isNull);
    });

    test('yerel reklam kuralı değişmedi (test birimi hâlâ yerel)', () {
      expect(
          reklamBirimiSec(
              androidTanimli: '',
              iosTanimli: '',
              web: false,
              platform: TargetPlatform.android,
              surum: false),
          testBirimAndroid);
      expect(testBirimAndroid, isNot(testOdulluAndroid));
    });

    test('release derlemede kimliksiz dart-define boş: ödüllü gizli', () {
      expect(admobOdulluAndroid, isEmpty);
      expect(admobOdulluIos, isEmpty);
    });

    test('gerçek servis: ödüllü yalnızca reklam VE ödüllü birim varsa mümkün',
        () {
      expect(
          GercekReklamServisi.birimle('a', 'b').odulluKullanilabilir, isTrue);
      expect(GercekReklamServisi.birimle('a').odulluKullanilabilir, isFalse);
      expect(
          GercekReklamServisi.birimle(null, 'b').odulluKullanilabilir, isFalse);
      expect(const KapaliReklamServisi().odulluKullanilabilir, isFalse);
    });

    test(
        'gerçek servis: ödüllü birim yoksa platforma dokunmadan yüklenemedi döner',
        () async {
      expect(await GercekReklamServisi.birimle('a').odulluIzle(),
          OdulluSonuc.yuklenemedi);
      expect(await const KapaliReklamServisi().odulluIzle(),
          OdulluSonuc.yuklenemedi);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('Reklamsız gün (yönetici)', () {
    test(
        'ödül gelince 24 saat reklam yok, kayıt saklanır, kartlar belleği boşaltır',
        () async {
      final s = SahteReklamServisi();
      var an = _sabah();
      final y = _yonetici(s, simdi: () => an);
      await y.baslat();
      expect(y.odulluAcik, isTrue);
      await y.iste('a', _stil());
      expect(y.onbellekAdedi, 1);
      expect(await y.odulluIzle(), OdulluSonuc.odul);
      expect(s.odulluSayisi, 1);
      expect(y.reklamsizMi, isTrue);
      expect(y.reklamsizBitis, DateTime.utc(2026, 11, 3, 10, 0));
      expect(y.odulluAcik, isFalse, reason: 'zaten reklamsızken düğme gizli');
      expect(y.onbellekAdedi, 0, reason: 'bellekteki reklamlar bırakıldı');
      expect(s.acikReklam, 0);
      expect(await y.iste('b', _stil()), isNull);
      expect(await y.gosterilebilir(), isFalse);
      expect(y.yerlesimIzinli('ana'), isFalse);
      final p = await SharedPreferences.getInstance();
      expect(DateTime.parse(p.getString(reklamsizBitisAnahtari)!),
          DateTime.utc(2026, 11, 3, 10, 0));
      // süre dolmadan 1 dakika önce hâlâ reklamsız, dolunca reklamlar geri gelir
      an = DateTime.utc(2026, 11, 3, 9, 59);
      expect(y.reklamsizMi, isTrue);
      an = DateTime.utc(2026, 11, 3, 10, 0);
      expect(y.reklamsizMi, isFalse);
      expect(y.reklamsizBitis, isNull);
      expect(y.odulluAcik, isTrue);
      expect(await y.gosterilebilir(), isTrue);
      expect(await y.iste('c', _stil()), isNotNull);
      y.dispose();
    });

    test('ödül yokken hiçbir şey değişmez: kapatıldı ve yüklenemedi', () async {
      for (final sonuc in [OdulluSonuc.kapatildi, OdulluSonuc.yuklenemedi]) {
        final s = SahteReklamServisi()..odulluSonucu = sonuc;
        final y = _yonetici(s);
        await y.baslat();
        expect(await y.odulluIzle(), sonuc);
        expect(y.reklamsizMi, isFalse);
        expect(y.odulluAcik, isTrue);
        expect(
            (await SharedPreferences.getInstance())
                .getString(reklamsizBitisAnahtari),
            isNull);
        y.dispose();
      }
    });

    test('rıza yoksa ödüllü izlenmez', () async {
      final s = SahteReklamServisi(rizaVar: false);
      final y = _yonetici(s);
      await y.baslat();
      expect(await y.odulluIzle(), OdulluSonuc.yuklenemedi);
      expect(s.odulluSayisi, 0);
      y.dispose();
    });

    test(
        'kayıtlı süre uygulama açılınca okunur; geçmiş, bozuk ve uzak gelecek geçersiz',
        () async {
      Future<bool> dene(Object? kayit) async {
        SharedPreferences.setMockInitialValues(
            {..._eskiKayit, if (kayit != null) reklamsizBitisAnahtari: kayit});
        final y = _yonetici(SahteReklamServisi());
        await y.baslat();
        final r = y.reklamsizMi;
        y.dispose();
        return r;
      }

      expect(await dene(DateTime.utc(2026, 11, 2, 14, 30).toIso8601String()),
          isTrue);
      expect(await dene(DateTime.utc(2026, 11, 2, 9, 0).toIso8601String()),
          isFalse);
      expect(await dene('bozuk'), isFalse);
      expect(await dene(12345), isFalse);
      expect(await dene(null), isFalse);
      // saati ileri oynayarak uydurulmuş 24 saatten uzak kayıt
      expect(await dene(DateTime.utc(2027, 1, 1).toIso8601String()), isFalse);
    });

    test('uzaktan odullu=false: özellik gizli', () async {
      final y = _yonetici(SahteReklamServisi(),
          ayar: () async => const UzakReklamAyari(odullu: false));
      await y.gosterilebilir();
      expect(y.odulluAcik, isFalse);
      expect(await y.odulluIzle(), OdulluSonuc.yuklenemedi);
      y.dispose();
    });

    test('ödüllü birim yoksa (kimliksiz release) özellik gizli', () async {
      final y = _yonetici(SahteReklamServisi(odulluVar: false));
      await y.baslat();
      expect(y.odulluAcik, isFalse);
      y.dispose();
    });

    test('yeni kullanıcı nezaket süresindeyken öneri yok', () async {
      SharedPreferences.setMockInitialValues({});
      final y = _yonetici(SahteReklamServisi());
      await y.baslat();
      expect(y.lutufBitti, isFalse);
      expect(y.odulluAcik, isFalse);
      y.dispose();
    });

    test('kalan süre metni', () {
      final simdi = DateTime.utc(2026, 11, 2, 10, 0);
      expect(reklamsizKalanMetni(DateTime.utc(2026, 11, 2, 14, 30), simdi),
          "Reklamsız: 14:30'a kadar");
      expect(reklamsizKalanMetni(DateTime.utc(2026, 11, 3, 9, 5), simdi),
          "Reklamsız: yarın 09:05'a kadar");
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('ReklamKarti: tasarım ve ödüllü akış', () {
    Future<void> kartAc(WidgetTester t, ReklamYoneticisi y,
        {double yazi = 1.0,
        Size boyut = const Size(400, 800),
        ThemeData? tema,
        bool buyuk = false}) async {
      _boyut(t, boyut);
      await t.pumpWidget(MaterialApp(
        theme: tema ?? TemaAyari().tema(Brightness.light),
        builder: (c, w) => MediaQuery(
            data:
                MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(yazi)),
            child: w!),
        home: Scaffold(
            body: ListView(children: [
          const Text('üst'),
          ReklamKarti(anahtar: 'k', yonetici: y, buyukOlabilir: buyuk),
          const Text('alt'),
        ])),
      ));
      await y.baslat();
      await _bekle(t);
    }

    testWidgets(
        'Reklam çipi, açıklama ve ödüllü düğme görünür; etiketler ve 48 dp',
        (t) async {
      final y = _yonetici(SahteReklamServisi());
      final sem = t.ensureSemantics();
      await kartAc(t, y);
      expect(_sahteReklam, findsOneWidget);
      expect(find.text('Reklam'), findsOneWidget);
      expect(find.text("Üni Yemek'i ücretsiz tutar"), findsOneWidget);
      expect(find.bySemanticsLabel('Reklam'), findsWidgets);
      expect(_odulluDugme, findsOneWidget);
      final dugme =
          find.ancestor(of: _odulluDugme, matching: find.byType(TextButton));
      expect(t.getSize(dugme).height, greaterThanOrEqualTo(48));
      expect(t.getSize(dugme).width, greaterThanOrEqualTo(48));
      // komşu dokunulabilir öğelerle en az 16 dp: kartın üstü ve altı (kart = ilk Container)
      final kart = t.getRect(find
          .descendant(
              of: find.byType(ReklamKarti), matching: find.byType(Container))
          .first);
      final ust = t.getRect(find.text('üst')),
          alt = t.getRect(find.text('alt'));
      expect(kart.top - ust.bottom, greaterThanOrEqualTo(16));
      expect(alt.top - kart.bottom, greaterThanOrEqualTo(16));
      sem.dispose();
      y.dispose();
    });

    testWidgets('ödüllü yok / kapalı ise düğme görünmez, reklam yine görünür',
        (t) async {
      final y = _yonetici(SahteReklamServisi(odulluVar: false));
      await kartAc(t, y);
      expect(_sahteReklam, findsOneWidget);
      expect(_odulluDugme, findsNothing);
      y.dispose();
    });

    testWidgets('düğme -> açıklama -> Vazgeç: hiçbir şey olmaz', (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await kartAc(t, y);
      await t.tap(_odulluDugme);
      await t.pumpAndSettle();
      expect(
          find.text(
              'Kısa bir reklam izle, 24 saat boyunca uygulamada reklam görme.'),
          findsOneWidget);
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(s.odulluSayisi, 0);
      expect(y.reklamsizMi, isFalse);
      expect(_sahteReklam, findsOneWidget);
      y.dispose();
    });

    testWidgets(
        'İzle -> ödül: tüm kartlar hemen gizlenir, süre dolunca geri gelir',
        (t) async {
      final s = SahteReklamServisi();
      var an = _sabah();
      final y = _yonetici(s, simdi: () => an);
      await kartAc(t, y);
      await t.tap(_odulluDugme);
      await t.pumpAndSettle();
      await t.tap(find.text('İzle'));
      await t.pumpAndSettle();
      expect(s.odulluSayisi, 1);
      expect(y.reklamsizMi, isTrue);
      expect(_sahteReklam, findsNothing);
      expect(_odulluDugme, findsNothing);
      expect(find.text('Reklamlar 24 saat kapalı.'), findsOneWidget);
      expect(s.acikReklam, 0, reason: 'gösterilmeyen reklam serbest bırakıldı');
      // 23 saat sonra hâlâ yok
      an = _sabah().add(const Duration(hours: 23));
      await t.pump(const Duration(hours: 23));
      expect(_sahteReklam, findsNothing);
      // süre dolunca zamanlayıcı kartları uyandırır; 2 sn sonra yeni reklam yüklenir
      an = _sabah().add(const Duration(hours: 24, minutes: 1));
      await t.pump(const Duration(hours: 1, minutes: 1));
      await _bekle(t);
      expect(y.reklamsizMi, isFalse);
      expect(_sahteReklam, findsOneWidget);
      y.dispose();
    });

    testWidgets('İzle -> reklam yüklenemedi: ileti çıkar, reklam ve süre aynı',
        (t) async {
      final s = SahteReklamServisi()..odulluSonucu = OdulluSonuc.yuklenemedi;
      final y = _yonetici(s);
      await kartAc(t, y);
      await t.tap(_odulluDugme);
      await t.pumpAndSettle();
      await t.tap(find.text('İzle'));
      await t.pumpAndSettle();
      expect(find.text('Şu an reklam yok, sonra tekrar dene.'), findsOneWidget);
      expect(y.reklamsizMi, isFalse);
      expect(_sahteReklam, findsOneWidget);
      y.dispose();
    });

    testWidgets('İzle -> ödül gelmeden kapatıldı: sessiz, hiçbir şey değişmez',
        (t) async {
      final s = SahteReklamServisi()..odulluSonucu = OdulluSonuc.kapatildi;
      final y = _yonetici(s);
      await kartAc(t, y);
      await t.tap(_odulluDugme);
      await t.pumpAndSettle();
      await t.tap(find.text('İzle'));
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(y.reklamsizMi, isFalse);
      expect(_sahteReklam, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      y.dispose();
    });

    testWidgets('yerleşim uzaktan kapalıysa kart hiç yer kaplamaz ve istek yok',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s,
          ayar: () async => const UzakReklamAyari(yerlesimler: {'ana': false}));
      await kartAc(t, y);
      expect(_sahteReklam, findsNothing);
      expect(s.yukleSayisi, 0);
      expect(s.hazirlaSayisi, 0);
      y.dispose();
    });

    testWidgets(
        'tema (renk ya da mod) değişince reklam yeniden kurulur, stil temadan gelir',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await kartAc(t, y);
      expect(s.yukleSayisi, 1);
      final acik = s.istenenStiller.last;
      final koyu = TemaAyari().tema(Brightness.dark);
      await kartAc(t, y, tema: koyu);
      await _bekle(t); // tema geçişi bitince son imza için bekleme
      expect(s.yukleSayisi, 2);
      final k = s.istenenStiller.last;
      expect(k.imza, isNot(acik.imza));
      expect(k.birincilYazi, koyu.colorScheme.onSurface);
      expect(k.ikincilYazi, koyu.colorScheme.onSurfaceVariant);
      expect(k.dugme, koyu.colorScheme.primary);
      expect(k.dugmeYazisi, koyu.colorScheme.onPrimary);
      expect(k.arkaPlan,
          koyu.cardTheme.color ?? koyu.colorScheme.surfaceContainerLow);
      expect(k.kose, 22);
      expect(_sahteReklam, findsOneWidget);
      y.dispose();
    });

    test('stil: yazı boyutları textTheme\'den, büyük/küçük imzası farklı', () {
      final tema = ThemeData(
          textTheme: const TextTheme(
              titleSmall: TextStyle(fontSize: 21),
              bodyMedium: TextStyle(fontSize: 17),
              bodySmall: TextStyle(fontSize: 11),
              labelLarge: TextStyle(fontSize: 19)));
      final st = ReklamStili.temadan(tema);
      expect(st.baslikBoyutu, 21);
      expect(st.govdeBoyutu, 17);
      expect(st.kucukBoyut, 11);
      expect(st.dugmeBoyutu, 19);
      expect(ReklamStili.temadan(tema, buyuk: true).imza, isNot(st.imza));
      expect(ReklamStili.temadan(tema, buyuk: true).buyuk, isTrue);
    });

    for (final boyut in [const Size(320, 640)]) {
      testWidgets('320x640, yazı 1.5x: taşma yok (ödüllü düğmeyle)', (t) async {
        final y = _yonetici(SahteReklamServisi());
        await kartAc(t, y, yazi: 1.5, boyut: boyut);
        expect(_sahteReklam, findsOneWidget);
        expect(_odulluDugme, findsOneWidget);
        expect(t.takeException(), isNull);
        y.dispose();
      });
    }
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('yerleşim: ana ekran (medium / small)', () {
    test('anaReklamBuyukMu eşikleri', () {
      expect(anaReklamBuyukMu(yukseklik: 700, yaziOlcegi: 1.3), isTrue);
      expect(anaReklamBuyukMu(yukseklik: 699.9, yaziOlcegi: 1.0), isFalse);
      expect(anaReklamBuyukMu(yukseklik: 900, yaziOlcegi: 1.31), isFalse);
      expect(anaReklamBuyukMu(yukseklik: 900, yaziOlcegi: 1.0, izinli: false),
          isFalse);
    });

    testWidgets('uzun ekran + normal yazı: görselli (medium) şablon istenir',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _anaAc(t, y);
      await _bekle(t);
      expect(_sahteReklam, findsOneWidget);
      expect(s.istenenStiller.last.buyuk, isTrue);
      y.dispose();
    });

    testWidgets('kısa ekran ya da büyük yazı: küçük şablon', (t) async {
      for (final (boyut, yazi) in [
        (const Size(400, 640), 1.0),
        (const Size(400, 1400), 1.5),
      ]) {
        final s = SahteReklamServisi();
        final y = _yonetici(s);
        await _anaAc(t, y, boyut: boyut, yazi: yazi);
        await _bekle(t);
        expect(_sahteReklam, findsOneWidget, reason: '$boyut $yazi');
        expect(s.istenenStiller.last.buyuk, isFalse, reason: '$boyut $yazi');
        await t.pumpWidget(const SizedBox());
        y.dispose();
      }
    });

    testWidgets('uzaktan anaBuyuk=false: uzun ekranda da küçük', (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s,
          ayar: () async => const UzakReklamAyari(anaBuyuk: false));
      await _anaAc(t, y);
      await _bekle(t, kez: 2);
      expect(_sahteReklam, findsOneWidget);
      expect(s.istenenStiller.last.buyuk, isFalse);
      y.dispose();
    });

    testWidgets('uzaktan ana=false: ana ekranda reklam yok', (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s,
          ayar: () async => const UzakReklamAyari(yerlesimler: {'ana': false}));
      await _anaAc(t, y);
      await _bekle(t, kez: 2);
      expect(_sahteReklam, findsNothing);
      expect(s.yukleSayisi, 0);
      y.dispose();
    });

    testWidgets('uzaktan aktif=false: SDK hiç başlatılmaz', (t) async {
      final s = SahteReklamServisi();
      final y =
          _yonetici(s, ayar: () async => const UzakReklamAyari(aktif: false));
      await _anaAc(t, y);
      await _bekle(t, kez: 2);
      expect(_sahteReklam, findsNothing);
      expect(s.hazirlaSayisi, 0);
      expect(s.yukleSayisi, 0);
      y.dispose();
    });

    testWidgets('320x640, yazı 1.5x: taşma yok (reklam ve düğmeyle)',
        (t) async {
      final y = _yonetici(SahteReklamServisi());
      await _anaAc(t, y, boyut: const Size(320, 640), yazi: 1.5);
      // küçük ekranda reklam alanı ekranın altında kalır; liste öğesi ekrana yaklaşınca kurulur
      await t.dragUntilVisible(
          find.text('Öğün yorumları'),
          find
              .descendant(
                  of: find.byType(OgunKarti), matching: find.byType(Scrollable))
              .first,
          const Offset(0, -80));
      await t.pumpAndSettle();
      await _bekle(t);
      expect(_sahteReklam, findsOneWidget);
      expect(t.takeException(), isNull);
      y.dispose();
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('yerleşim: haftalık menü', () {
    test('haftaReklamVarMi: 3. karttan sonra, en az 3 kart', () {
      expect(haftaReklamVarMi(7, 2), isTrue);
      expect(haftaReklamVarMi(7, 1), isFalse);
      expect(haftaReklamVarMi(7, 3), isFalse);
      expect(haftaReklamVarMi(3, 2), isTrue);
      expect(haftaReklamVarMi(2, 2), isFalse);
      expect(haftaReklamVarMi(0, 2), isFalse);
    });

    Future<void> haftaAc(WidgetTester t, ReklamYoneticisi? y,
        {double yazi = 1.0, Size boyut = const Size(400, 1800)}) async {
      _boyut(t, boyut);
      await t.pumpWidget(_uygulama(
          HaftaSayfasi(
              uni: _uni(),
              menu: _haftaMenusu(),
              bugun: '2026-11-04',
              tarih: '2026-11-04',
              ogun: 'lunch',
              paylasim: _SahtePaylasim(),
              reklam: y),
          yazi: yazi));
      await t.pumpAndSettle();
    }

    testWidgets(
        '3. gün kartından sonra tek küçük reklam; 2 sn beklemeden istek yok',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await haftaAc(t, y);
      expect(_sahteReklam, findsNothing);
      expect(s.yukleSayisi, 0);
      await _bekle(t);
      expect(_sahteReklam, findsOneWidget);
      expect(s.istenenStiller.last.buyuk, isFalse);
      // sıra: 3. kart (Çarşamba 4 Kasım) ile 4. kart (Perşembe 5 Kasım) arasında
      final y3 = t.getRect(find.textContaining('Mercimek Çorbası 4')).bottom;
      final r = t.getRect(_sahteReklam);
      final y4 = t.getRect(find.textContaining('Mercimek Çorbası 5')).top;
      expect(r.top, greaterThan(y3));
      expect(r.bottom, lessThan(y4));
      expect(find.byType(ReklamKarti), findsOneWidget);
      y.dispose();
    });

    testWidgets('reklam yok / kapalı / yüklenemezse sayfa aynı, yer kaplamaz',
        (t) async {
      await haftaAc(t, null);
      expect(find.byType(ReklamKarti), findsNothing);
      final s = SahteReklamServisi(basarili: false);
      final y = _yonetici(s);
      await haftaAc(t, y);
      await _bekle(t);
      expect(_sahteReklam, findsNothing);
      expect(t.getSize(find.byType(ReklamKarti)).height, 0);
      y.dispose();
      final k = SahteReklamServisi(kullanilabilir: false);
      final z = _yonetici(k);
      await haftaAc(t, z);
      await _bekle(t);
      expect(k.hazirlaSayisi + k.yukleSayisi, 0);
      z.dispose();
    });

    testWidgets(
        'uzaktan hafta=false: reklam yok; hafta değişince ikinci reklam çıkmaz',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s,
          ayar: () async =>
              const UzakReklamAyari(yerlesimler: {'hafta': false}));
      await haftaAc(t, y);
      await _bekle(t, kez: 2);
      expect(_sahteReklam, findsNothing);
      expect(s.yukleSayisi, 0);
      y.dispose();

      final s2 = SahteReklamServisi();
      final y2 = _yonetici(s2);
      await haftaAc(t, y2);
      await _bekle(t);
      await t.tap(find.byTooltip('Sonraki hafta'));
      await t.pump(const Duration(milliseconds: 100));
      expect(_sahteReklam.evaluate().length, lessThanOrEqualTo(1));
      await _bekle(t);
      expect(_sahteReklam.evaluate().length, lessThanOrEqualTo(1));
      y2.dispose();
    });

    testWidgets('320x640, yazı 1.5x: taşma yok', (t) async {
      final y = _yonetici(SahteReklamServisi());
      await haftaAc(t, y, yazi: 1.5, boyut: const Size(320, 640));
      await t.drag(find.byType(ListView), const Offset(0, -700));
      await t.pumpAndSettle();
      await _bekle(t);
      expect(_sahteReklam, findsOneWidget);
      expect(t.takeException(), isNull);
      y.dispose();
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('yerleşim: yemek arama', () {
    test('aramaReklamSirasi: 5. sonuçtan sonra, en az 8 sonuç', () {
      // başlık, 3 sonuç, başlık, 6 sonuç
      final satirlar = [
        false, true, true, true, //
        false, true, true, true, true, true, true,
      ];
      // 5. sonuç satır dizini 6 -> reklam 7. sıraya girer
      expect(aramaReklamSirasi(satirlar, 9), 7);
      expect(aramaReklamSirasi(satirlar, 8), 7);
      expect(aramaReklamSirasi(satirlar, 7), isNull);
      expect(aramaReklamSirasi(satirlar, 0), isNull);
      expect(aramaReklamSirasi(const [false, true], 8), isNull,
          reason: 'sonuç sayısı yetse de satırlarda 5. sonuç yoksa reklam yok');
      expect(aramaReklamSonucSirasi, 5);
      expect(aramaReklamEnAzSonuc, 8);
      expect(aramaReklamBeklemesi, const Duration(seconds: 1));
    });

    Menu menu(int gun) => Menu('ankara', null, {
          for (var d = 3; d < 3 + gun; d++)
            '2026-11-${d.toString().padLeft(2, '0')}': {
              'lunch': Ogun([YemekOgesi('Bulgur Pilavı', 250)], 250),
            },
        });

    Future<void> araAc(WidgetTester t, ReklamYoneticisi? y, Menu m,
        {double yazi = 1.0, Size boyut = const Size(400, 1800)}) async {
      _boyut(t, boyut);
      await t.pumpWidget(_uygulama(
          YemekAraSayfasi(
              depo: _Depo(m),
              uniler: [_uni()],
              uni: _uni(),
              menu: m,
              bugun: '2026-11-02',
              reklam: y),
          yazi: yazi));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'pilav');
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
        '8+ sonuç: 1 sn sabit kalınca 5. sonuçtan sonra reklam; 1 sn dolmadan istek yok',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await araAc(t, y, menu(10));
      expect(find.text('Bulgur Pilavı'), findsWidgets);
      await t.pump(const Duration(milliseconds: 800));
      expect(s.yukleSayisi, 0, reason: '1 sn dolmadı');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(_sahteReklam, findsOneWidget);
      expect(s.istenenStiller.last.buyuk, isFalse);
      // sıra: 5. sonuçtan sonra
      final sonuclar = find.text('Bulgur Pilavı');
      final bes = t.getRect(sonuclar.at(4)).bottom;
      final alti = t.getRect(sonuclar.at(5)).top;
      final r = t.getRect(_sahteReklam);
      expect(r.top, greaterThan(bes));
      expect(r.bottom, lessThan(alti));
      expect(find.byType(ReklamKarti), findsOneWidget);
      y.dispose();
    });

    testWidgets(
        'yazarken ya da sonuç değişirken istek atılmaz; sonuç sabitlenince atılır',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await araAc(t, y, menu(10));
      await t.pump(const Duration(milliseconds: 400));
      // yeni sorgu: bekleme yeniden başlar
      await t.enterText(find.byType(TextField), 'pilav ');
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(find.byType(TextField), 'pilavı');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 600));
      expect(s.yukleSayisi, 0);
      await t.pump(const Duration(milliseconds: 700));
      await t.pumpAndSettle();
      expect(s.yukleSayisi, 1);
      expect(_sahteReklam, findsOneWidget);
      y.dispose();
    });

    testWidgets('8\'den az sonuç: reklam yok, istek yok', (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await araAc(t, y, menu(7));
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.text('Bulgur Pilavı'), findsWidgets);
      expect(find.byType(ReklamKarti), findsNothing);
      expect(s.yukleSayisi, 0);
      y.dispose();
    });

    testWidgets('reklam parametresi yoksa ya da yerleşim kapalıysa liste aynı',
        (t) async {
      await araAc(t, null, menu(10));
      expect(find.byType(ReklamKarti), findsNothing);
      await t.pumpWidget(const SizedBox());
      final s = SahteReklamServisi();
      final y = _yonetici(s,
          ayar: () async =>
              const UzakReklamAyari(yerlesimler: {'arama': false}));
      await araAc(t, y, menu(10));
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(_sahteReklam, findsNothing);
      expect(s.yukleSayisi, 0);
      y.dispose();
    });

    testWidgets('320x640, yazı 1.5x: taşma yok', (t) async {
      final y = _yonetici(SahteReklamServisi());
      await araAc(t, y, menu(10), yazi: 1.5, boyut: const Size(320, 640));
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      y.dispose();
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('yerleşim: yemek ayrıntısı', () {
    Future<void> detayAc(WidgetTester t, ReklamYoneticisi? y,
        {YemekOgesi? yemek,
        double yazi = 1.0,
        Size boyut = const Size(400, 2600)}) async {
      _boyut(t, boyut);
      await t.pumpWidget(_uygulama(
          YemekDetaySayfasi(
              yemek: yemek ?? YemekOgesi('Mantı', 450, null, 'manti'),
              uni: _uni(),
              menu: _haftaMenusu(),
              bugun: '2026-11-02',
              geriBildirim: YerelDepo(),
              reklam: y),
          yazi: yazi));
      await t.pumpAndSettle();
    }

    testWidgets('sayfanın en altında, yorumlardan sonra tek küçük reklam',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await detayAc(t, y);
      await _bekle(t);
      expect(_sahteReklam, findsOneWidget);
      expect(s.istenenStiller.last.buyuk, isFalse);
      final yorum = t.getRect(find.text('Bu yemek hakkında'));
      final r = t.getRect(_sahteReklam);
      expect(r.top, greaterThan(yorum.bottom));
      expect(find.byType(ReklamKarti), findsOneWidget);
      y.dispose();
    });

    testWidgets('anahtarsız yemekte de en altta; reklamsız ya da kapalıysa yok',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await detayAc(t, y, yemek: YemekOgesi('Ayran', 60));
      await _bekle(t);
      expect(_sahteReklam, findsOneWidget);
      y.dispose();
      await t.pumpWidget(const SizedBox());
      await detayAc(t, null);
      expect(find.byType(ReklamKarti), findsNothing);
      final s2 = SahteReklamServisi();
      final y2 = _yonetici(s2,
          ayar: () async =>
              const UzakReklamAyari(yerlesimler: {'detay': false}));
      await detayAc(t, y2);
      await _bekle(t, kez: 2);
      expect(_sahteReklam, findsNothing);
      expect(s2.yukleSayisi, 0);
      y2.dispose();
    });

    testWidgets('320x640, yazı 1.5x: taşma yok', (t) async {
      final y = _yonetici(SahteReklamServisi());
      await detayAc(t, y, yazi: 1.5, boyut: const Size(320, 640));
      await t.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await _bekle(t);
      expect(t.takeException(), isNull);
      y.dispose();
    });
  });

  // ---------------------------------------------------------------------------------------------------------------
  group('reklamsız yerleşimler ve ayarlar', () {
    testWidgets(
        'ayarlar sayfasında reklam kartı yok; Reklamsız gün satırı ve kalan süre',
        (t) async {
      final s = SahteReklamServisi();
      var an = _sabah();
      final y = _yonetici(s, simdi: () => an);
      _boyut(t, const Size(400, 1600));
      await t.pumpWidget(_uygulama(AyarlarSayfasi(
          temaAyari: TemaAyari(),
          depo: _Depo(_haftaMenusu()),
          uniler: [_uni()],
          uni: _uni(),
          reklam: y,
          menuyuYenile: () async {})));
      await t.pumpAndSettle();
      await _bekle(t);
      expect(find.byType(ReklamKarti), findsNothing);
      expect(find.text('Reklamsız gün kazan'), findsOneWidget);
      await t.ensureVisible(find.text('Reklamsız gün kazan'));
      await t.tap(find.text('Reklamsız gün kazan'));
      await t.pumpAndSettle();
      await t.tap(find.text('İzle'));
      await t.pumpAndSettle();
      expect(y.reklamsizMi, isTrue);
      expect(find.text('Reklamsız gün kazan'), findsNothing);
      expect(find.text("Reklamsız: yarın 10:00'a kadar"), findsOneWidget);
      expect(find.byType(ReklamKarti), findsNothing);
      y.dispose();
    });

    testWidgets('ödüllü yoksa Ayarlar\'da satır görünmez', (t) async {
      final y = _yonetici(SahteReklamServisi(odulluVar: false));
      _boyut(t, const Size(400, 1600));
      await t.pumpWidget(_uygulama(AyarlarSayfasi(
          temaAyari: TemaAyari(),
          depo: _Depo(_haftaMenusu()),
          uniler: [_uni()],
          uni: _uni(),
          reklam: y,
          menuyuYenile: () async {})));
      await _bekle(t);
      expect(find.text('Reklamsız gün kazan'), findsNothing);
      y.dispose();
    });

    testWidgets('ana ekranda tek reklam: her ekranda en fazla 1', (t) async {
      final y = _yonetici(SahteReklamServisi());
      await _anaAc(t, y);
      await _bekle(t);
      expect(find.byType(ReklamKarti), findsOneWidget);
      expect(_sahteReklam, findsOneWidget);
      y.dispose();
    });

    testWidgets(
        'ana ekran -> hafta: ana ekranın reklamı arkada kalır, hafta ekranında bir tane daha (ekran başına 1)',
        (t) async {
      final s = SahteReklamServisi();
      final y = _yonetici(s);
      await _anaAc(t, y);
      await _bekle(t);
      expect(s.yukleSayisi, 1);
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Haftalık menü'));
      await t.pumpAndSettle();
      await _bekle(t);
      expect(find.byType(HaftaSayfasi), findsOneWidget);
      // ekranda görünen sayfada tek ReklamKarti var
      expect(
          find.descendant(
              of: find.byType(HaftaSayfasi),
              matching: find.byType(ReklamKarti)),
          findsOneWidget);
      expect(s.yukleSayisi, 2);
      expect(t.takeException(), isNull);
      y.dispose();
    });
  });
}
