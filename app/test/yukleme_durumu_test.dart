// Ana sayfa yükleme durumu: araya giren yüklemelerde eski yanıtın yazmaması (yukle_yarisi_test.dart'a
// ek durumlar) ve yenilemenin kullanıcının seçtiği öğün sekmesine dokunmaması (ogun_sekmesi_yenileme_test.dart'a
// ek yollar).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

/// Okul başına kapı (Completer) olan sahte depo: kapı açılana kadar o okulun menüsü gelmez,
/// completeError ile hata da verilebilir. [secili] boşsa kayıtlı okul yoktur (ilk açılış).
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

Universite _uni(String id, String ad,
        {List<String> ogunler = const ['lunch']}) =>
    Universite(
        id: id,
        ad: ad,
        kisa: id,
        sehir: 'X',
        kaynak: '',
        ogunler: ogunler,
        fiyatlar: const []);

/// 2 Kasım 2026'da yalnızca verilen öğünler dolu (her biri tek yemekli) menü.
Menu _menu(String id, Map<String, String> ogunler) => Menu(id, null, {
      '2026-11-02': {
        for (final e in ogunler.entries)
          e.key: Ogun([YemekOgesi(e.value, 100)], 100)
      }
    });

const _oneri = 'Okul bu gün için ayrı bir vejetaryen menü yayınlamadı.';

/// a, b, c okulları (hepsinde yalnızca öğle menüsü); kayıtlı okul a.
_Depo _uclu() => _Depo([
      _uni('a', 'Ankara Üniversitesi'),
      _uni('b', 'Bursa Üniversitesi'),
      _uni('c', 'Çukurova Üniversitesi'),
    ], {
      'a': _menu('a', {'lunch': 'Yemek A'}),
      'b': _menu('b', {'lunch': 'Yemek B'}),
      'c': _menu('c', {'lunch': 'Yemek C'}),
    }, secili: 'a');

/// Öğle ve vejetaryen sekmeli iki okul; ikisinde de vejetaryen menü o gün yayınlanmamış.
_Depo _vejetaryenli() => _Depo([
      _uni('a', 'Ankara Üniversitesi', ogunler: const ['lunch', 'vegetarian']),
      _uni('b', 'Bursa Üniversitesi', ogunler: const ['lunch', 'vegetarian']),
    ], {
      'a': _menu('a', {'lunch': 'Yemek A'}),
      'b': _menu('b', {'lunch': 'Yemek B'}),
    }, secili: 'a');

DateTime _an(int saat, int dk) => DateTime.utc(2026, 11, 2, saat, dk);

Future<void> _ac(WidgetTester t, _Depo depo,
    {DateTime Function()? simdi}) async {
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
          simdi: simdi ?? () => _an(10, 0))));
  await t.pumpAndSettle();
}

/// Üst çubuktaki okul adına dokunur, listeden [ad] okulunu seçer; kapanan okul seçici rotası ağaçtan
/// kalkana kadar bekler (yükleme sürüyorsa iskelet nabız attığından pumpAndSettle kullanılmaz).
Future<void> _okulSec(WidgetTester t, String mevcutAd, String ad) async {
  await t.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text(mevcutAd)));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(find.text(ad));
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

Set<String> _seciliOgun(WidgetTester t) => t
    .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
    .selected;

Future<void> _vejetaryenAc(WidgetTester t) async {
  await t.tap(find.descendant(
      of: find.byType(SegmentedButton<String>),
      matching: find.text('Vejetaryen')));
  await t.pumpAndSettle();
  expect(find.text(_oneri), findsOneWidget);
  expect(_seciliOgun(t), {'vegetarian'});
}

