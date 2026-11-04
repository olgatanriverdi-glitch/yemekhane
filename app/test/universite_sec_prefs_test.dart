// P4 eki: Depo.universiteSec cihaza yazarken hata alırsa (SharedPreferences hataları yutulur) hiçbir şey fırlatmaz;
// menü zaten yüklenmiş ve gösteriliyor olabilir, "Menü yüklenemedi" denmemeli.
//
// SharedPreferences'ın gerçek (yöntem kanallı) deposu sahte kanalla değiştirilir; bu yüzden bu dosyada
// SharedPreferences.setMockInitialValues kullanılmaz (o, kanalı bellek içi depoyla değiştirirdi).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';

const _kanal = MethodChannel('plugins.flutter.io/shared_preferences');

/// Kanala gelen yazma çağrıları: yöntem adı -> [anahtar, değer].
class _SahteDepolama {
  /// true ise okuma ('getAll') hata verir.
  bool okumaHatasi = false;

  /// true ise her yazma (set*) PlatformException fırlatır.
  bool yazmaHatasi = false;
  final List<(String, Object?)> yazilanlar = [];

  Future<Object?> isle(MethodCall c) async {
    if (c.method == 'getAll') {
      if (okumaHatasi) throw PlatformException(code: 'okuma');
      return <String, Object>{};
    }
    if (yazmaHatasi) throw PlatformException(code: 'yazma');
    final a = c.arguments as Map<Object?, Object?>;
    yazilanlar.add((a['key'] as String, a['value']));
    return true;
  }
}

_SahteDepolama _depolamayiTaklitEt() {
  SharedPreferences
      .resetStatic(); // önceki testin önbelleğe aldığı örnek kalmasın
  final depolama = _SahteDepolama();
  final iletisim =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  iletisim.setMockMethodCallHandler(_kanal, depolama.isle);
  addTearDown(() {
    iletisim.setMockMethodCallHandler(_kanal, null);
    SharedPreferences.resetStatic();
  });
  return depolama;
}

/// Yalnızca veri okuyan metotları sahteleyen depo; universiteSec GERÇEK (yazma hatasını sınamak için).
class _Depo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  _Depo(this.liste, this.menuVeri);

  @override
  Future<List<Universite>> universiteler() async => liste;

  @override
  Future<Menu> menu(String universiteId) async => menuVeri[universiteId]!;

  @override
  Future<String?> seciliUniversite() async => 'a';

  @override
  String? fotoUrl(String universiteId, String? foto) => null;

  @override
  String? yemekFotoUrl(String? img) => null;
}

Universite _uni(String id, String ad) => Universite(
    id: id,
    ad: ad,
    kisa: id,
    sehir: 'X',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

Menu _menu(String id, String yemek) => Menu(id, null, {
      '2026-11-02': {
        'lunch': Ogun([YemekOgesi(yemek, 100)], 100)
      }
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Depo.universiteSec', () {
    test('normal durumda seçili okulu ve son seçilenleri yazar', () async {
      final depolama = _depolamayiTaklitEt();
      await Depo().universiteSec('gazi');
      final yazilan = {for (final (k, v) in depolama.yazilanlar) k: v};
      expect(yazilan['flutter.universite'], 'gazi');
      expect(yazilan['flutter.son_secilenler'], ['gazi']);
    });

    test('yazma hatası fırlatılmaz (menü yüklenmişken hata gösterilmesin)',
        () async {
      final depolama = _depolamayiTaklitEt()..yazmaHatasi = true;
      await expectLater(Depo().universiteSec('gazi'), completes);
      expect(depolama.yazilanlar, isEmpty);
    });

    test('depolama hiç açılamazsa da hata fırlatılmaz', () async {
      _depolamayiTaklitEt().okumaHatasi = true;
      await expectLater(Depo().universiteSec('gazi'), completes);
    });
  });

  group('ana sayfa', () {
    testWidgets(
        'okul seçimi cihaza yazılamasa da yeni okulun menüsü görünür, "Menü yüklenemedi" çıkmaz',
        (t) async {
      final depolama = _depolamayiTaklitEt()..yazmaHatasi = true;
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final depo = _Depo([
        _uni('a', 'Ankara Üniversitesi'),
        _uni('b', 'Bursa Üniversitesi'),
      ], {
        'a': _menu('a', 'Yemek A'),
        'b': _menu('b', 'Yemek B'),
      });
      final ayar = TemaAyari();
      await t.pumpWidget(MaterialApp(
          theme: ayar.tema(Brightness.light),
          home: AnaSayfa(
              temaAyari: ayar,
              depo: depo,
              geriBildirim: YerelDepo(),
              simdi: () => DateTime.utc(2026, 11, 2, 10, 0))));
      await t.pumpAndSettle();
      expect(find.text('Yemek A'), findsOneWidget);

      await t.tap(find.descendant(
          of: find.byType(AppBar), matching: find.text('Ankara Üniversitesi')));
      await t.pumpAndSettle();
      await t.tap(find.text('Bursa Üniversitesi'));
      await t.pumpAndSettle();
      expect(find.text('Yemek B'), findsOneWidget,
          reason: 'menü yüklendi ve gösterilmeli');
      expect(find.textContaining('Menü yüklenemedi'), findsNothing,
          reason: 'prefs hatası menü hatası sayılmamalı');
      expect(find.byType(SnackBar), findsNothing);
      expect(depolama.yazilanlar, isEmpty,
          reason: 'yazma gerçekten reddedildi');
      expect(t.takeException(), isNull);
    });
  });
}
