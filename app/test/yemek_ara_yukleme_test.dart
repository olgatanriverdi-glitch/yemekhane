// P5 madde 1: bir okul (B) yüklenirken (iskelet) üst çubuktaki "Yemek ara" ile açılan aramadan, ekrandaki okula (A) ait
// bir sonuç seçilirse A'ya dönülür ve B'nin geç yanıtı ekranı değiştirmez. Eskiden "aynı okul" karşılaştırması ekrandaki
// okula (A) göre yapıldığından yalnızca gün / öğün değişiyor, B gelince ekran B'ye dönüyordu. Karşılaştırma artık
// hedef okula (yüklenen, yoksa ekrandaki) göre yapılır.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/university_picker.dart';
import 'package:yemekhane/screens/yemek_ara.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

/// Ağa ve diske gitmeyen sahte depo. [ilkIstekKapisi]: okulun İLK menü isteğini (ana sayfanın yüklemesi) bekleten
/// kapı; sonraki istekler (arama sayfasınınki) beklemez. Her menü isteği [istekler]e yazılır.
class _Depo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  final Map<String, Completer<void>> ilkIstekKapisi = {};
  final List<String> istekler = [];
  String? secili;
  _Depo(this.liste, this.menuVeri, {this.secili});

  int istek(String id) => istekler.where((x) => x == id).length;

  @override
  Future<List<Universite>> universiteler() async => liste;

  @override
  Future<Menu> menu(String universiteId) async {
    istekler.add(universiteId);
    final kapi = ilkIstekKapisi[universiteId];
    if (kapi != null && istek(universiteId) == 1) await kapi.future;
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

Universite _uni(String id, String ad, List<String> ogunler) => Universite(
    id: id,
    ad: ad,
    kisa: id.toUpperCase(),
    sehir: 'Ankara',
    kaynak: '',
    ogunler: ogunler,
    fiyatlar: const []);

/// A (ankara): yalnızca öğle; bugün Mercimek, yarın Ezogelin. B (bursa): öğle ve akşam; yarın akşam İskender.
_Depo _depo() => _Depo([
      _uni('ankara', 'Ankara Üniversitesi', ['lunch']),
      _uni('bursa', 'Bursa Üniversitesi', ['lunch', 'dinner']),
    ], {
      'ankara': Menu('ankara', null, {
        '2026-11-02': {
          'lunch': Ogun([YemekOgesi('Mercimek Çorbası', 100)], 100)
        },
        '2026-11-03': {
          'lunch': Ogun([YemekOgesi('Ezogelin Çorbası', 100)], 100)
        },
      }),
      'bursa': Menu('bursa', null, {
        '2026-11-02': {
          'lunch': Ogun([YemekOgesi('Bursa Kebabı', 100)], 100)
        },
        '2026-11-03': {
          'dinner': Ogun([YemekOgesi('Bursa İskender', 100)], 100)
        },
      }),
    }, secili: 'ankara');

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

/// Üst çubuktaki okul adına dokunur, açılan seçicide [ad] okulunu seçer; B'nin yüklenmesi (iskelet) başlar.
Future<void> _okulSec(WidgetTester t, String mevcutAd, String ad) async {
  await t.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text(mevcutAd)));
  await _bekle(t, 2);
  await t.tap(find.descendant(
      of: find.byType(UniversitePicker), matching: find.text(ad)));
  await _bekle(t);
}

