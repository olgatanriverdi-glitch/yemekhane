// BildirimAyari (lib/bildirim_ayari.dart): ayar saklama, izin isteme, kapatma ve planlamanın yeniden kurulması.
// Gerçek eklenti yok: sahte servis çağrıları kaydeder (test/sahte_bildirim.dart).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/bildirim_ayari.dart';
import 'package:yemekhane/bildirim_plani.dart';
import 'package:yemekhane/models.dart';

import 'sahte_bildirim.dart';

Universite _uni([String kisa = 'AÜ']) => Universite(
    id: 'ankara',
    ad: 'Ankara Üniversitesi',
    kisa: kisa,
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

/// 2 - 6 Kasım 2026 (Pzt - Cum), her gün öğlede [yemek].
Menu _menu([String yemek = 'Mercimek Çorbası']) => Menu('ankara', null, {
      for (var g = 2; g <= 6; g++)
        '2026-11-0$g': {
          'lunch': Ogun([YemekOgesi(yemek, null, null, 'k$g')], null)
        }
    });

DateTime _sabah() => DateTime.utc(2026, 11, 2, 10, 0);

Future<BildirimAyari> _ayar(SahteBildirimServisi servis,
    {bool acik = false, int? saatDk}) async {
  final a = BildirimAyari(
      servis: servis, acik: acik, saatDk: saatDk ?? varsayilanBildirimSaatDk);
  await a.yukle();
  addTearDown(a.dispose);
  return a;
}

Future<Object?> _kayitli(String anahtar) async =>
    (await SharedPreferences.getInstance()).get(anahtar);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ayar ve saklama', () {
    test('varsayılan: kapalı, saat 10:30; yükleme servise dokunmaz', () async {
      final s = SahteBildirimServisi();
      final a = BildirimAyari(servis: s);
      expect(a.acik, isFalse);
      expect(a.saatDk, 10 * 60 + 30);
      expect(a.yuklendi, isFalse);
      await a.yukle();
      expect(a.acik, isFalse);
      expect(a.yuklendi, isTrue);
      expect(s.cagrilar, isEmpty);
    });

    test('kayıtlı açık ve saat yüklenir; yükleme servise yine dokunmaz',
        () async {
      SharedPreferences.setMockInitialValues(
          {'bildirim_acik': true, 'bildirim_saat': 8 * 60});
      final s = SahteBildirimServisi();
      final a = await _ayar(s);
      expect(a.acik, isTrue);
      expect(a.saatDk, 480);
      expect(s.cagrilar, isEmpty);
    });

    test('bozuk kayıtlar yok sayılır: varsayılan kapalı ve 10:30', () async {
      for (final bozuk in <Map<String, Object>>[
        {'bildirim_acik': 'evet', 'bildirim_saat': 'sabah'},
        {'bildirim_saat': -1},
        {'bildirim_saat': 24 * 60},
        {'bildirim_saat': 630.5},
        {'bildirim_acik': 1},
      ]) {
        SharedPreferences.setMockInitialValues(bozuk);
        final a = await _ayar(SahteBildirimServisi());
        expect(a.acik, isFalse, reason: '$bozuk');
        expect(a.saatDk, 630, reason: '$bozuk');
      }
    });

    test('yukle bir kez çalışır; sonraki çağrılar aynı işlemi döndürür',
        () async {
      final a = BildirimAyari(servis: SahteBildirimServisi());
      expect(identical(a.yukle(), a.yukle()), isTrue);
      await a.yukle();
    });

    test('kurucudaki gün dışı saat varsayılana düşer', () {
      expect(BildirimAyari(servis: SahteBildirimServisi(), saatDk: -3).saatDk,
          630);
      expect(BildirimAyari(servis: SahteBildirimServisi(), saatDk: 1440).saatDk,
          630);
      expect(
          BildirimAyari(servis: SahteBildirimServisi(), saatDk: 0).saatDk, 0);
    });

    test('değişince dinleyenler haberdar olur', () async {
      final a = await _ayar(SahteBildirimServisi());
      var sayac = 0;
      a.addListener(() => sayac++);
      await a.ac();
      await a.saatSec(9 * 60);
      await a.kapat();
      expect(sayac, 3);
    });
  });

  group('açma (izin)', () {
    test('izin verilirse açılır, kaydedilir ve true döner', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s);
      expect(await a.ac(), isTrue);
      expect(a.acik, isTrue);
      expect(await _kayitli('bildirim_acik'), isTrue);
      expect(s.sayi('izin'), 1);
    });

    test('izin reddedilirse kapalı kalır, kaydedilmez, plan kurulmaz',
        () async {
      final s = SahteBildirimServisi(izin: false);
      final a = await _ayar(s);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      expect(await a.ac(), isFalse);
      expect(a.acik, isFalse);
      expect(await _kayitli('bildirim_acik'), isNull);
      expect(s.cagrilar, ['izin']);
    });

    test('izin isteği istisna verirse de kapalı kalır', () async {
      final s = SahteBildirimServisi()..izinHata = true;
      final a = await _ayar(s);
      expect(await a.ac(), isFalse);
      expect(a.acik, isFalse);
    });

    test('zaten açıksa izin yeniden istenmez', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      expect(await a.ac(), isTrue);
      expect(s.cagrilar, isEmpty);
    });

    test('açılınca bilinen menüyle iptal + plan kurulur', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      expect(s.cagrilar, isEmpty, reason: 'kapalıyken servise dokunulmaz');
      await a.ac();
      expect(s.cagrilar, ['izin', 'iptal', 'planla']);
      expect(s.sonPlan.map((b) => b.kimlik),
          [20261102, 20261103, 20261104, 20261105, 20261106]);
      expect(s.sonPlan.first.zaman, DateTime.utc(2026, 11, 2, 10, 30));
      expect(s.sonPlan.first.baslik, 'AÜ · bugün öğle');
    });

    test('menü henüz bilinmiyorsa açılınca yalnızca izin istenir', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s);
      await a.ac();
      expect(a.acik, isTrue);
      expect(s.cagrilar, ['izin']);
    });
  });

  group('kapatma', () {
    test('kapatınca bütün bildirimler iptal edilir, plan kurulmaz', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      s.cagrilar.clear();
      await a.kapat();
      expect(a.acik, isFalse);
      expect(await _kayitli('bildirim_acik'), isFalse);
      expect(s.cagrilar, ['iptal']);
    });

    test('kapalıyken kapat hiçbir şey yapmaz', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s);
      await a.kapat();
      expect(s.cagrilar, isEmpty);
    });

    test('kapandıktan sonra gelen menü durumu servise dokunmaz', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.kapat();
      s.cagrilar.clear();
      await a.durumuBildir(_uni(), _menu(), {'k2'}, _sabah);
      await a.saatSec(7 * 60);
      expect(s.cagrilar, isEmpty);
    });

    test('iptal hata verse de ayar kapanır ve istisna sızmaz', () async {
      final s = SahteBildirimServisi()..planHata = true;
      final a = await _ayar(s, acik: true);
      await a.kapat();
      expect(a.acik, isFalse);
    });

    test('kapat, sıradaki (bekleyen) planı atlar', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      s.iptalKapisi = Completer<void>();
      final ilk = a.durumuBildir(_uni(), _menu(), {}, _sabah);
      await pumpEventQueue();
      final ikinci = a.durumuBildir(_uni(), _menu('Yeni'), {}, _sabah);
      final kapat = a.kapat();
      await pumpEventQueue();
      s.iptalKapisi!.complete();
      await Future.wait([ilk, ikinci, kapat]);
      // çalışan ilk plan tamamlandı (iptal, planla); bekleyen ikinci plan atlandı; ardından kapatma iptali
      expect(s.cagrilar, ['iptal', 'planla', 'iptal']);
      expect(s.planlar.length, 1);
    });
  });

  group('saat seçimi', () {
    test('açıkken saat değişince kaydedilir ve yeni saatle yeniden kurulur',
        () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      s.cagrilar.clear();
      await a.saatSec(11 * 60 + 15);
      expect(a.saatDk, 11 * 60 + 15);
      expect(await _kayitli('bildirim_saat'), 11 * 60 + 15);
      expect(s.cagrilar, ['iptal', 'planla']);
      expect(s.sonPlan.first.zaman, DateTime.utc(2026, 11, 2, 11, 15));
    });

    test('kapalıyken saat yalnızca kaydedilir, servise dokunulmaz', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      await a.saatSec(9 * 60);
      expect(a.saatDk, 540);
      expect(await _kayitli('bildirim_saat'), 540);
      expect(s.cagrilar, isEmpty);
    });

    test('gün dışı saat ve aynı saat yok sayılır', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      s.cagrilar.clear();
      await a.saatSec(-1);
      await a.saatSec(24 * 60);
      await a.saatSec(a.saatDk);
      expect(a.saatDk, 630);
      expect(s.cagrilar, isEmpty);
      expect(await _kayitli('bildirim_saat'), isNull);
    });

    test('kayıtlı saat sonraki açılışta kullanılır', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s);
      await a.saatSec(7 * 60 + 5);
      final b = await _ayar(SahteBildirimServisi());
      expect(b.saatDk, 425);
    });
  });

  group('yeniden planlama', () {
    test('kapalıyken durum yalnızca saklanır: servise hiç dokunulmaz',
        () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s);
      await a.durumuBildir(_uni(), _menu(), {'k2'}, _sabah);
      await a.durumuBildir(_uni('GÜ'), _menu('Başka'), {}, _sabah);
      expect(s.cagrilar, isEmpty);
    });

    test('açıkken her durum bildirimi önce iptal sonra yeni plan kurar',
        () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      expect(s.cagrilar, ['iptal', 'planla']);
      await a.durumuBildir(_uni('GÜ'), _menu('Başka Yemek'), {}, _sabah);
      expect(s.cagrilar, ['iptal', 'planla', 'iptal', 'planla']);
      expect(s.sonPlan.first.baslik, 'GÜ · bugün öğle');
      expect(s.sonPlan.first.metin, 'Başka Yemek');
    });

    test('plan, bildirilen saat kaynağıyla (sahte saat) hazırlanır', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      // 3 Kasım 11:00: 3 Kasım 10:30 geçmiş, plan 4 Kasım'dan başlar
      await a.durumuBildir(
          _uni(), _menu(), {}, () => DateTime.utc(2026, 11, 3, 11, 0));
      expect(s.sonPlan.first.kimlik, 20261104);
    });

    test('favoriler plana girer', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.durumuBildir(_uni(), _menu(), {'k3'}, _sabah);
      expect(s.sonPlan[0].metin, 'Mercimek Çorbası');
      expect(s.sonPlan[1].metin, 'Bugün favorin Mercimek Çorbası menüde');
    });

    test('favoriler değişince plan yeni favorilerle yeniden kurulur', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      s.cagrilar.clear();
      await a.favorileriBildir({'k3'});
      expect(s.cagrilar, ['iptal', 'planla']);
      expect(s.sonPlan[1].metin, 'Bugün favorin Mercimek Çorbası menüde');
      // favoriler çıkarılınca normal liste geri gelir
      await a.favorileriBildir({});
      expect(s.cagrilar.length, 4);
      expect(s.sonPlan[1].metin, 'Mercimek Çorbası');
    });

    test(
        'favoriler aynıysa (başlangıçta boş listenin yüklenmesi) servise dokunulmaz',
        () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.durumuBildir(_uni(), _menu(), {'k3'}, _sabah);
      s.cagrilar.clear();
      await a.favorileriBildir({'k3'});
      await a.favorileriBildir({'k3'});
      expect(s.cagrilar, isEmpty);
    });

    test('menü bildirilmeden gelen favori değişimi yok sayılır; kapalıyken de',
        () async {
      final s = SahteBildirimServisi();
      final acikAyar = await _ayar(s, acik: true);
      await acikAyar.favorileriBildir({'k3'});
      expect(s.cagrilar, isEmpty);
      final s2 = SahteBildirimServisi();
      final kapali = await _ayar(s2);
      await kapali.durumuBildir(_uni(), _menu(), {}, _sabah);
      await kapali.favorileriBildir({'k3'});
      expect(s2.cagrilar, isEmpty);
      // ama durum saklanır: ayar sonradan açılınca yeni favorilerle kurulur
      await kapali.ac();
      expect(s2.sonPlan[1].metin, 'Bugün favorin Mercimek Çorbası menüde');
    });

    test('plan yalnızca durum bildirilmişse kurulur', () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      await a.saatSec(9 * 60);
      expect(s.cagrilar, isEmpty, reason: 'menü / okul henüz bilinmiyor');
    });

    test('art arda istekler sıraya girer; arkasından yenisi gelen atlanır',
        () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      s.iptalKapisi = Completer<void>();
      final f1 = a.durumuBildir(_uni(), _menu('Bir'), {}, _sabah);
      await pumpEventQueue();
      expect(s.cagrilar, ['iptal'],
          reason: 'ilk plan çalışıyor, iptalde bekler');
      final f2 = a.durumuBildir(_uni(), _menu('İki'), {}, _sabah);
      final f3 = a.durumuBildir(_uni(), _menu('Üç'), {}, _sabah);
      await pumpEventQueue();
      expect(s.cagrilar, ['iptal'], reason: 'sonrakiler sırada bekler');
      s.iptalKapisi!.complete();
      await Future.wait([f1, f2, f3]);
      // ilk plan tamamlanır (Bir); İki, arkasından Üç geldiği için atlanır; Üç tam plan kurar
      expect(s.cagrilar, ['iptal', 'planla', 'iptal', 'planla']);
      expect(s.planlar.map((p) => p.first.metin), ['Bir', 'Üç']);
    });

    test('aynı anda gelen istekler tek plana iner (hepsi aynı mikro görevde)',
        () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      final f = [
        a.durumuBildir(_uni(), _menu('Bir'), {}, _sabah),
        a.durumuBildir(_uni(), _menu('İki'), {}, _sabah),
        a.durumuBildir(_uni(), _menu('Üç'), {}, _sabah),
      ];
      await Future.wait(f);
      expect(s.cagrilar, ['iptal', 'planla']);
      expect(s.sonPlan.first.metin, 'Üç');
    });

    test('servis hataları yutulur; sonraki istek yine denenir', () async {
      final s = SahteBildirimServisi()..planHata = true;
      final a = await _ayar(s, acik: true);
      await a.durumuBildir(
          _uni(), _menu(), {}, _sabah); // iptal ve planla hata verir
      expect(s.cagrilar, ['iptal', 'planla']);
      s.planHata = false;
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      expect(s.cagrilar, ['iptal', 'planla', 'iptal', 'planla']);
    });

    test('yükleme bitmeden gelen durum, kayıtlı açık ayara göre işlenir',
        () async {
      SharedPreferences.setMockInitialValues({'bildirim_acik': true});
      final s = SahteBildirimServisi();
      final a = BildirimAyari(servis: s); // yukle çağrılmadı
      addTearDown(a.dispose);
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      expect(a.acik, isTrue);
      expect(s.cagrilar, ['iptal', 'planla']);
    });

    test('hiçbir yerde servis çağrısı sırası bozulmaz: iptal hep plandan önce',
        () async {
      final s = SahteBildirimServisi();
      final a = await _ayar(s, acik: true);
      for (var i = 0; i < 5; i++) {
        await a.durumuBildir(_uni(), _menu('Yemek $i'), {}, _sabah);
      }
      expect(
          listEquals(s.cagrilar, [
            for (var i = 0; i < 5; i++) ...['iptal', 'planla']
          ]),
          isTrue);
    });
  });

  group('varsayılan servis', () {
    test(
        'servis verilmezse gerçek servis kurulur ama ayar kapalıyken çağrılmaz',
        () async {
      // gerçek FlutterBildirimServisi kurulumu eklentiye dokunmaz (tembel başlatma): ayar yükleme ve
      // kapalıyken durum bildirimi hiçbir platform çağrısı yapmaz (aksi halde testte MissingPluginException olurdu)
      final a = BildirimAyari();
      addTearDown(a.dispose);
      await a.yukle();
      await a.durumuBildir(_uni(), _menu(), {}, _sabah);
      await a.kapat();
      expect(a.acik, isFalse);
    });
  });
}
