// P5 madde 3: Depo, cihaz depolaması (SharedPreferences) açılamasa ya da yazılamasa da çalışır.
//  - seciliUniversite(): okuma hatası fırlatılmaz, okul seçilmemiş (null) sayılır.
//  - veri okuma: depolama açılamazsa önbellek yok sayılır; veri ağdan, o da olmazsa uygulamayla gelen kopyadan gelir.
//  - veri okuma: indirilen verinin önbelleğe yazılması başarısız olursa veri yine döner ve bu bir ağ hatası sayılmaz
//    (cevrimdisi false kalır; eskiden indirilen veri atılıp "Çevrimdışı" etiketi çıkıyordu).
//
// SharedPreferences'ın gerçek (yöntem kanallı) deposu sahte kanalla değiştirilir (desen: universite_sec_prefs_test.dart);
// bu yüzden bu dosyada SharedPreferences.setMockInitialValues kullanılmaz.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/config.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';

const _kanal = MethodChannel('plugins.flutter.io/shared_preferences');

/// Kanala gelen çağrılar: 'getAll' ([baslangic] verisini döndürür) ve yazmalar (set*).
class _SahteDepolama {
  /// getAll'ın döndüreceği veri ('flutter.' önekli anahtarlar).
  final Map<String, Object> baslangic;

  /// true ise okuma ('getAll'), yani SharedPreferences.getInstance(), hata verir.
  bool okumaHatasi = false;

  /// true ise her yazma (set*) PlatformException fırlatır.
  bool yazmaHatasi = false;

  /// Yapılan yazma denemesi sayısı (başarısız olanlar dahil).
  int yazmaDenemesi = 0;

  /// Başarılı yazmalar: anahtar -> değer.
  final Map<String, Object?> yazilan = {};

  _SahteDepolama([this.baslangic = const {}]);

  Future<Object?> isle(MethodCall c) async {
    if (c.method == 'getAll') {
      if (okumaHatasi) throw PlatformException(code: 'okuma');
      return <String, Object>{...baslangic};
    }
    yazmaDenemesi++;
    if (yazmaHatasi) throw PlatformException(code: 'yazma');
    final a = c.arguments as Map<Object?, Object?>;
    yazilan[a['key'] as String] = a['value'];
    return true;
  }
}

_SahteDepolama _depolamayiTaklitEt([Map<String, Object> baslangic = const {}]) {
  SharedPreferences
      .resetStatic(); // önceki testin önbelleğe aldığı örnek kalmasın
  final depolama = _SahteDepolama(baslangic);
  final iletisim =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  iletisim.setMockMethodCallHandler(_kanal, depolama.isle);
  addTearDown(() {
    iletisim.setMockMethodCallHandler(_kanal, null);
    SharedPreferences.resetStatic();
  });
  return depolama;
}

const _agdanGelen = 'Ağdan Gelen Çorba';

String _menuJson(String id) => jsonEncode({
      'university': id,
      'updated': '2026-10-31T08:00:00+03:00',
      'days': {
        '2026-11-02': {
          'lunch': {
            'items': [
              {'name': _agdanGelen, 'kcal': 120}
            ],
            'kcal': 120
          }
        }
      }
    });

