// Denetim F-a: boş öğün listesi, şeması bozuk JSON'un önbelleği bozması, gece yarısı "bugün" yenilenmesi.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/gun_secimi.dart';
import 'package:yemekhane/kalori_hedefi.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/ana_icerik.dart';

Map<String, dynamic> _okul(String id, List<Object?> ogunler) => {
      'id': id,
      'name': 'Okul $id',
      'meals': ogunler,
    };

String _menuJson(String id, String gun) => jsonEncode({
      'university': id,
      'days': {
        gun: {
          'lunch': {
            'items': [
              {'name': 'Mercimek Çorbası', 'kcal': 120}
            ],
            'kcal': 120
          }
        }
      }
    });

http.Response _json(String g) => http.Response(g, 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void _paket(Map<String, String> dosyalar) {
  final iletisim = TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;
  for (final k in dosyalar.keys) {
    rootBundle.evict('assets/data/$k');
  }
  iletisim.setMockMessageHandler('flutter/assets', (ByteData? m) async {
    final istenen =
        utf8.decode(m!.buffer.asUint8List(m.offsetInBytes, m.lengthInBytes));
    final icerik = dosyalar[istenen.replaceFirst('assets/data/', '')];
    if (icerik == null) return null;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(icerik)));
  });
  addTearDown(() {
    iletisim.setMockMessageHandler('flutter/assets', null);
    for (final k in dosyalar.keys) {
      rootBundle.evict('assets/data/$k');
    }
  });
}

class _SahteDepo extends Depo {
  final Universite okul;
  final Menu menuVeri;
  _SahteDepo(this.okul, this.menuVeri);
  @override
  Future<List<Universite>> universiteler() async => [okul];
  @override
  Future<Menu> menu(String id) async => menuVeri;
  @override
  Future<String?> seciliUniversite() async => 'ankara';
  @override
  Future<void> universiteSec(String id) async {}
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  String? fotoUrl(String u, String? f) => null;
  @override
  String? yemekFotoUrl(String? i) => null;
}