/// Uygulamayı arka plana atıp öne getirir (resumed).
void _arkaPlanaGidipDon(WidgetTester t) {
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
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('araya giren yüklemeler', () {
    testWidgets(
        'eski okulun yanıtı, yeni okul hâlâ yüklenirken gelirse iskelet kalkmaz ve ekran değişmez',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      depo.kapi['b'] = Completer<void>();
      depo.kapi['c'] = Completer<void>();
      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      await _okulSec(t, 'Ankara Üniversitesi', 'Çukurova Üniversitesi');

      depo.kapi['b']!.complete(); // eski istek biter, yenisi (C) hâlâ yolda
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(IskeletGovde), findsOneWidget,
          reason: 'yeni yükleme sürerken eski yanıt iskeleti kaldırmamalı');
      expect(find.text('Yemek B'), findsNothing);
      expect(depo.secili, 'a', reason: 'eski yanıt seçimi kaydetmemeli');

      depo.kapi['c']!.complete();
      await t.pumpAndSettle();
      expect(find.byType(IskeletGovde), findsNothing);
      expect(find.text('Yemek C'), findsOneWidget);
      expect(depo.secili, 'c');
    });

    testWidgets(
        'aşağı çekip yenileme sürerken yeni okul yüklenmeye başlarsa, biten yenileme iskeleti kaldırmaz',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      depo.kapi['a'] = Completer<void>(); // A'nın yenilemesi takılı
      await t.fling(find.text('Yemek A'), const Offset(0, 400), 1000);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(seconds: 1));
      expect(depo.istek('a'), 2);

      depo.kapi['b'] = Completer<void>();
      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      expect(find.byType(IskeletGovde), findsOneWidget);

      depo.kapi['a']!.complete(); // eski sessiz yenileme biter, B hâlâ yolda
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(IskeletGovde), findsOneWidget,
          reason: 'sessiz yenileme yükleniyor durumunu kapatmamalı');
      expect(find.text('Yemek A'), findsNothing);
      expect(depo.secili, 'a');

      depo.kapi['b']!.complete();
      await t.pumpAndSettle();
      expect(find.text('Yemek B'), findsOneWidget);
      expect(depo.secili, 'b');
    });

    testWidgets('eski sessiz yenileme bitince sonraki aşağı çekme yine çalışır',
        (t) async {
      final depo = _uclu();
      await _ac(t, depo);
      depo.kapi['a'] = Completer<void>();
      await t.fling(find.text('Yemek A'), const Offset(0, 400), 1000);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(seconds: 1));

      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      // A'nın yenilemesi hâlâ takılı olduğundan pumpAndSettle kullanılmaz (yenileme göstergesi döner)
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Yemek B'), findsOneWidget);
      depo.kapi['a']!.complete(); // eski yenileme (atılan yanıt) şimdi biter
      await t.pumpAndSettle();
      expect(find.text('Yemek B'), findsOneWidget);

      final once = depo.istek('b');
      await t.fling(find.text('Yemek B'), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(depo.istek('b'), once + 1,
          reason: 'atılan yanıt "yenileme sürüyor" bayrağını açık bırakmamalı');
      expect(find.text('Yemek B'), findsOneWidget);
    });

    testWidgets(
        'karşılamadan seçilen ilk okulun hatası, ikinci seçim yüklenirken gelirse hata ekranı çıkmaz',
        (t) async {
      final depo = _uclu()..secili = null; // kayıtlı okul yok
      await _ac(t, depo);
      expect(find.text('Okulunu seç'), findsOneWidget);
      depo.kapi['b'] =
          Completer<void>(); // B'nin yanıtı sonradan hata olarak gelecek
      depo.kapi['c'] = Completer<void>();
      // karşılamadaki düğme okul seçiciyi açar
      await t.tap(find.text('Okulunu seç'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Bursa Üniversitesi'));
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(IskeletGovde), findsOneWidget);
      await _okulSec(t, 'Üni Yemek', 'Çukurova Üniversitesi');

      depo.kapi['b']!
          .completeError(Exception('ağ yok')); // eski istek hata verir
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(IskeletGovde), findsOneWidget);
      expect(find.textContaining('Menü yüklenemedi'), findsNothing,
          reason: 'eski isteğin hatası yeni okulun yüklemesini bozmamalı');
      expect(find.text('Tekrar dene'), findsNothing);

      depo.kapi['c']!.complete();
      await t.pumpAndSettle();
      expect(find.text('Yemek C'), findsOneWidget);
      expect(depo.secili, 'c');
    });
  });

  group('öğün sekmesi', () {
    testWidgets('Diğer > Yenile boş Vejetaryen sekmesini değiştirmez',
        (t) async {
      final depo = _vejetaryenli();
      await _ac(t, depo);
      await _vejetaryenAc(t);

      final once = depo.istek('a');
      await t.tap(find.byTooltip('Diğer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Yenile'));
      await t.pumpAndSettle();
      expect(depo.istek('a'), once + 1, reason: 'Yenile gerçekten çalıştı');
      expect(find.text(_oneri), findsOneWidget);
      expect(_seciliOgun(t), {'vegetarian'});
    });

    testWidgets(
        'arka plandan dönünce 3 saatlik otomatik yenileme Vejetaryen sekmesini değiştirmez',
        (t) async {
      var saat = _an(10, 0);
      final depo = _vejetaryenli();
      await _ac(t, depo, simdi: () => saat);
      await _vejetaryenAc(t);

      final once = depo.istek('a');
      saat = _an(13, 30);
      _arkaPlanaGidipDon(t);
      await t.pumpAndSettle();
      expect(depo.istek('a'), once + 1, reason: 'otomatik yenileme çalıştı');
      expect(find.text(_oneri), findsOneWidget);
      expect(_seciliOgun(t), {'vegetarian'});
    });

    testWidgets('okul değişince boş sekme yerine yeni okulun dolu öğünü açılır',
        (t) async {
      final depo = _vejetaryenli();
      await _ac(t, depo);
      await _vejetaryenAc(t);

      await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
      await t.pumpAndSettle();
      expect(find.text('Yemek B'), findsOneWidget);
      expect(_seciliOgun(t), {'lunch'});
      expect(find.text(_oneri), findsNothing);
    });

    testWidgets('açılışta akıllı öğün o gün boşsa dolu olan öğüne geçilir',
        (t) async {
      final depo = _Depo([
        _uni('a', 'Ankara Üniversitesi', ogunler: const ['lunch', 'dinner'])
      ], {
        'a':
            _menu('a', {'dinner': 'Fırın Makarna'}) // öğle menüsü yayınlanmamış
      }, secili: 'a');
      await _ac(t, depo, simdi: () => _an(10, 0)); // 10:00: akıllı öğün öğle
      expect(find.text('Fırın Makarna'), findsOneWidget);
      expect(_seciliOgun(t), {'dinner'});
    });
  });
}
