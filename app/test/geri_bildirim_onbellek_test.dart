import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/firebase_config.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

// Puan / yorum okuma önbelleği (OnbellekliGeriBildirim): Firestore okuma kotası aynı sorgularla boşa gitmesin.
// Gerçek ağ yok: içteki depo sahte "sunucu" (_Ic), Firestore yolu için MockClient kullanılır.

/// İçteki depoyu taklit eden bellek içi "sunucu". Çağrıları sayar; oylar ve yorumlar bellekte durur. Okuma yanıtı
/// istek AÇILDIĞI andaki durumdan üretilir (yanıt yolda beklerken sunucuda olan değişiklik yanıta girmez).
class _Ic implements GeriBildirimDeposu {
  final Map<String, int> cagri = {};
  int sayi(String ad) => cagri[ad] ?? 0;
  void _say(String ad) => cagri[ad] = sayi(ad) + 1;

  /// slot -> başka kullanıcıların oyları; [benim] bu kullanıcının kendi oyları.
  final Map<String, List<int>> digerOylar = {};
  final Map<String, int> benim = {};
  final Map<String, List<Yorum>> yorumDeposu = {};

  /// Doluysa okumalar bu tamamlanana kadar bekler; [okumaHatasi] doluysa bekleyişten sonra bu hatayla biter.
  Completer<void>? kapi;
  Object? okumaHatasi;
  Object? yazmaHatasi;
  int _yorumNo = 0;

  Future<void> _bekle() async {
    if (kapi != null) await kapi!.future;
    if (okumaHatasi != null) throw okumaHatasi!;
  }

  PuanOzeti _ozet(String slot) {
    final oylar = [
      ...?digerOylar[slot],
      if (benim[slot] != null) benim[slot]!,
    ];
    return oylar.isEmpty
        ? const PuanOzeti(null, 0)
        : PuanOzeti(oylar.reduce((a, b) => a + b) / oylar.length, oylar.length);
  }

  @override
  bool get cevrimici => true;

  @override
  Future<String> kullaniciId() async {
    _say('kullaniciId');
    return 'u1';
  }

  @override
  Future<PuanOzeti> puanOzeti(String slot) async {
    _say('puanOzeti');
    final sonuc = _ozet(slot);
    await _bekle();
    return sonuc;
  }

  @override
  Future<int?> benimPuanim(String slot) async {
    _say('benimPuanim');
    final sonuc = benim[slot];
    await _bekle();
    return sonuc;
  }

  @override
  Future<YemekPuanlari> puanlar(List<String> slotlar) async {
    _say('puanlar');
    final sonuc = YemekPuanlari({
      for (final s in slotlar) s: _ozet(s)
    }, {
      for (final s in slotlar)
        if (benim[s] != null) s: benim[s]!
    });
    await _bekle();
    return sonuc;
  }

  @override
  Future<void> puanVer(String slot, int yildiz) async {
    _say('puanVer');
    if (yazmaHatasi != null) throw yazmaHatasi!;
    benim[slot] = yildiz;
  }

  @override
  Future<List<Yorum>> yorumlar(String slot) async {
    _say('yorumlar');
    final sonuc = List.of(yorumDeposu[slot] ?? const <Yorum>[]);
    await _bekle();
    return sonuc;
  }

  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async {
    _say('yorumEkle');
    if (yazmaHatasi != null) throw yazmaHatasi!;
    (yorumDeposu[slot] ??= []).insert(
        0, Yorum('c${_yorumNo++}', 'u1', ad, metin, DateTime(2026, 11, 2, 10)));
  }

  @override
  Future<void> yorumSil(Yorum y) async {
    _say('yorumSil');
    if (yazmaHatasi != null) throw yazmaHatasi!;
    for (final l in yorumDeposu.values) {
      l.removeWhere((e) => e.id == y.id);
    }
  }

  @override
  Future<void> yorumBildir(Yorum y, YorumBildirimNedeni neden) async {
    _say('yorumBildir');
    if (yazmaHatasi != null) throw yazmaHatasi!;
  }

  @override
  Future<void> verilerimiSil() async {
    _say('verilerimiSil');
    if (yazmaHatasi != null) throw yazmaHatasi!;
    yorumDeposu.clear();
  }
}

