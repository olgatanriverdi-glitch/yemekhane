// Bulgu 2: _yukle yarışı. Eski (yavaş) bir okul isteği, kullanıcının sonradan seçtiği okulun üstüne yazmamalı.
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

/// Okul başına kapı (Completer) olan sahte depo: kapı açılana kadar o okulun menüsü gelmez.
class _KapiliDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  final Map<String, Completer<void>> kapi = {};
  String? secili;
  _KapiliDepo(this.liste, this.menuVeri);

  @override
  Future<List<Universite>> universiteler() async => liste;

  @override
  Future<Menu> menu(String universiteId) async {
    final k = kapi[universiteId];
    if (k != null) await k.future; // completeError ile hata da verilebilir
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

_KapiliDepo _depo() => _KapiliDepo([
      _uni('a', 'Ankara Üniversitesi'),
      _uni('b', 'Bursa Üniversitesi'),
      _uni('c', 'Çukurova Üniversitesi'),
    ], {
      'a': _menu('a', 'Yemek A'),
      'b': _menu('b', 'Yemek B'),
      'c': _menu('c', 'Yemek C'),
    })
      ..secili = 'a';

Future<void> _ac(WidgetTester t, _KapiliDepo depo) async {
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

/// Üst çubuktaki okul adına dokunur, listeden [ad] okulunu seçer ve geçişin bitmesini bekler
/// (yükleme sürüyorsa iskelet nabız attığından pumpAndSettle kullanılmaz).
Future<void> _okulSec(WidgetTester t, String mevcutAd, String ad) async {
  await t.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text(mevcutAd)));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(find.text(ad));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
  // Kapanış animasyonu ikinci karede biter ama okul seçici rotası ağaçtan ancak bir sonraki karede
  // kalkar; bu kare olmadan ikinci _okulSec çağrısının ilk dokunuşu kapanan rotaya çarpar.
  await t.pump(const Duration(milliseconds: 16));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'B seçilip yanıt gelmeden C seçilirse, geç gelen B yanıtı C\'nin üstüne yazmaz',
      (t) async {
    final depo = _depo();
    await _ac(t, depo);
    expect(find.text('Yemek A'), findsOneWidget);
    depo.kapi['b'] = Completer<void>();
    depo.kapi['c'] = Completer<void>();

    await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
    expect(find.byType(IskeletGovde), findsOneWidget);
    await _okulSec(t, 'Ankara Üniversitesi', 'Çukurova Üniversitesi');

    depo.kapi['c']!.complete();
    await t.pumpAndSettle();
    expect(find.text('Yemek C'), findsOneWidget);

    depo.kapi['b']!.complete(); // eski istek en son biter
    await t.pumpAndSettle();
    expect(find.text('Yemek C'), findsOneWidget,
        reason: 'son seçilen okul ekranda kalmalı');
    expect(find.text('Yemek B'), findsNothing);
    expect(depo.secili, 'c', reason: 'kayıtlı okul da son seçim olmalı');
  });

  testWidgets(
      'geç gelen eski istek hata verirse yeni okulun ekranında hata bildirimi çıkmaz',
      (t) async {
    final depo = _depo();
    await _ac(t, depo);
    depo.kapi['b'] = Completer<void>();
    depo.kapi['c'] = Completer<void>();

    await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
    await _okulSec(t, 'Ankara Üniversitesi', 'Çukurova Üniversitesi');
    depo.kapi['c']!.complete();
    await t.pumpAndSettle();

    depo.kapi['b']!.completeError(Exception('ağ yok'));
    await t.pumpAndSettle();
    expect(find.text('Yemek C'), findsOneWidget);
    expect(find.textContaining('Menü yüklenemedi'), findsNothing,
        reason: 'eski isteğin hatası yeni okulda gösterilmemeli');
  });

  testWidgets(
      'aşağı çekip yenileme sürerken okul değişirse, eski sessiz istek seçimi geri almaz',
      (t) async {
    final depo = _depo();
    await _ac(t, depo);
    depo.kapi['a'] = Completer<void>(); // A'nın yenilemesi takılı

    await t.fling(find.text('Yemek A'), const Offset(0, 400), 1000);
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(seconds: 1));

    await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Yemek B'), findsOneWidget);

    depo.kapi['a']!.complete(); // eski sessiz yenileme şimdi biter
    await t.pumpAndSettle();
    expect(find.text('Yemek B'), findsOneWidget,
        reason: 'kullanıcının seçtiği okul kalmalı');
    expect(find.text('Yemek A'), findsNothing);
    expect(depo.secili, 'b');
  });
}
