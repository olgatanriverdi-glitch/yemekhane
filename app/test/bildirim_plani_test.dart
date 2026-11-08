// Günlük menü bildirimi planlaması (lib/bildirim_plani.dart): saf işlev, ağ / disk / eklenti yok.
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/bildirim_plani.dart';
import 'package:yemekhane/models.dart';

Universite _uni(
        {String kisa = 'AÜ',
        String ad = 'Ankara Üniversitesi',
        List<String> ogunler = const ['lunch', 'dinner']}) =>
    Universite(
        id: 'ankara',
        ad: ad,
        kisa: kisa,
        sehir: 'Ankara',
        kaynak: '',
        ogunler: ogunler,
        fiyatlar: const []);

YemekOgesi _y(String ad, [String? anahtar]) =>
    YemekOgesi(ad, null, null, anahtar);

Ogun _ogun(List<YemekOgesi> yemekler) => Ogun(yemekler, null);

Ogun _tatil(String not) => Ogun(const [], null, null, false, not);

Menu _menu(Map<String, Map<String, Ogun>> gunler) =>
    Menu('ankara', null, gunler);

/// [baslangic]tan başlayarak [gun] gün, her gün öğlede "Yemek <tarih>" olan menü.
Menu _uzunMenu(String baslangic, int gun) {
  final b = DateTime.parse(baslangic);
  return _menu({
    for (var i = 0; i < gun; i++)
      isoTarih(DateTime.utc(b.year, b.month, b.day + i)): {
        'lunch': _ogun([_y('Yemek $i')])
      }
  });
}

/// Pazartesi 2 Kasım 2026, 10:00 (Türkiye duvar saati).
DateTime _sabah() => DateTime.utc(2026, 11, 2, 10, 0);

List<PlanliBildirim> _plan(Menu menu,
        {Universite? uni,
        int saatDk = 10 * 60 + 30,
        DateTime? simdi,
        Set<String> favoriler = const {},
        int gunSayisi = 7}) =>
    bildirimPlani(
        menu: menu,
        uni: uni ?? _uni(),
        saatDk: saatDk,
        simdi: simdi ?? _sabah(),
        favoriler: favoriler,
        gunSayisi: gunSayisi);

String _tarih(PlanliBildirim p) => isoTarih(p.zaman);