Yorum _yorum(String id, [String metin = 'Güzeldi']) =>
    Yorum(id, 'u1', 'Ali', metin, DateTime(2026, 11, 2, 9));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _Ic ic;
  late DateTime an;
  late OnbellekliGeriBildirim depo;

  setUp(() {
    ic = _Ic();
    an = DateTime(2026, 11, 2, 10, 0);
    depo = OnbellekliGeriBildirim(ic, saat: () => an);
  });

  group('okuma önbelleği', () {
    test('puanOzeti: ikinci okuma içteki depoya gitmez, aynı değeri verir',
        () async {
      ic.digerOylar['s'] = [4, 5];
      final ilk = await depo.puanOzeti('s');
      final ikinci = await depo.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 1);
      expect(ikinci.ortalama, 4.5);
      expect(ikinci.adet, 2);
      expect(ilk.ortalama, ikinci.ortalama);
    });

    test(
        'benimPuanim: ikinci okuma içteki depoya gitmez (boş değer de saklanır)',
        () async {
      expect(await depo.benimPuanim('s'), isNull);
      expect(await depo.benimPuanim('s'), isNull);
      expect(ic.sayi('benimPuanim'), 1);
      ic.benim['t'] = 3;
      expect(await depo.benimPuanim('t'), 3);
      expect(await depo.benimPuanim('t'), 3);
      expect(ic.sayi('benimPuanim'), 2);
    });

    test('yorumlar: ikinci okuma içteki depoya gitmez', () async {
      ic.yorumDeposu['s'] = [_yorum('a'), _yorum('b')];
      expect((await depo.yorumlar('s')).map((y) => y.id), ['a', 'b']);
      expect((await depo.yorumlar('s')).map((y) => y.id), ['a', 'b']);
      expect(ic.sayi('yorumlar'), 1);
    });

    test('puanlar: ikinci okuma içteki depoya gitmez, benim puanlarım da gelir',
        () async {
      ic.digerOylar['a'] = [2];
      ic.benim['b'] = 5;
      final ilk = await depo.puanlar(['a', 'b']);
      final ikinci = await depo.puanlar(['a', 'b']);
      expect(ic.sayi('puanlar'), 1);
      expect(ikinci.ozet['a']!.ortalama, 2.0);
      expect(ikinci.ozet['b']!.adet, 1);
      expect(ikinci.benim, {'b': 5});
      expect(ilk.benim, ikinci.benim);
    });

    test('farklı slotlar ayrı kayıttır', () async {
      await depo.puanOzeti('a');
      await depo.puanOzeti('b');
      await depo.puanOzeti('a');
      expect(ic.sayi('puanOzeti'), 2);
      await depo.yorumlar('a');
      await depo.yorumlar('b');
      expect(ic.sayi('yorumlar'), 2);
    });

    test('puanlar slot KÜMESİNE göre saklanır: sıra ve tekrar önemsiz',
        () async {
      await depo.puanlar(['a', 'b']);
      await depo.puanlar(['b', 'a']);
      await depo.puanlar(['a', 'b', 'a']);
      expect(ic.sayi('puanlar'), 1);
      // farklı küme (alt küme ya da üst küme) ayrı kayıt
      await depo.puanlar(['a']);
      await depo.puanlar(['a', 'b', 'c']);
      expect(ic.sayi('puanlar'), 3);
      await depo.puanlar(['c', 'b', 'a']);
      expect(ic.sayi('puanlar'), 3);
    });

    test('boş slot listesi içteki depoya iletilir, saklanmaz', () async {
      final p = await depo.puanlar(const []);
      expect(p.ozet, isEmpty);
      await depo.puanlar(const []);
      expect(ic.sayi('puanlar'), 2);
    });

    test(
        'kayıt varsayılan olarak 5 dakika yaşar: 4 dk 59 sn önbellekten, 5 dk yeniden okunur',
        () async {
      ic.digerOylar['s'] = [4];
      expect((await depo.puanOzeti('s')).adet, 1);
      ic.digerOylar['s'] = [4, 2]; // sunucuda başkası da oy verdi
      an = an.add(const Duration(minutes: 4, seconds: 59));
      expect((await depo.puanOzeti('s')).adet, 1, reason: 'hâlâ önbellekte');
      expect(ic.sayi('puanOzeti'), 1);
      an = an.add(const Duration(seconds: 1));
      final taze = await depo.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 2, reason: 'süre doldu');
      expect(taze.adet, 2);
      // yeni kayıt kendi saatinden sayılır
      an = an.add(const Duration(minutes: 4, seconds: 59));
      await depo.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 2);
      an = an.add(const Duration(seconds: 1));
      await depo.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 3);
    });

    test('süre dolunca her okuma türü yeniden okunur', () async {
      await depo.puanOzeti('s');
      await depo.benimPuanim('s');
      await depo.puanlar(['s']);
      await depo.yorumlar('s');
      an = an.add(const Duration(minutes: 5));
      await depo.puanOzeti('s');
      await depo.benimPuanim('s');
      await depo.puanlar(['s']);
      await depo.yorumlar('s');
      for (final ad in ['puanOzeti', 'benimPuanim', 'puanlar', 'yorumlar']) {
        expect(ic.sayi(ad), 2, reason: ad);
      }
    });

    test('ömür enjekte edilebilir', () async {
      final kisa = OnbellekliGeriBildirim(ic,
          saat: () => an, omur: const Duration(seconds: 30));
      await kisa.puanOzeti('s');
      an = an.add(const Duration(seconds: 29));
      await kisa.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 1);
      an = an.add(const Duration(seconds: 1));
      await kisa.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 2);
    });

    test('saat geriye alınırsa (cihaz saati değişti) kayda güvenilmez',
        () async {
      await depo.puanOzeti('s');
      an = an.subtract(const Duration(minutes: 1));
      await depo.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 2);
    });

    test('kullaniciId önbelleğe alınmaz; cevrimici içteki depodan gelir',
        () async {
      expect(await depo.kullaniciId(), 'u1');
      expect(await depo.kullaniciId(), 'u1');
      expect(ic.sayi('kullaniciId'), 2);
      expect(depo.cevrimici, isTrue);
      expect(OnbellekliGeriBildirim(YerelDepo()).cevrimici, isFalse);
    });

    test('YerelDepo ile de çalışır (zararsız)', () async {
      final yerel = OnbellekliGeriBildirim(YerelDepo(), saat: () => an);
      expect((await yerel.puanOzeti('s')).adet, 0);
      expect(await yerel.benimPuanim('s'), isNull);
      await yerel.puanVer('s', 4);
      expect((await yerel.puanOzeti('s')).ortalama, 4.0);
      expect(await yerel.benimPuanim('s'), 4);
      expect((await yerel.puanlar(['s'])).benim, {'s': 4});
      expect(await yerel.yorumlar('s'), isEmpty);
      await yerel.yorumEkle('s', 'Ali', 'Güzeldi');
      final liste = await yerel.yorumlar('s');
      expect(liste.single.metin, 'Güzeldi');
      await yerel.yorumSil(liste.single);
      expect(await yerel.yorumlar('s'), isEmpty);
    });
  });

  group('yazma sonrası geçersizleme', () {
    test('puanVer: puan özeti tazelenir (ortalama ve oy sayısı)', () async {
      ic.digerOylar['s'] = [4];
      final once = await depo.puanOzeti('s');
      expect(once.adet, 1);
      expect(once.ortalama, 4.0);
      await depo.puanVer('s', 2);
      final sonra = await depo.puanOzeti('s');
      expect(sonra.adet, 2);
      expect(sonra.ortalama, 3.0);
      expect(ic.sayi('puanOzeti'), 2);
      // taze değer yeniden saklanır
      await depo.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 2);
    });

    test('puanVer: benim puanım tazelenir', () async {
      expect(await depo.benimPuanim('s'), isNull);
      await depo.puanVer('s', 5);
      expect(await depo.benimPuanim('s'), 5);
      expect(ic.sayi('benimPuanim'), 2);
    });

    test(
        'puanVer: o slotu içeren puanlar kümeleri düşer; slotu içermeyenler ve başka slotlar kalır',
        () async {
      await depo.puanlar(['a', 'b']);
      await depo.puanlar(['b', 'c']);
      await depo.puanlar(['c', 'd']);
      await depo.puanOzeti('b');
      await depo.puanOzeti('c');
      await depo.benimPuanim('c');
      expect(ic.sayi('puanlar'), 3);

      await depo.puanVer('b', 3);

      final ab = await depo.puanlar(['a', 'b']);
      final bc = await depo.puanlar(['b', 'c']);
      expect(ic.sayi('puanlar'), 5, reason: 'yalnızca b içeren iki küme');
      expect(ab.benim, {'b': 3});
      expect(bc.ozet['b']!.ortalama, 3.0);
      await depo.puanlar(['c', 'd']); // b'yi içermiyor: önbellekte
      await depo.puanOzeti('c');
      await depo.benimPuanim('c');
      expect(ic.sayi('puanlar'), 5);
      expect(ic.sayi('puanOzeti'), 2);
      expect(ic.sayi('benimPuanim'), 1);
    });

    test('puanVer yorum kayıtlarına dokunmaz', () async {
      await depo.yorumlar('s');
      await depo.puanVer('s', 4);
      await depo.yorumlar('s');
      expect(ic.sayi('yorumlar'), 1);
    });

    test(
        'yorumEkle: o slotun yorumları tazelenir; başka slot ve puan kayıtları kalır',
        () async {
      await depo.yorumlar('s');
      await depo.yorumlar('t');
      await depo.puanOzeti('s');
      await depo.puanlar(['s']);
      expect(await depo.yorumlar('s'), isEmpty);

      await depo.yorumEkle('s', 'Ayşe', 'Tuzsuz');

      final liste = await depo.yorumlar('s');
      expect(liste.single.metin, 'Tuzsuz');
      expect(ic.sayi('yorumlar'), 3);
      await depo.yorumlar('t');
      await depo.puanOzeti('s');
      await depo.puanlar(['s']);
      expect(ic.sayi('yorumlar'), 3, reason: 't kayıtlıydı');
      expect(ic.sayi('puanOzeti'), 1);
      expect(ic.sayi('puanlar'), 1);
    });

    test(
        'yorumSil: silinen yorumun slotu bilinmediğinden bütün yorum kayıtları düşer; puanlar kalır',
        () async {
      ic.yorumDeposu['s'] = [_yorum('a'), _yorum('b')];
      ic.yorumDeposu['t'] = [_yorum('c')];
      final s = await depo.yorumlar('s');
      await depo.yorumlar('t');
      await depo.puanlar(['s']);
      expect(ic.sayi('yorumlar'), 2);

      await depo.yorumSil(s.first);

      expect((await depo.yorumlar('s')).map((y) => y.id), ['b']);
      expect((await depo.yorumlar('t')).map((y) => y.id), ['c']);
      expect(ic.sayi('yorumlar'), 4);
      await depo.puanlar(['s']);
      expect(ic.sayi('puanlar'), 1);
    });

    test(
        'yazma başarısız olsa da kayıtlar düşer (sunucuda uygulanmış olabilir)',
        () async {
      await depo.puanOzeti('s');
      await depo.puanlar(['s']);
      await depo.yorumlar('s');
      ic.yazmaHatasi = Exception('zaman aşımı');
      await expectLater(depo.puanVer('s', 4), throwsException);
      await expectLater(depo.yorumEkle('s', 'Ali', 'x'), throwsException);
      ic.yazmaHatasi = null;
      await depo.puanOzeti('s');
      await depo.puanlar(['s']);
      await depo.yorumlar('s');
      expect(ic.sayi('puanOzeti'), 2);
      expect(ic.sayi('puanlar'), 2);
      expect(ic.sayi('yorumlar'), 2);
    });

    test('yazma hatası olduğu gibi çağırana iletilir', () async {
      ic.yazmaHatasi = StateError('kayıt yok');
      await expectLater(depo.puanVer('s', 1), throwsStateError);
      await expectLater(depo.yorumEkle('s', 'Ali', 'x'), throwsStateError);
      await expectLater(depo.yorumSil(_yorum('a')), throwsStateError);
    });

    test('yazma sürerken başlamış okumanın eski sonucu saklanmaz', () async {
      ic.kapi = Completer<void>();
      final yolda = depo.puanOzeti('s'); // sunucunun eski durumu (oy yok) yolda
      final yoldaPuanlar = depo.puanlar(['s']);
      await depo.puanVer('s', 5);
      ic.kapi!.complete();
      expect((await yolda).adet, 0, reason: 'çağırana yine döner');
      expect((await yoldaPuanlar).benim, isEmpty);
      ic.kapi = null;

      final taze = await depo.puanOzeti('s');
      final tazePuanlar = await depo.puanlar(['s']);
      expect(taze.adet, 1);
      expect(tazePuanlar.benim, {'s': 5});
      expect(ic.sayi('puanOzeti'), 2);
      expect(ic.sayi('puanlar'), 2);
    });
  });

  group('hata ve eşzamanlılık', () {
    test(
        'hata önbelleğe alınmaz: sonraki okuma yeniden dener, başarısı saklanır',
        () async {
      final hata = Exception('ağ yok');
      ic.okumaHatasi = hata;
      await expectLater(depo.puanOzeti('s'), throwsA(same(hata)));
      await expectLater(depo.benimPuanim('s'), throwsA(same(hata)));
      await expectLater(depo.puanlar(['s']), throwsA(same(hata)));
      await expectLater(depo.yorumlar('s'), throwsA(same(hata)));
      // hata sürerken her çağrı yeniden dener
      await expectLater(depo.puanOzeti('s'), throwsA(same(hata)));
      expect(ic.sayi('puanOzeti'), 2);

      ic.okumaHatasi = null;
      await depo.puanOzeti('s');
      await depo.benimPuanim('s');
      await depo.puanlar(['s']);
      await depo.yorumlar('s');
      expect(ic.sayi('puanOzeti'), 3);
      // başarı saklandı
      await depo.puanOzeti('s');
      await depo.benimPuanim('s');
      await depo.puanlar(['s']);
      await depo.yorumlar('s');
      expect(ic.sayi('puanOzeti'), 3);
      expect(ic.sayi('benimPuanim'), 2);
      expect(ic.sayi('puanlar'), 2);
      expect(ic.sayi('yorumlar'), 2);
    });

    test('hata sonrası eski taze kayıt varsa o korunur', () async {
      await depo.puanOzeti('s');
      ic.okumaHatasi = Exception('ağ yok');
      // taze kayıt önbellekten gelir, içteki depoya gidilmez (hata görünmez)
      expect((await depo.puanOzeti('s')).adet, 0);
      expect(ic.sayi('puanOzeti'), 1);
    });

    test(
        'eşzamanlı aynı okumalar tek isteği paylaşır (slot sırası farklı olsa da)',
        () async {
      ic.kapi = Completer<void>();
      ic.benim['b'] = 4;
      final f1 = depo.puanlar(['a', 'b']);
      final f2 = depo.puanlar(['b', 'a']);
      final f3 = depo.puanlar(['a', 'b', 'a']);
      final o1 = depo.puanOzeti('a');
      final o2 = depo.puanOzeti('a');
      final y1 = depo.yorumlar('a');
      final y2 = depo.yorumlar('a');
      expect(ic.sayi('puanlar'), 1);
      expect(ic.sayi('puanOzeti'), 1);
      expect(ic.sayi('yorumlar'), 1);

      ic.kapi!.complete();
      final sonuc = await Future.wait([f1, f2, f3]);
      await Future.wait([o1, o2, y1, y2]);
      for (final p in sonuc) {
        expect(p.benim, {'b': 4});
        expect(p.ozet.keys, unorderedEquals(['a', 'b']));
      }
      expect(ic.sayi('puanlar'), 1);
      // paylaşılan sonuç saklandı: yeni çağrı da içteki depoya gitmez
      await depo.puanlar(['a', 'b']);
      await depo.puanOzeti('a');
      await depo.yorumlar('a');
      expect(ic.sayi('puanlar'), 1);
      expect(ic.sayi('puanOzeti'), 1);
      expect(ic.sayi('yorumlar'), 1);
    });

    test(
        'eşzamanlı okuma hatayla biterse hepsi hatayı görür; sonraki çağrı yeniden dener',
        () async {
      final hata = Exception('ağ yok');
      ic.kapi = Completer<void>();
      ic.okumaHatasi = hata;
      final f1 = depo.puanlar(['a']);
      final f2 = depo.puanlar(['a']);
      final s1 = expectLater(f1, throwsA(same(hata)));
      final s2 = expectLater(f2, throwsA(same(hata)));
      expect(ic.sayi('puanlar'), 1);
      ic.kapi!.complete();
      await s1;
      await s2;

      ic.kapi = null;
      ic.okumaHatasi = null;
      await depo.puanlar(['a']);
      expect(ic.sayi('puanlar'), 2);
      await depo.puanlar(['a']);
      expect(ic.sayi('puanlar'), 2);
    });

    test('farklı anahtarlar aynı anda ayrı istek açar', () async {
      ic.kapi = Completer<void>();
      final f = [
        depo.puanOzeti('a'),
        depo.puanOzeti('b'),
        depo.puanlar(['a']),
        depo.puanlar(['b']),
      ];
      expect(ic.sayi('puanOzeti'), 2);
      expect(ic.sayi('puanlar'), 2);
      ic.kapi!.complete();
      await Future.wait(f);
    });
  });

  group('temizle ve kopyalar', () {
    test('temizle() bütün okuma kayıtlarını boşaltır', () async {
      await depo.puanOzeti('s');
      await depo.benimPuanim('s');
      await depo.puanlar(['s']);
      await depo.yorumlar('s');
      depo.temizle();
      await depo.puanOzeti('s');
      await depo.benimPuanim('s');
      await depo.puanlar(['s']);
      await depo.yorumlar('s');
      for (final ad in ['puanOzeti', 'benimPuanim', 'puanlar', 'yorumlar']) {
        expect(ic.sayi(ad), 2, reason: ad);
      }
    });

    test('temizle() sırasında süren okumanın (eski olabilir) sonucu saklanmaz',
        () async {
      ic.kapi = Completer<void>();
      final yolda = depo.puanOzeti('s');
      depo.temizle();
      // temizlemeden sonra gelen aynı okuma eski isteğe katılmaz, yenisini açar
      final yeni = depo.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 2);
      ic.kapi!.complete();
      await yolda;
      await yeni;
      ic.kapi = null;
      await depo.puanOzeti('s'); // yeni isteğin sonucu saklandı
      expect(ic.sayi('puanOzeti'), 2);
    });

    test(
        'dönen liste ve haritalar kopyadır: değiştirmek saklanan değeri bozmaz',
        () async {
      ic.yorumDeposu['s'] = [_yorum('a'), _yorum('b')];
      ic.benim['a'] = 4;
      final l1 = await depo.yorumlar('s');
      l1.clear();
      final l2 = await depo.yorumlar('s');
      expect(l2.length, 2);
      l2.removeLast();
      expect((await depo.yorumlar('s')).length, 2);

      final p1 = await depo.puanlar(['a']);
      p1.ozet.clear();
      p1.benim.clear();
      final p2 = await depo.puanlar(['a']);
      expect(p2.ozet.keys, ['a']);
      expect(p2.benim, {'a': 4});
      expect(ic.sayi('puanlar'), 1);
    });
  });

  group('olustur ve onbellekTemizle', () {
    test(
        'GeriBildirimDeposu.olustur() önbellekli depo döner; Firestore sorguları önbellekten gelir',
        () async {
      final firebaseVar =
          firebaseProjeId.isNotEmpty && firebaseApiAnahtari.isNotEmpty;
      var ozetSorgusu = 0, listeSorgusu = 0, yazma = 0;
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
        if (u.contains(':runAggregationQuery')) {
          ozetSorgusu++;
          return http.Response(
              jsonEncode([
                {
                  'result': {
                    'aggregateFields': {
                      'n': {'integerValue': '3'},
                      'ort': {'doubleValue': 4.5}
                    }
                  }
                }
              ]),
              200);
        }
        if (u.contains(':runQuery')) {
          listeSorgusu++;
          return http.Response(
              jsonEncode([
                {'readTime': '2026-11-02T10:00:00Z'}
              ]),
              200);
        }
        if (r.method == 'PATCH' || u.contains(':commit')) {
          yazma++;
          return http.Response('{}', 200);
        }
        return http.Response('{}', 200);
      });
      final gercek = GeriBildirimDeposu.olustur(istemci: istemci);
      expect(gercek, isA<OnbellekliGeriBildirim>());
      if (!firebaseVar) {
        expect(gercek.cevrimici, isFalse); // Firebase ayarı yok: yerel depo
        return;
      }
      expect(gercek.cevrimici, isTrue);

      expect((await gercek.puanOzeti('s')).adet, 3);
      expect((await gercek.puanOzeti('s')).ortalama, 4.5);
      await gercek.puanlar(['a', 'b']);
      await gercek.puanlar(['b', 'a']);
      await gercek.yorumlar('s');
      await gercek.yorumlar('s');
      expect(ozetSorgusu, 1);
      expect(listeSorgusu, 2, reason: 'bir puan listesi + bir yorum listesi');

      await gercek.puanVer('a', 5); // yazma: ilgili kayıtlar düşer
      expect(yazma, 1);
      await gercek.puanOzeti('s'); // a'yı içermiyor: önbellekte
      await gercek.puanlar(['a', 'b']);
      expect(ozetSorgusu, 1);
      expect(listeSorgusu, 3);

      (gercek as OnbellekliGeriBildirim).temizle();
      await gercek.puanOzeti('s');
      expect(ozetSorgusu, 2);
    });

    test(
        'onbellekTemizle(): önbellekli depoyu boşaltır, diğer depolarda zararsızdır',
        () async {
      await depo.puanOzeti('s');
      depo.onbellekTemizle();
      await depo.puanOzeti('s');
      expect(ic.sayi('puanOzeti'), 2);

      final GeriBildirimDeposu sade = ic; // önbellekli değil
      sade.onbellekTemizle();
      YerelDepo().onbellekTemizle();
      expect(ic.sayi('puanOzeti'), 2);
    });
  });

  group('ana sayfa', () {
    testWidgets(
        'gün değiştirip geri dönmek aynı öğünün puan ve yorumlarını yeniden sorgulamaz',
        (t) async {
      final yerel = _SayacliYerel();
      await _anaSayfa(t, OnbellekliGeriBildirim(yerel, saat: () => an));
      expect(yerel.puanlarCagri, 1);
      expect(yerel.yorumlarCagri, 1);

      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      expect(yerel.puanlarCagri, 2);
      expect(yerel.yorumlarCagri, 2);

      await t.tap(find.byTooltip('Önceki gün'));
      await t.pumpAndSettle();
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(yerel.puanlarCagri, 2, reason: 'önbellekten');
      expect(yerel.yorumlarCagri, 2, reason: 'önbellekten');
    });

    testWidgets('aşağı çekip yenileme puan ve yorum önbelleğini boşaltır',
        (t) async {
      final yerel = _SayacliYerel();
      await _anaSayfa(t, OnbellekliGeriBildirim(yerel, saat: () => an));
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Önceki gün'));
      await t.pumpAndSettle();
      expect(yerel.puanlarCagri, 2);
      expect(yerel.yorumlarCagri, 2);

      await t.fling(find.byType(OgunKarti), const Offset(0, 300), 1000);
      await t.pumpAndSettle();

      // yenileme sonrası gün değiştirince ikisi de yeniden okunur (önbellekte kalsaydı sayılar artmazdı)
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      expect(yerel.puanlarCagri, 3);
      expect(yerel.yorumlarCagri, 3);
    });

    testWidgets('Diğer > Yenile puan ve yorum önbelleğini boşaltır', (t) async {
      final yerel = _SayacliYerel();
      final menuDepo = _MenuDepo();
      await _anaSayfa(t, OnbellekliGeriBildirim(yerel, saat: () => an),
          depo: menuDepo);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Önceki gün'));
      await t.pumpAndSettle();
      expect(yerel.puanlarCagri, 2);
      expect(yerel.yorumlarCagri, 2);

      // menü yüklenirken iskelet görünür (gerçek ağda olduğu gibi); bitince öğün kartı yeniden kurulur
      menuDepo.kapi = Completer<void>();
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Yenile'));
      await t.pump();
      expect(find.byType(IskeletGovde), findsOneWidget);
      menuDepo.kapi!.complete();
      await t.pumpAndSettle();

      // önbellek boşaltıldığı için yeni kart puanları ve yorumları yeniden okur (önbellekte kalsaydı sayılar artmazdı)
      expect(find.byType(IskeletGovde), findsNothing);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(menuDepo.menuCagri, 2);
      expect(yerel.puanlarCagri, 3);
      expect(yerel.yorumlarCagri, 3);
    });

    testWidgets(
        'aşağı çekip yenileme yeni menü gelince ekrandaki satırların puanlarını hemen yeniden okur',
        (t) async {
      final yerel = _SayacliYerel();
      final menuDepo = _TazeMenuDepo();
      await _anaSayfa(t, OnbellekliGeriBildirim(yerel, saat: () => an),
          depo: menuDepo);
      expect(yerel.puanlarCagri, 1);

      await t.fling(find.byType(OgunKarti), const Offset(0, 300), 1000);
      await t.pumpAndSettle();

      // gün değiştirmeden: yeni Ogun örneği geldiği için kart, boşaltılmış önbellekten puanları yeniden okur
      expect(menuDepo.menuCagri, 2);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(yerel.puanlarCagri, 2);
    });

    testWidgets(
        'otomatik (arka plandan dönünce) yenileme ve okul değişikliği önbelleği boşaltmaz',
        (t) async {
      var simdi = DateTime.utc(2026, 11, 2, 10, 0);
      final yerel = _SayacliYerel();
      final depoMenu = _MenuDepo();
      await _anaSayfa(t, OnbellekliGeriBildirim(yerel, saat: () => an),
          depo: depoMenu, simdi: () => simdi);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Önceki gün'));
      await t.pumpAndSettle();
      expect(yerel.puanlarCagri, 2);
      expect(depoMenu.menuCagri, 1);

      simdi = DateTime.utc(2026, 11, 2, 13, 0); // 3 saat geçti: sessiz yenileme
      for (final d in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        t.binding.handleAppLifecycleStateChanged(d);
      }
      await t.pumpAndSettle();
      expect(depoMenu.menuCagri, 2, reason: 'menü gerçekten yenilendi');

      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      expect(yerel.puanlarCagri, 2, reason: 'önbellek korundu');
      expect(yerel.yorumlarCagri, 2, reason: 'önbellek korundu');
    });

    testWidgets(
        'önbellekli depoyla oy verilip dönülünce satırdaki puan eski önbelleği göstermez',
        (t) async {
      await _anaSayfa(t, OnbellekliGeriBildirim(YerelDepo(), saat: () => an));
      expect(find.text('Puanla'), findsNWidgets(2));
      await t.tap(find.text('Mercimek Çorbası'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('5 yıldız'));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('5.0 · 1 oy · senin: 5'), findsOneWidget);
      expect(find.text('Puanla'), findsNWidgets(1)); // Pirinç Pilavı satırı

      // ayrıntı sayfasına yeniden girince de güncel puan görünür
      await t.tap(find.text('Mercimek Çorbası'));
      await t.pumpAndSettle();
      expect(find.text('Ortalama · 1 oy'), findsOneWidget);
      expect(find.text('Senin puanın: 5 / 5 (değiştirmek için dokun)'),
          findsOneWidget);
    });

    testWidgets(
        'enjekte edilen önbelleksiz depo olduğu gibi kullanılır (sarılmaz, yenileme zararsız)',
        (t) async {
      final yerel = _SayacliYerel();
      await _anaSayfa(t, yerel);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Önceki gün'));
      await t.pumpAndSettle();
      expect(yerel.puanlarCagri, 3,
          reason: 'önbellek yok: her gösterimde okur');
      await t.fling(find.byType(OgunKarti), const Offset(0, 300), 1000);
      await t.pumpAndSettle();
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
    });
  });
}