Universite _uni(List<String> ogunler) => Universite(
    id: 'ankara',
    ad: 'Ankara Üniversitesi',
    kisa: 'ankara',
    sehir: 'Ankara',
    kaynak: '',
    ogunler: ogunler,
    fiyatlar: const []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1. boş / tanınmayan öğün listesi', () {
    test('Universite.fromJson desteklenen öğünü olmayan kaydı reddeder', () {
      expect(() => Universite.fromJson(_okul('a', [])), throwsFormatException);
      expect(() => Universite.fromJson(_okul('a', ['brunch'])),
          throwsFormatException);
      expect(Universite.fromJson(_okul('a', ['brunch', 'lunch'])).ogunler,
          contains('lunch'));
    });

    test('aktifOgun boş listede çökmez', () {
      expect(aktifOgun(_uni([]), 'lunch'), 'lunch');
    });

    test('ağdan gelen boş öğünlü kayıt atlanır, paketteki kayıt kullanılır',
        () async {
      _paket({
        'index.json': jsonEncode({
          'universities': [
            _okul('ankara', ['lunch'])
          ]
        })
      });
      final depo = Depo(
          istemci: MockClient((r) async => _json(jsonEncode({
                'universities': [_okul('ankara', [])]
              }))));
      final liste = await depo.universiteler();
      expect(liste.map((u) => u.id), ['ankara']);
      expect(liste.single.ogunler, ['lunch']);
    });

    testWidgets('AnaIcerik boş öğün listesinde açıklama gösterir', (t) async {
      final menu = Menu('ankara', null, {'2026-11-02': {}});
      await t.pumpWidget(MaterialApp(
          home: AnaIcerik(
              uni: _uni([]),
              menu: menu,
              bugun: '2026-11-02',
              tarih: '2026-11-02',
              ogun: 'lunch',
              yon: 0,
              depo: Depo(),
              geriBildirim: YerelDepo(),
              favoriler: FavoriDeposu(),
              kaloriHedefi: KaloriHedefi(),
              simdi: () => DateTime.utc(2026, 11, 2, 12),
              gunSec: (_) {},
              eslesmeyeGit: (_, __) {},
              ogunSec: (_) {},
              yenile: () async {})));
      expect(t.takeException(), isNull);
      expect(find.text('Bu okulun menüsü şu an okunamıyor.'), findsOneWidget);
    });
  });

  group('2. şeması bozuk JSON', () {
    for (final bozuk in ['[]', '{"error":"x"}', '{"days":[]}']) {
      test('menu.json $bozuk önbelleğe yazılmaz, önbellekteki kopyaya düşülür',
          () async {
        SharedPreferences.setMockInitialValues(
            {'onbellek/ankara/menu.json': _menuJson('ankara', '2099-01-05')});
        _paket({});
        final depo = Depo(istemci: MockClient((r) async => _json(bozuk)));
        final menu = await depo.menu('ankara');
        expect(menu.tarihler, ['2099-01-05']);
        final p = await SharedPreferences.getInstance();
        expect(p.getString('onbellek/ankara/menu.json'),
            _menuJson('ankara', '2099-01-05'));
        expect(depo.cevrimdisi, isTrue);
      });
    }

    test('bozuk önbellek atlanır, pakete düşülür', () async {
      SharedPreferences.setMockInitialValues(
          {'onbellek/ankara/menu.json': '{"error":"x"}'});
      _paket({'ankara/menu.json': _menuJson('ankara', '2026-11-03')});
      final depo =
          Depo(istemci: MockClient((r) async => http.Response('hata', 500)));
      expect((await depo.menu('ankara')).tarihler, ['2026-11-03']);
    });

    test('index.json: {"error":..} yazılmaz, paket listesi döner', () async {
      _paket({
        'index.json': jsonEncode({
          'universities': [
            _okul('ankara', ['lunch'])
          ]
        })
      });
      final depo =
          Depo(istemci: MockClient((r) async => _json('{"error":"x"}')));
      expect((await depo.universiteler()).map((u) => u.id), ['ankara']);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('onbellek/index.json'), isNull);
    });

    test('geçerli menü yine önbelleğe yazılır', () async {
      final depo = Depo(
          istemci: MockClient(
              (r) async => _json(_menuJson('ankara', '2026-11-02'))));
      await depo.menu('ankara');
      final p = await SharedPreferences.getInstance();
      expect(p.getString('onbellek/ankara/menu.json'), isNotNull);
    });
  });

  group('3. gece yarısı', () {
    testWidgets('ön plandayken gün dönünce "bugün" yenilenir', (t) async {
      var simdi = DateTime.utc(2026, 11, 2, 23, 59, 30);
      final menu = Menu('ankara', null, {
        for (final g in ['2026-11-02', '2026-11-03'])
          g: {
            'lunch': Ogun([YemekOgesi('Mercimek Çorbası', 120)], 120)
          }
      });
      final depo = _SahteDepo(_uni(['lunch']), menu);
      final ayar = TemaAyari();
      await t.pumpWidget(MaterialApp(
          theme: ayar.tema(Brightness.light),
          home: AnaSayfa(
              temaAyari: ayar,
              depo: depo,
              geriBildirim: YerelDepo(),
              simdi: () => simdi)));
      await t.pumpAndSettle();
      AnaIcerik icerik() => t.widget<AnaIcerik>(find.byType(AnaIcerik));
      expect(icerik().bugun, '2026-11-02');
      expect(icerik().tarih, '2026-11-02');

      simdi = DateTime.utc(2026, 11, 3, 0, 0, 5);
      await t.pump(const Duration(seconds: 40));
      await t.pumpAndSettle();
      expect(icerik().bugun, '2026-11-03');
      expect(icerik().tarih, '2026-11-03');
    });
  });
}
