// P4 ek testleri: bir okul (B) yüklenirken (iskelet) seçiciden ya da Ayarlar'dan ekranda görünen okul (A) yeniden
// seçilirse B'den vazgeçilip A'ya dönülür; yüklenmekte olan B yeniden seçilirse ikinci bir istek açılmaz. Yükleme
// bitince (başarıyla ya da hatayla) "yüklenen okul" kalmaz: aynı okul yeniden seçilince yeniden denenir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/university_picker.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

/// Okul başına kapı (Completer) olan sahte depo: kapı açılana kadar o okulun menüsü gelmez, completeError ile hata
/// da verilebilir. [secili] boşsa kayıtlı okul yoktur (ilk açılış). Her menü isteği [istekler]e yazılır.
class _Depo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  final Map<String, Completer<void>> kapi = {};
  final List<String> istekler = [];
  String? secili;
  _Depo(this.liste, this.menuVeri, {this.secili});

  int istek(String id) => istekler.where((x) => x == id).length;

  @override
  Future<List<Universite>> universiteler() async => liste;

  @override
  Future<Menu> menu(String universiteId) async {
    istekler.add(universiteId);
    final k = kapi[universiteId];
    if (k != null) await k.future;
    return menuVeri[universiteId]!;
  }

  @override
  Future<String?> seciliUniversite() async => secili;

  @override
  Future<void> universiteSec(String id) async => secili = id;

  @override
  Future<List<String>> sonSecilenler() async => const [];

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

/// a, b, c okulları (hepsinde yalnızca öğle menüsü); kayıtlı okul a.
_Depo _uclu() => _Depo([
      _uni('a', 'Ankara Üniversitesi'),
      _uni('b', 'Bursa Üniversitesi'),
      _uni('c', 'Çukurova Üniversitesi'),
    ], {
      'a': _menu('a', 'Yemek A'),
      'b': _menu('b', 'Yemek B'),
      'c': _menu('c', 'Yemek C'),
    }, secili: 'a');

Future<void> _ac(WidgetTester t, _Depo depo) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari();
  await t.pumpWidget(MaterialApp(
      theme: ayar.tema(Brightness.light),
      home: AnaSayfa(
          temaAyari: ayar,
          depo: depo,
          geriBildirim: YerelDepo(),
          simdi: () => DateTime.utc(2026, 11, 2, 10, 0))));
  await t.pumpAndSettle();
}

/// Yükleme sürerken iskelet nabız attığından pumpAndSettle yerine sabit adımlarla ilerler.
Future<void> _bekle(WidgetTester t, [int adim = 3]) async {
  for (var i = 0; i < adim; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

/// Açık okul seçicide (UniversitePicker) [ad] okulunu seçer ve seçici kapanana kadar bekler.
Future<void> _seciciyeSec(WidgetTester t, String ad) async {
  await t.tap(find.descendant(
      of: find.byType(UniversitePicker), matching: find.text(ad)));
  await _bekle(t);
}

/// Üst çubuktaki okul adına dokunur, açılan seçicide [ad] okulunu seçer.
Future<void> _okulSec(WidgetTester t, String mevcutAd, String ad) async {
  await t.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text(mevcutAd)));
  await _bekle(t, 2);
  await _seciciyeSec(t, ad);
}

/// "Okulunu seç" (karşılama) ya da "Okul seç" (hata ekranı) düğmesiyle seçiciyi açar ve [ad] okulunu seçer.
Future<void> _dugmeyleSec(WidgetTester t, String dugme, String ad) async {
  await t.tap(find.text(dugme));
  await _bekle(t, 2);
  await _seciciyeSec(t, ad);
}

