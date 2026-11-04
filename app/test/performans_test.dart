import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';

/// Performans (statik inceleme sonrası): gereksiz ağ istekleri ve yeniden yüklemeler. Süre ölçülmez; yalnızca
/// çağrı sayıları sayılır (sayılar gerçek ağ isteği sayısıyla orantılıdır: her çağrı bir Firestore isteğidir).

/// [YerelDepo]yu sarar ve hangi yöntemin kaç kez çağrıldığını sayar.
class _SayacDepo implements GeriBildirimDeposu {
  final YerelDepo _ic = YerelDepo();
  final Map<String, int> cagri = {};
  int sayi(String ad) => cagri[ad] ?? 0;
  void _say(String ad) => cagri[ad] = sayi(ad) + 1;

  @override
  bool get cevrimici => false;
  @override
  Future<String> kullaniciId() {
    _say('kullaniciId');
    return _ic.kullaniciId();
  }

  @override
  Future<PuanOzeti> puanOzeti(String slot) {
    _say('puanOzeti');
    return _ic.puanOzeti(slot);
  }

  @override
  Future<int?> benimPuanim(String slot) {
    _say('benimPuanim');
    return _ic.benimPuanim(slot);
  }

  @override
  Future<YemekPuanlari> puanlar(List<String> slotlar) {
    _say('puanlar');
    return _ic.puanlar(slotlar);
  }

  @override
  Future<void> puanVer(String slot, int yildiz) {
    _say('puanVer');
    return _ic.puanVer(slot, yildiz);
  }

  @override
  Future<List<Yorum>> yorumlar(String slot) {
    _say('yorumlar');
    return _ic.yorumlar(slot);
  }

  @override
  Future<void> yorumEkle(String slot, String ad, String metin) {
    _say('yorumEkle');
    return _ic.yorumEkle(slot, ad, metin);
  }

  @override
  Future<void> yorumSil(Yorum y) {
    _say('yorumSil');
    return _ic.yorumSil(y);
  }
}

/// Ağa ve diske gitmeyen sahte veri deposu.
class _SahteDepo extends Depo {
  final Universite uni;
  final Menu menuVeri;
  _SahteDepo(this.uni, this.menuVeri);

  @override
  Future<List<Universite>> universiteler() async => [uni];
  @override
  Future<Menu> menu(String universiteId) async => menuVeri;
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

Universite _uni() => Universite(
    id: 'ankara',
    ad: 'Ankara Üniversitesi',
    kisa: 'AÜ',
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

Menu _menu() => Menu('ankara', null, {
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

DateTime _simdi() => DateTime.utc(2026, 11, 2, 10, 0);

Future<void> _anaSayfa(WidgetTester t, _SayacDepo gb,
    {FavoriDeposu? favoriler}) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari();
  await t.pumpWidget(MaterialApp(
      theme: ayar.tema(Brightness.light),
      home: AnaSayfa(
          temaAyari: ayar,
          depo: _SahteDepo(_uni(), _menu()),
          geriBildirim: gb,
          favoriler: favoriler,
          simdi: _simdi)));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GeriBildirimBolumu: görünmeyen sonuç için istek atılmaz', () {
    Future<_SayacDepo> ac(WidgetTester t, {required bool puanGoster}) async {
      final gb = _SayacDepo();
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: GeriBildirimBolumu(
                      depo: gb,
                      slot: 'ankara_2026-11-02_lunch',
                      puanGoster: puanGoster)))));
      await t.pumpAndSettle();
      return gb;
    }

    testWidgets(
        'puan kartı gizliyken (yemek bazlı puanlama) puan özeti ve "benim puanım" okunmaz, yorumlar okunur',
        (t) async {
      final gb = await ac(t, puanGoster: false);
      expect(gb.sayi('puanOzeti'), 0);
      expect(gb.sayi('benimPuanim'), 0);
      expect(gb.sayi('yorumlar'), 1);
      expect(gb.sayi('kullaniciId'), greaterThanOrEqualTo(1));
      expect(find.text('Yorumlar'), findsOneWidget);
      expect(find.text('İlk yorumu sen yaz.'), findsOneWidget);
    });

    testWidgets('puan kartı görünürken puan özeti ve "benim puanım" da okunur',
        (t) async {
      final gb = await ac(t, puanGoster: true);
      expect(gb.sayi('puanOzeti'), 1);
      expect(gb.sayi('benimPuanim'), 1);
      expect(gb.sayi('yorumlar'), 1);
      expect(find.text('Henüz oy yok'), findsOneWidget);
    });

    testWidgets('puan kartı görünürken verilen puan okunur ve gösterilir',
        (t) async {
      await YerelDepo().puanVer('ankara_2026-11-02_lunch', 4);
      final gb = await ac(t, puanGoster: true);
      expect(gb.sayi('benimPuanim'), 1);
      expect(
          find.text('Puanın: 4 / 5 (değiştirmek için dokun)'), findsOneWidget);
      expect(find.text('4.0 · 1 oy'), findsOneWidget);
    });
  });

  group('ana sayfa: gereksiz yeniden yükleme yok', () {
    testWidgets(
        'açılışta ve her gün değişiminde öğün başına tek puan sorgusu ve tek yorum sorgusu atılır; ayrı özet sorgusu yoktur',
        (t) async {
      final gb = _SayacDepo();
      await _anaSayfa(t, gb);
      expect(gb.sayi('puanlar'), 1);
      expect(gb.sayi('yorumlar'), 1);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      expect(find.text('Ezogelin Çorbası'), findsOneWidget);
      expect(gb.sayi('puanlar'), 2);
      expect(gb.sayi('yorumlar'), 2);
      expect(gb.sayi('puanOzeti'), 0);
      expect(gb.sayi('benimPuanim'), 0);
    });

    testWidgets(
        'kalbe dokunmak öğünün puanlarını ve yorumlarını yeniden yüklemez',
        (t) async {
      final gb = _SayacDepo();
      final favoriler = FavoriDeposu();
      await _anaSayfa(t, gb, favoriler: favoriler);
      expect(gb.sayi('puanlar'), 1);
      expect(gb.sayi('yorumlar'), 1);
      await t.tap(find.byTooltip('Favorilere ekle').first);
      await t.pumpAndSettle();
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
      expect(gb.sayi('puanlar'), 1);
      expect(gb.sayi('yorumlar'), 1);
      await t.tap(find.byTooltip('Favorilerden çıkar'));
      await t.pumpAndSettle();
      expect(gb.sayi('puanlar'), 1);
      expect(gb.sayi('yorumlar'), 1);
    });

    testWidgets(
        'öğün değiştirmeden aynı güne dönmek (geri / ileri) her seferinde yalnızca o öğünü okur',
        (t) async {
      final gb = _SayacDepo();
      await _anaSayfa(t, gb);
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Önceki gün'));
      await t.pumpAndSettle();
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      // üç öğün görünümü: açılış, ertesi gün, geri dönüş (her biri bir puan + bir yorum sorgusu)
      expect(gb.sayi('puanlar'), 3);
      expect(gb.sayi('yorumlar'), 3);
    });
  });
}