/// [YerelDepo]yu olduğu gibi kullanır, yalnızca okuma çağrılarını sayar.
class _SayacliYerel extends YerelDepo {
  int puanlarCagri = 0, yorumlarCagri = 0;

  @override
  Future<YemekPuanlari> puanlar(List<String> slotlar) {
    puanlarCagri++;
    return super.puanlar(slotlar);
  }

  @override
  Future<List<Yorum>> yorumlar(String slot) {
    yorumlarCagri++;
    return super.yorumlar(slot);
  }
}

/// Ağa ve diske gitmeyen sahte veri deposu; menü çağrılarını sayar.
class _MenuDepo extends Depo {
  int menuCagri = 0;

  /// Doluysa menü isteği bu tamamlanana kadar bekler (yüklenirken iskeleti yakalamak için).
  Completer<void>? kapi;
  final Universite uni = Universite(
      id: 'ankara',
      ad: 'Ankara Üniversitesi',
      kisa: 'AÜ',
      sehir: 'Ankara',
      kaynak: '',
      ogunler: const ['lunch'],
      fiyatlar: const []);
  final Menu menuVeri = Menu('ankara', null, {
    '2026-11-02': {
      'lunch': Ogun([
        YemekOgesi('Mercimek Çorbası', 120, null, 'mercimek'),
        YemekOgesi('Pirinç Pilavı', 300, null, 'pilav'),
      ], 420)
    },
    '2026-11-03': {
      'lunch':
          Ogun([YemekOgesi('Ezogelin Çorbası', 110, null, 'ezogelin')], 110)
    },
  });