/// Diğer > Ayarlar > Okul satırı ile açılan seçicide [ad] okulunu seçer.
Future<void> _ayarlardanSec(WidgetTester t, String ad) async {
  await t.tap(find.byTooltip('Diğer'));
  await _bekle(t, 2);
  await t.tap(find.text('Ayarlar'));
  await _bekle(t);
  expect(find.byType(AyarlarSayfasi), findsOneWidget);
  await t.tap(find.text('Okul'));
  await _bekle(t);
  await _seciciyeSec(t, ad);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('okul seçici', () {
    testWidgets(
        'B yüklenirken ekrandaki A yeniden seçilirse B\'den vazgeçilir, A yüklenir ve B\'nin geç yanıtı yazmaz',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      expect(find.text('Yemek A'), findsOneWidget);
      depo.kapi['b'] = Completer<void>();

      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      expect(find.byType(IskeletGovde), findsOneWidget);

      await _okulSec(t, 'Ankara Üniversitesi', 'Ankara Üniversitesi');
      expect(find.byType(IskeletGovde), findsNothing,
          reason: 'A\'ya dönüldü: B\'nin yanıtı beklenmez');
      expect(find.text('Yemek A'), findsOneWidget);
      expect(depo.istek('a'), 2, reason: 'açılış + A\'ya dönüş');
      expect(depo.secili, 'a');

      depo.kapi['b']!.complete(); // vazgeçilen B şimdi biter
      await t.pumpAndSettle();
      expect(find.text('Yemek A'), findsOneWidget,
          reason: 'vazgeçilen B ekrana yazmamalı');
      expect(find.text('Yemek B'), findsNothing);
      expect(depo.secili, 'a', reason: 'kayıtlı okul A kalmalı');
    });

    testWidgets(
        'B yüklenirken B yeniden seçilirse ikinci istek açılmaz ve B yüklenir',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      depo.kapi['b'] = Completer<void>();

      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      expect(depo.istek('b'), 1);
      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      expect(depo.istek('b'), 1,
          reason: 'B zaten yükleniyor: yeni yükleme başlamamalı');
      expect(find.byType(IskeletGovde), findsOneWidget);

      depo.kapi['b']!.complete();
      await t.pumpAndSettle();
      expect(find.text('Yemek B'), findsOneWidget);
      expect(depo.secili, 'b');
    });

    testWidgets('B yüklenirken C seçilirse C yüklenir, B\'nin yanıtı yazmaz',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      depo.kapi['b'] = Completer<void>();
      depo.kapi['c'] = Completer<void>();

      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      await _okulSec(t, 'Ankara Üniversitesi', 'Çukurova Üniversitesi');
      expect(depo.istek('c'), 1);
      depo.kapi['b']!.complete();
      depo.kapi['c']!.complete();
      await t.pumpAndSettle();
      expect(find.text('Yemek C'), findsOneWidget);
      expect(find.text('Yemek B'), findsNothing);
      expect(depo.secili, 'c');
    });

    testWidgets(
        'B yüklenemeyince "yüklenen okul" kalmaz: B yeniden seçilince yeniden denenir',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      depo.kapi['b'] = Completer<void>();

      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      depo.kapi['b']!.completeError(Exception('ağ yok'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Menü yüklenemedi'), findsOneWidget);
      expect(find.text('Yemek A'), findsOneWidget,
          reason: 'önceki menü ekranda kalır');
      expect(depo.istek('b'), 1);

      depo.kapi.remove('b'); // bağlantı düzeldi
      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      await t.pumpAndSettle();
      expect(depo.istek('b'), 2, reason: 'başarısız B yeniden denenmeli');
      expect(find.text('Yemek B'), findsOneWidget);
      expect(depo.secili, 'b');
    });

    testWidgets('B yüklendikten sonra A seçilirse A yüklenir (olağan geçiş)',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      await t.pumpAndSettle();
      expect(find.text('Yemek B'), findsOneWidget);
      expect(depo.istek('a'), 1);

      await _okulSec(t, 'Bursa Üniversitesi', 'Ankara Üniversitesi');
      await t.pumpAndSettle();
      expect(find.text('Yemek A'), findsOneWidget);
      expect(depo.istek('a'), 2);
      expect(depo.secili, 'a');
    });

    testWidgets(
        'gösterilen okul yeniden seçilirse (yükleme yokken) yeni yükleme başlamaz',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      await _okulSec(t, 'Ankara Üniversitesi', 'Ankara Üniversitesi');
      await t.pumpAndSettle();
      expect(depo.istek('a'), 1);
      expect(find.text('Yemek A'), findsOneWidget);
    });

    testWidgets(
        'karşılamadan seçilen ilk okul yüklenemeyince aynı okul seçiciden yeniden seçilip denenebilir',
        (t) async {
      final depo = _uclu()..secili = null; // kayıtlı okul yok
      await _ac(t, depo);
      expect(find.text('Okulunu seç'), findsOneWidget);
      depo.kapi['b'] = Completer<void>();

      await _dugmeyleSec(t, 'Okulunu seç', 'Bursa Üniversitesi');
      expect(find.byType(IskeletGovde), findsOneWidget);
      depo.kapi['b']!.completeError(Exception('ağ yok'));
      await t.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(depo.istek('b'), 1);

      depo.kapi.remove('b');
      await _dugmeyleSec(t, 'Okul seç', 'Bursa Üniversitesi');
      await t.pumpAndSettle();
      expect(depo.istek('b'), 2);
      expect(find.text('Yemek B'), findsOneWidget);
      expect(depo.secili, 'b');
    });
  });

  group('Ayarlar', () {
    testWidgets(
        'B yüklenirken Ayarlar > Okul > A seçilirse Ayarlar kapanır, A yüklenir ve B\'nin geç yanıtı yazmaz',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      depo.kapi['b'] = Completer<void>();
      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      expect(find.byType(IskeletGovde), findsOneWidget);

      await _ayarlardanSec(t, 'Ankara Üniversitesi');
      expect(find.byType(AyarlarSayfasi), findsNothing,
          reason: 'seçim ana sayfaya iletilmeli');
      expect(find.byType(IskeletGovde), findsNothing);
      expect(find.text('Yemek A'), findsOneWidget);
      expect(depo.istek('a'), 2);

      depo.kapi['b']!.complete();
      await t.pumpAndSettle();
      expect(find.text('Yemek A'), findsOneWidget);
      expect(find.text('Yemek B'), findsNothing);
      expect(depo.secili, 'a');
    });

    testWidgets(
        'B yüklenirken Ayarlar > Okul > B seçilirse Ayarlar açık kalır, yeni istek açılmaz',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      depo.kapi['b'] = Completer<void>();
      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');

      await _ayarlardanSec(t, 'Bursa Üniversitesi');
      expect(find.byType(AyarlarSayfasi), findsOneWidget);
      expect(depo.istek('b'), 1);

      depo.kapi['b']!.complete();
      await t.pumpAndSettle();
      expect(depo.secili, 'b');
    });

    testWidgets(
        'yükleme yokken Ayarlar > Okul > aynı okul: Ayarlar açık kalır, yeni istek açılmaz',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      await _ayarlardanSec(t, 'Ankara Üniversitesi');
      expect(find.byType(AyarlarSayfasi), findsOneWidget);
      expect(depo.istek('a'), 1);
    });

    testWidgets(
        'yükleme yokken Ayarlar > Okul > başka okul: Ayarlar kapanır, o okul yüklenir',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      await _ayarlardanSec(t, 'Bursa Üniversitesi');
      await t.pumpAndSettle();
      expect(find.byType(AyarlarSayfasi), findsNothing);
      expect(find.text('Yemek B'), findsOneWidget);
      expect(depo.secili, 'b');
    });
  });
}