http.Response _json(String govde) => http.Response(govde, 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _okul(String id) => {
      'id': id,
      'name': 'Okul $id',
      'short': id,
      'city': 'Ankara',
      'source': '',
      'meals': ['lunch'],
      'prices': [],
      'hours': {},
    };

/// Öğle menüsündeki yemek adları.
List<String> _ogleYemekleri(Menu m) =>
    [for (final o in m.gunler['2026-11-02']!['lunch']!.ogeler) o.ad];

void main() {
  TestWidgetsFlutterBinding
      .ensureInitialized(); // rootBundle (paket verisi) ve sahte kanal için

  group('seciliUniversite', () {
    test('kayıtlı okulu döndürür (koruyucu)', () async {
      _depolamayiTaklitEt({'flutter.universite': 'gazi'});
      expect(await Depo().seciliUniversite(), 'gazi');
    });

    test('depolama okunamazsa fırlatmaz, null döner (okul seçilmemiş sayılır)',
        () async {
      _depolamayiTaklitEt().okumaHatasi = true;
      await expectLater(Depo().seciliUniversite(), completion(isNull));
    });
  });

  group('veri okuma', () {
    test('normal durumda indirilen veri önbelleğe yazılır (koruyucu)',
        () async {
      final depolama = _depolamayiTaklitEt();
      final depo =
          Depo(istemci: MockClient((r) async => _json(_menuJson('ankara'))));
      final menu = await depo.menu('ankara');
      expect(_ogleYemekleri(menu), [_agdanGelen]);
      expect(depo.cevrimdisi, isFalse);
      expect(
          depolama.yazilan.keys, contains('flutter.onbellek/ankara/menu.json'));
    });

    test(
        'önbelleğe yazma başarısız olsa da indirilen veri döner ve çevrimdışı sayılmaz',
        () async {
      final depolama = _depolamayiTaklitEt()..yazmaHatasi = true;
      final depo =
          Depo(istemci: MockClient((r) async => _json(_menuJson('ankara'))));
      depo.cevrimdisi =
          true; // önceki okuma başarısızdı; bu okuma bayrağı düzeltmeli
      final menu = await depo.menu('ankara');
      expect(depolama.yazmaDenemesi, greaterThan(0),
          reason: 'yazma gerçekten denendi ve reddedildi');
      expect(_ogleYemekleri(menu), [_agdanGelen],
          reason: 'indirilen veri atılıp paket verisine düşülmemeli');
      expect(depo.cevrimdisi, isFalse,
          reason: 'depolama hatası ağ hatası değildir');
    });

    test(
        'okul listesi de önbelleğe yazılamasa bile indirilen liste kullanılır, çevrimdışı sayılmaz',
        () async {
      final depolama = _depolamayiTaklitEt()..yazmaHatasi = true;
      final liste = {
        'universities': [_okul('uzaktaki_okul')]
      };
      final depo =
          Depo(istemci: MockClient((r) async => _json(jsonEncode(liste))));
      final uniler = await depo.universiteler();
      expect(depolama.yazmaDenemesi, greaterThan(0));
      expect(uniler.map((u) => u.id), contains('uzaktaki_okul'));
      expect(uniler.map((u) => u.id), contains('ankara'),
          reason: 'paketteki okullar yine eklenir');
      expect(depo.cevrimdisi, isFalse);
    });

    test(
        'depolama açılamazsa fırlatmaz: ağdan gelen veri kullanılır, çevrimdışı sayılmaz',
        () async {
      _depolamayiTaklitEt().okumaHatasi = true;
      final depo =
          Depo(istemci: MockClient((r) async => _json(_menuJson('ankara'))));
      final menu = await depo.menu('ankara');
      expect(_ogleYemekleri(menu), [_agdanGelen]);
      expect(depo.cevrimdisi, isFalse);
    });

    test(
        'depolama açılamaz ve ağ da yoksa uygulamayla gelen kopya kullanılır, çevrimdışı sayılır',
        () async {
      _depolamayiTaklitEt().okumaHatasi = true;
      final depo =
          Depo(istemci: MockClient((r) async => http.Response('x', 500)));
      final menu = await depo.menu('ankara'); // assets/data/ankara/menu.json
      expect(menu.tarihler, isNotEmpty);
      expect(depo.cevrimdisi, isTrue);
      final uniler = await depo.universiteler();
      expect(uniler.map((u) => u.id), contains('ankara'));
    });

    test(
        'depolama açılamazsa okul listesi de uygulamayla gelen listeden okunur',
        () async {
      _depolamayiTaklitEt().okumaHatasi = true;
      final depo = Depo(
          istemci:
              MockClient((r) async => throw http.ClientException('ağ yok')));
      final uniler = await depo.universiteler();
      expect(uniler.length, greaterThan(10));
    });
  }, skip: veriTabanUrl.isEmpty ? 'VERI_URL boş: Depo ağa gitmez' : false);
}