/// "Yemek ara"yı açar, [sorgu]yu yazar ve [sonuc] satırına dokunur (sayfa o sonuçla kapanır).
Future<void> _arayipSec(WidgetTester t, String sorgu, String sonuc) async {
  await t.tap(find.byTooltip('Yemek ara'));
  await _bekle(
      t, 3); // sayfa geçişi bitsin (altta kalan ana sayfa sahne dışına çıkar)
  expect(find.byType(YemekAraSayfasi), findsOneWidget);
  await t.enterText(
      find.descendant(
          of: find.byType(YemekAraSayfasi), matching: find.byType(TextField)),
      sorgu);
  await t.pump(const Duration(milliseconds: 300)); // 250 ms bekleme sonrası
  await _bekle(t, 2);
  await t.tap(find.descendant(
      of: find.byType(YemekAraSayfasi), matching: find.text(sonuc)));
  await _bekle(t);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'B yüklenirken aramadan ekrandaki A\'nın sonucu seçilirse A\'ya dönülür, B\'nin geç yanıtı ekranı değiştirmez',
      (t) async {
    final depo = _depo();
    await _ac(t, depo);
    expect(find.text('Mercimek Çorbası'), findsOneWidget);
    depo.ilkIstekKapisi['bursa'] = Completer<void>();

    await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
    expect(find.byType(IskeletGovde), findsOneWidget,
        reason: 'B yükleniyor (kapı kapalı)');

    await _arayipSec(t, 'ezogelin', 'Ezogelin Çorbası');
    expect(find.byType(YemekAraSayfasi), findsNothing);
    expect(find.byType(IskeletGovde), findsNothing,
        reason: 'A\'ya dönüldü: B\'nin yanıtı beklenmez');
    expect(find.text('Ezogelin Çorbası'), findsOneWidget,
        reason: 'seçilen A sonucunun günü (yarın) açılmalı');
    expect(find.text('Yarın'), findsOneWidget);
    expect(depo.istek('ankara'), 2, reason: 'açılış + A\'ya dönüş');
    expect(depo.secili, 'ankara');

    depo.ilkIstekKapisi['bursa']!.complete(); // vazgeçilen B şimdi biter
    await t.pumpAndSettle();
    expect(find.text('Ezogelin Çorbası'), findsOneWidget,
        reason: 'vazgeçilen B ekrana yazmamalı');
    expect(find.text('Bursa Kebabı'), findsNothing);
    expect(
        find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Ankara Üniversitesi')),
        findsOneWidget);
    expect(depo.secili, 'ankara', reason: 'kayıtlı okul A kalmalı');
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'yükleme yokken ekrandaki okulun sonucu yeniden yükleme açmadan o güne geçer',
      (t) async {
    final depo = _depo();
    await _ac(t, depo);

    await _arayipSec(t, 'ezogelin', 'Ezogelin Çorbası');
    await t.pumpAndSettle();
    expect(find.byType(YemekAraSayfasi), findsNothing);
    expect(find.text('Yarın'), findsOneWidget);
    expect(find.text('Ezogelin Çorbası'), findsOneWidget);
    expect(depo.istek('ankara'), 1, reason: 'aynı okul: yeniden yükleme yok');
  });

  testWidgets(
      'B yüklenirken aramadan B\'nin sonucu seçilirse B gelince o gün ve öğün açılır',
      (t) async {
    final depo = _depo();
    await _ac(t, depo);
    depo.ilkIstekKapisi['bursa'] = Completer<void>();

    await _okulSec(t, 'Ankara Üniversitesi', 'Bursa Üniversitesi');
    expect(find.byType(IskeletGovde), findsOneWidget);

    // arama sayfası kendi isteğiyle B'nin menüsünü alır (ana sayfanın isteği hâlâ bekliyor)
    await _arayipSec(t, 'iskender', 'Bursa İskender');
    expect(find.byType(YemekAraSayfasi), findsNothing);

    depo.ilkIstekKapisi['bursa']!
        .complete(); // ana sayfanın ilk B isteği de biter
    await t.pumpAndSettle();
    expect(find.byType(IskeletGovde), findsNothing);
    expect(find.text('Bursa İskender'), findsOneWidget,
        reason: 'B\'nin yarın akşam menüsü açılmalı');
    expect(find.text('Yarın'), findsOneWidget);
    final dugme =
        t.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(dugme.selected, {'dinner'});
    expect(depo.secili, 'bursa');
    expect(t.takeException(), isNull);
  });
}