  @override
  Future<List<Universite>> universiteler() async => [uni];
  @override
  Future<Menu> menu(String universiteId) async {
    menuCagri++;
    if (kapi != null) await kapi!.future;
    return menuVeri;
  }

  @override
  Future<String?> seciliUniversite() async => uni.id;
  @override
  Future<void> universiteSec(String id) async {}
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  String? fotoUrl(String universiteId, String? foto) => null;
  @override
  String? yemekFotoUrl(String? img) => null;
}

/// Her istekte yeni Menu/Ogun örnekleri döndürür (gerçek ağdan gelen yanıtın her seferinde yeniden ayrıştırılması gibi).
class _TazeMenuDepo extends _MenuDepo {
  @override
  Future<Menu> menu(String universiteId) async {
    menuCagri++;
    return Menu('ankara', null, {
      '2026-11-02': {
        'lunch': Ogun([
          YemekOgesi('Mercimek Çorbası', 120, null, 'mercimek'),
          YemekOgesi('Pirinç Pilavı', 300, null, 'pilav'),
        ], 420)
      },
    });
  }
}

DateTime _sabahSimdi() => DateTime.utc(2026, 11, 2, 10, 0);

Future<void> _anaSayfa(WidgetTester t, GeriBildirimDeposu gb,
    {_MenuDepo? depo, DateTime Function()? simdi}) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari();
  await t.pumpWidget(MaterialApp(
      theme: ayar.tema(Brightness.light),
      home: AnaSayfa(
          temaAyari: ayar,
          depo: depo ?? _MenuDepo(),
          geriBildirim: gb,
          simdi: simdi ?? _sabahSimdi)));
  await t.pumpAndSettle();
}