void main() {
  group('saat ve geçmiş', () {
    final menu = _uzunMenu('2026-11-02', 14);

    test('saat henüz gelmediyse bugün de planlanır (10:00 < 10:30)', () {
      final p = _plan(menu);
      expect(p.first.kimlik, 20261102);
      expect(p.first.zaman, DateTime.utc(2026, 11, 2, 10, 30));
    });

    test('geçmiş saat atlanır: 10:31 ve 23:59 bugünü planlamaz', () {
      for (final simdi in [
        DateTime.utc(2026, 11, 2, 10, 31),
        DateTime.utc(2026, 11, 2, 23, 59),
      ]) {
        final p = _plan(menu, simdi: simdi);
        expect(p.first.kimlik, 20261103, reason: '$simdi');
        expect(p.length, 6, reason: 'pencere bugünden başlayan 7 gündür');
      }
    });

    test('tam o an (10:30:00) geçmiş sayılır; bir saniye önce planlanır', () {
      expect(_plan(menu, simdi: DateTime.utc(2026, 11, 2, 10, 30)).first.kimlik,
          20261103);
      expect(
          _plan(menu, simdi: DateTime.utc(2026, 11, 2, 10, 29, 59))
              .first
              .kimlik,
          20261102);
    });

    test('yerel (UTC olmayan) şimdi de duvar saati alanlarıyla karşılaştırılır',
        () {
      expect(_plan(menu, simdi: DateTime(2026, 11, 2, 10, 0)),
          _plan(menu, simdi: DateTime.utc(2026, 11, 2, 10, 0)));
      expect(_plan(menu, simdi: DateTime(2026, 11, 2, 11, 0)).first.kimlik,
          20261103);
    });

    test('ayar saati gün dışındaysa en yakın uca çekilir (23:59 / 00:00)', () {
      expect(_plan(menu, saatDk: 99999).first.zaman,
          DateTime.utc(2026, 11, 2, 23, 59));
      expect(
          _plan(menu, saatDk: -5).first.zaman, DateTime.utc(2026, 11, 3, 0, 0),
          reason: '00:00 bugün için geçmiştir');
    });
  });

  group('atlanan günler', () {
    test('menüsü olmayan, tatil, hafta sonu ve yemeksiz günler atlanır', () {
      final menu = _menu({
        '2026-11-02': {
          'lunch': _ogun([_y('Mercimek Çorbası')])
        },
        '2026-11-03': {
          'lunch': _ogun([_y('Ezogelin Çorbası')])
        },
        // 4 Kasım tatil: iki öğünde de yemek yok, yalnızca not
        '2026-11-04': {'lunch': _tatil('Tatil'), 'dinner': _tatil('Tatil')},
        '2026-11-05': {
          'lunch': _ogun([_y('Yayla Çorbası')])
        },
        // 6 Kasım menüde var ama yalnızca boş adlı öğeler
        '2026-11-06': {
          'lunch': _ogun([_y('  '), _y('')])
        },
        // 7 - 8 Kasım (hafta sonu) menüde yok
        '2026-11-09': {
          'lunch': _ogun([_y('Domates Çorbası')])
        },
      });
      final p = _plan(menu);
      expect(p.map((b) => b.kimlik), [20261102, 20261103, 20261105]);
      expect(p.map(_tarih), ['2026-11-02', '2026-11-03', '2026-11-05']);
    });

    test('hafta sonu da menüde yemekle yer alıyorsa planlanır', () {
      final menu = _menu({
        '2026-11-07': {
          'lunch': _ogun([_y('Cumartesi Yemeği')])
        },
      });
      final p = _plan(menu, simdi: DateTime.utc(2026, 11, 6, 9, 0));
      expect(p.single.kimlik, 20261107);
    });

    test('yalnızca okulun sunmadığı öğünde yemek olan gün atlanır', () {
      final menu = _menu({
        '2026-11-02': {
          'dinner': _ogun([_y('Fırın Makarna')])
        },
        '2026-11-03': {
          'lunch': _ogun([_y('Kuru Fasulye')])
        },
      });
      final p = _plan(menu, uni: _uni(ogunler: const ['lunch']));
      expect(p.map((b) => b.kimlik), [20261103]);
    });

    test('menü tamamen boşsa ya da bugünden önceyse plan boştur', () {
      expect(_plan(_menu({})), isEmpty);
      expect(
          _plan(_menu({
            '2026-10-30': {
              'lunch': _ogun([_y('Eski Yemek')])
            }
          })),
          isEmpty);
    });
  });

  group('metin ve başlık', () {
    test('öğle yemekleri: 3 ya da daha azı olduğu gibi, fazlası "+N"', () {
      final menu = _menu({
        '2026-11-02': {
          'lunch': _ogun([
            _y('Mercimek Çorbası'),
            _y('  Pirinç Pilavı '),
            _y('Cacık'),
          ])
        },
        '2026-11-03': {
          'lunch': _ogun([
            _y('Ezogelin Çorbası'),
            _y('Tavuk Sote'),
            _y('Bulgur Pilavı'),
            _y('Ayran'),
            _y('Sütlaç'),
          ])
        },
        '2026-11-04': {
          'lunch': _ogun([_y('Kuru Fasulye'), _y('Pilav')])
        },
        '2026-11-05': {
          'lunch': _ogun([_y('A'), _y('B'), _y('C'), _y('D')])
        },
      });
      final p = _plan(menu);
      expect(p[0].metin, 'Mercimek Çorbası, Pirinç Pilavı, Cacık');
      expect(p[1].metin, 'Ezogelin Çorbası, Tavuk Sote, Bulgur Pilavı +2');
      expect(p[2].metin, 'Kuru Fasulye, Pilav');
      expect(p[3].metin, 'A, B, C +1');
    });

    test('başlık "<kısa ad> · bugün öğle"; kısa ad yoksa tam ad', () {
      final menu = _uzunMenu('2026-11-02', 2);
      expect(_plan(menu).first.baslik, 'AÜ · bugün öğle');
      expect(_plan(menu, uni: _uni(kisa: '')).first.baslik,
          'Ankara Üniversitesi · bugün öğle');
      expect(_plan(menu, uni: _uni(kisa: '  ')).first.baslik,
          'Ankara Üniversitesi · bugün öğle');
    });

    test('öğle yoksa günün ilk öğünü: kahvaltı, sonra akşam, sonra vejetaryen',
        () {
      final menu = _menu({
        '2026-11-02': {
          'dinner': _ogun([_y('Fırın Makarna')]),
          'breakfast': _ogun([_y('Simit'), _y('Peynir')]),
        },
        '2026-11-03': {
          'dinner': _ogun([_y('Mantı')])
        },
        '2026-11-04': {
          'vegetarian': _ogun([_y('Sebze Güveç')])
        },
        // öğle boş (not var): kahvaltı değil, dolu olan ilk öğün seçilir
        '2026-11-05': {
          'lunch': _tatil('Yemek verilmiyor'),
          'dinner': _ogun([_y('Pilav')])
        },
      });
      final uni =
          _uni(ogunler: const ['breakfast', 'lunch', 'dinner', 'vegetarian']);
      final p = _plan(menu, uni: uni);
      expect(p[0].baslik, 'AÜ · bugün kahvaltı');
      expect(p[0].metin, 'Simit, Peynir');
      expect(p[1].baslik, 'AÜ · bugün akşam');
      expect(p[1].metin, 'Mantı');
      expect(p[2].baslik, 'AÜ · bugün vejetaryen');
      expect(p[2].metin, 'Sebze Güveç');
      expect(p[3].baslik, 'AÜ · bugün akşam');
    });

    test('öğle de akşam da varsa öğle seçilir', () {
      final menu = _menu({
        '2026-11-02': {
          'dinner': _ogun([_y('Fırın Makarna')]),
          'lunch': _ogun([_y('Kuru Fasulye')]),
        },
      });
      final p = _plan(menu);
      expect(p.single.baslik, 'AÜ · bugün öğle');
      expect(p.single.metin, 'Kuru Fasulye');
    });

    test('hiçbir başlıkta ve metinde emoji yoktur', () {
      final menu = _uzunMenu('2026-11-02', 7);
      final emoji = RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]',
          unicode: true);
      for (final b in _plan(menu, favoriler: {'x'})) {
        expect(emoji.hasMatch(b.baslik), isFalse, reason: b.baslik);
        expect(emoji.hasMatch(b.metin), isFalse, reason: b.metin);
      }
    });
  });

  group('favori önceliği', () {
    Menu gun(Map<String, Ogun> ogunler) => _menu({'2026-11-02': ogunler});

    test('tek favori: "Bugün favorin Mantı menüde" öne çıkar', () {
      final menu = gun({
        'lunch': _ogun([
          _y('Mercimek Çorbası', 'mercimek'),
          _y('Mantı', 'manti'),
          _y('Cacık', 'cacik'),
        ])
      });
      final p = _plan(menu, favoriler: {'manti'});
      expect(p.single.metin, 'Bugün favorin Mantı menüde');
      expect(p.single.baslik, 'AÜ · bugün öğle');
    });

    test('iki favori "ve" ile, daha fazlası "N yemek daha" ile yazılır', () {
      final menu = gun({
        'lunch': _ogun([
          _y('Mantı', 'manti'),
          _y('Cacık', 'cacik'),
          _y('Ayran', 'ayran'),
          _y('Sütlaç', 'sutlac'),
        ])
      });
      expect(_plan(menu, favoriler: {'manti', 'cacik'}).single.metin,
          'Bugün favorilerin Mantı ve Cacık menüde');
      expect(_plan(menu, favoriler: {'manti', 'cacik', 'ayran'}).single.metin,
          'Bugün favorilerin Mantı, Cacık ve 1 yemek daha menüde');
      expect(
          _plan(menu, favoriler: {'manti', 'cacik', 'ayran', 'sutlac'})
              .single
              .metin,
          'Bugün favorilerin Mantı, Cacık ve 2 yemek daha menüde');
    });

    test('favori yoksa ya da eşleşmezse normal liste; anahtarsız öğe eşleşmez',
        () {
      final menu = gun({
        'lunch': _ogun([_y('Mantı', 'manti'), _y('Ayran')])
      });
      expect(_plan(menu).single.metin, 'Mantı, Ayran');
      expect(_plan(menu, favoriler: {'baska'}).single.metin, 'Mantı, Ayran');
      expect(_plan(menu, favoriler: {''}).single.metin, 'Mantı, Ayran');
    });

    test('favori yalnızca akşamdaysa başlık akşama döner', () {
      final menu = gun({
        'lunch': _ogun([_y('Kuru Fasulye', 'fasulye')]),
        'dinner': _ogun([_y('Fırın Makarna', 'makarna')]),
      });
      final p = _plan(menu, favoriler: {'makarna'});
      expect(p.single.baslik, 'AÜ · bugün akşam');
      expect(p.single.metin, 'Bugün favorin Fırın Makarna menüde');
    });

    test('favori hem öğlede hem akşamda varsa öğle öncelikli', () {
      final menu = gun({
        'lunch': _ogun([_y('Mantı', 'manti')]),
        'dinner': _ogun([_y('Mantı', 'manti'), _y('Cacık', 'cacik')]),
      });
      final p = _plan(menu, favoriler: {'manti', 'cacik'});
      expect(p.single.baslik, 'AÜ · bugün öğle');
      expect(p.single.metin, 'Bugün favorin Mantı menüde');
    });

    test('aynı favori aynı öğünde iki kez geçse tek sayılır', () {
      final menu = gun({
        'lunch': _ogun([_y('Mantı', 'manti'), _y('Mantı', 'manti')])
      });
      expect(_plan(menu, favoriler: {'manti'}).single.metin,
          'Bugün favorin Mantı menüde');
    });

    test('favori yalnızca o günün bildirimini değiştirir', () {
      final menu = _menu({
        '2026-11-02': {
          'lunch': _ogun([_y('Mantı', 'manti'), _y('Cacık')])
        },
        '2026-11-03': {
          'lunch': _ogun([_y('Kuru Fasulye'), _y('Pilav')])
        },
      });
      final p = _plan(menu, favoriler: {'manti'});
      expect(p[0].metin, 'Bugün favorin Mantı menüde');
      expect(p[1].metin, 'Kuru Fasulye, Pilav');
    });

    test('okulun sunmadığı öğündeki favori öne çıkmaz', () {
      final menu = gun({
        'lunch': _ogun([_y('Kuru Fasulye', 'fasulye')]),
        'dinner': _ogun([_y('Mantı', 'manti')]),
      });
      final p = _plan(menu,
          uni: _uni(ogunler: const ['lunch']), favoriler: {'manti'});
      expect(p.single.metin, 'Kuru Fasulye');
    });
  });

  group('7 gün sınırı', () {
    final menu = _uzunMenu('2026-11-02', 30);

    test('en çok 7 bildirim, bugünden başlayan 7 gün', () {
      final p = _plan(menu);
      expect(p.length, 7);
      expect(p.first.kimlik, 20261102);
      expect(p.last.kimlik, 20261108);
    });

    test('gunSayisi daha küçükse o kadar; 7den büyük ya da 0 / eksi sınırlanır',
        () {
      expect(_plan(menu, gunSayisi: 3).length, 3);
      expect(_plan(menu, gunSayisi: 30).length, 7);
      expect(_plan(menu, gunSayisi: 0), isEmpty);
      expect(_plan(menu, gunSayisi: -4), isEmpty);
    });

    test('bildirimEnCokGun 7', () => expect(bildirimEnCokGun, 7));
  });

  group('takvim', () {
    test('ay sonu: Ekim sonundan Kasım başına geçer', () {
      final menu = _uzunMenu('2026-10-28', 12);
      final p = _plan(menu, simdi: DateTime.utc(2026, 10, 30, 9, 0));
      expect(p.map((b) => b.kimlik), [
        20261030,
        20261031,
        20261101,
        20261102,
        20261103,
        20261104,
        20261105,
      ]);
      expect(p[2].zaman, DateTime.utc(2026, 11, 1, 10, 30));
    });

    test('yıl sonu: Aralık sonundan Ocak başına geçer', () {
      final menu = _uzunMenu('2026-12-28', 10);
      final p = _plan(menu, simdi: DateTime.utc(2026, 12, 30, 9, 0));
      expect(p.map((b) => b.kimlik).take(4), [
        20261230,
        20261231,
        20270101,
        20270102,
      ]);
    });

    test('artık yıl: 29 Şubat 2028 vardır', () {
      final menu = _uzunMenu('2028-02-25', 10);
      final p = _plan(menu, simdi: DateTime.utc(2028, 2, 27, 9, 0));
      expect(p.map((b) => b.kimlik).take(4),
          [20280227, 20280228, 20280229, 20280301]);
    });
  });

  group('Türkiye saati', () {
    test('zaman Türkiye duvar saatidir; gerçek an UTC+3 farklıdır', () {
      final p = _plan(_uzunMenu('2026-11-02', 3));
      expect(p.first.zaman.isUtc, isTrue);
      expect(p.first.zaman.hour, 10);
      expect(p.first.zaman.minute, 30);
      expect(p.first.utcAn, DateTime.utc(2026, 11, 2, 7, 30));
    });

    test('gece yarısından sonraki saat: kimlik Türkiye gününe bağlıdır', () {
      final p = _plan(_uzunMenu('2026-11-02', 3), saatDk: 15);
      // 00:15 Türkiye = bir önceki gün 21:15 UTC; kimlik yine Türkiye tarihidir
      expect(p.first.kimlik, 20261103);
      expect(p.first.zaman, DateTime.utc(2026, 11, 3, 0, 15));
      expect(p.first.utcAn, DateTime.utc(2026, 11, 2, 21, 15));
    });

    test('cihazın saat dilimi sonucu değiştirmez (yerel ve UTC şimdi aynı)',
        () {
      final menu = _uzunMenu('2026-11-02', 9);
      expect(
          _plan(menu, simdi: DateTime(2026, 11, 2, 10, 0)).map((b) => b.zaman),
          _plan(menu, simdi: DateTime.utc(2026, 11, 2, 10, 0))
              .map((b) => b.zaman));
    });
  });

  group('kimlik ve eşitlik', () {
    test('kimlik tarihten türer: yyyyMMdd', () {
      expect(bildirimKimligi(DateTime(2026, 11, 2)), 20261102);
      expect(bildirimKimligi(DateTime.utc(2027, 1, 5)), 20270105);
      expect(bildirimKimligi(DateTime(2026, 12, 31)), 20261231);
    });

    test('aynı girdi aynı plan: kimlikler tekrarlanabilir, günler farklıdır',
        () {
      final menu = _uzunMenu('2026-11-02', 10);
      final a = _plan(menu), b = _plan(menu);
      expect(a, b);
      expect(a.map((x) => x.kimlik).toSet().length, a.length);
      expect(a.first.hashCode, b.first.hashCode);
      expect(a.first == a[1], isFalse);
    });

    test('saat metni 24 saatlik: 630 -> 10:30', () {
      expect(bildirimSaatMetni(varsayilanBildirimSaatDk), '10:30');
      expect(varsayilanBildirimSaatDk, 630);
      expect(bildirimSaatMetni(5), '00:05');
      expect(bildirimSaatMetni(1439), '23:59');
      expect(bildirimSaatMetni(0), '00:00');
    });
  });
}
