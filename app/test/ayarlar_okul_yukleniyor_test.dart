// P5 madde 5: bir okul (B) yüklenirken (iskelet) Ayarlar açılırsa "Okul" satırı (ve veri kaynağı, seçicideki işaret)
// ekrandaki eski okulu (A) değil, yüklenen okulu (B) gösterir. Yükleme yokken ya da yüklenen okul listede
// bulunamıyorsa gösterilen okul görünür (mevcut davranış).
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

/// Okul başına kapı (Completer) olan sahte depo: kapı açılana kadar o okulun menüsü gelmez.
class _Depo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  final Map<String, Completer<void>> kapi = {};
  String? secili;
  _Depo(this.liste, this.menuVeri, {this.secili});

  @override
  Future<List<Universite>> universiteler() async => liste;

  @override
  Future<Menu> menu(String universiteId) async {
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
    sehir: 'Ankara',
    kaynak: 'https://$id.example/menu',
    ogunler: const ['lunch'],
    fiyatlar: const []);

Menu _menu(String id, String yemek) => Menu(id, null, {
      '2026-11-02': {
        'lunch': Ogun([YemekOgesi(yemek, 100)], 100)
      }
    });

final _ankara = _uni('ankara', 'Ankara Üniversitesi');
final _bursa = _uni('bursa', 'Bursa Üniversitesi');

Future<void> _ayarlariAc(WidgetTester t,
    {String? yuklenenId, List<Universite>? uniler}) async {
  final ayar = TemaAyari();
  await t.pumpWidget(MaterialApp(
      theme: ayar.tema(Brightness.light),
      home: AyarlarSayfasi(
          temaAyari: ayar,
          depo: _Depo(const [], const {}),
          uniler: uniler ?? [_ankara, _bursa],
          uni: _ankara,
          yuklenenId: yuklenenId,
          menuyuYenile: () async {})));
  await t.pumpAndSettle();
}

/// Okul satırının altındaki ad.
Finder _okulAdi(String ad) => find.descendant(
    of: find.widgetWithText(ListTile, 'Okul'), matching: find.text(ad));

Finder _kaynak(String adres) => find.descendant(
    of: find.widgetWithText(ListTile, 'Veri kaynağı'),
    matching: find.text(adres));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AyarlarSayfasi', () {
    testWidgets(
        'yükleme yokken Okul satırı ve veri kaynağı gösterilen okulu verir',
        (t) async {
      await _ayarlariAc(t);
      expect(_okulAdi('Ankara Üniversitesi'), findsOneWidget);
      expect(_kaynak('https://ankara.example/menu'), findsOneWidget);
    });

    testWidgets(
        'B yüklenirken Okul satırı ve veri kaynağı yüklenen okulu (B) gösterir',
        (t) async {
      await _ayarlariAc(t, yuklenenId: 'bursa');
      expect(_okulAdi('Bursa Üniversitesi'), findsOneWidget);
      expect(find.text('Ankara Üniversitesi'), findsNothing,
          reason: 'eski okul hâlâ yazmamalı');
      expect(_kaynak('https://bursa.example/menu'), findsOneWidget);
    });

    testWidgets(
        'yüklenen okul listede yoksa (ya da liste boşsa) gösterilen okul görünür',
        (t) async {
      await _ayarlariAc(t, yuklenenId: 'yok_okul');
      expect(_okulAdi('Ankara Üniversitesi'), findsOneWidget);
      await _ayarlariAc(t, yuklenenId: 'bursa', uniler: const []);
      expect(_okulAdi('Ankara Üniversitesi'), findsOneWidget);
    });

    testWidgets('seçicide işaret yüklenen okulda olur, gösterilen okulda olmaz',
        (t) async {
      await _ayarlariAc(t, yuklenenId: 'bursa');
      await t.tap(find.text('Okul'));
      await t.pumpAndSettle();
      expect(find.byType(UniversitePicker), findsOneWidget);
      Finder isaret(String ad) => find.descendant(
          of: find.widgetWithText(ListTile, ad),
          matching: find.byIcon(Icons.check_circle));
      expect(isaret('Bursa Üniversitesi'), findsOneWidget);
      expect(isaret('Ankara Üniversitesi'), findsNothing);
    });
  });

  group('ana sayfa', () {
    testWidgets(
        'B yüklenirken Diğer > Ayarlar: Okul satırı B\'yi gösterir, B yüklenince menüsü görünür',
        (t) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final depo = _Depo([
        _ankara,
        _bursa
      ], {
        'ankara': _menu('ankara', 'Yemek A'),
        'bursa': _menu('bursa', 'Yemek B'),
      }, secili: 'ankara');
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
      depo.kapi['bursa'] = Completer<void>();

      await t.tap(find.descendant(
          of: find.byType(AppBar), matching: find.text('Ankara Üniversitesi')));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.descendant(
          of: find.byType(UniversitePicker),
          matching: find.text('Bursa Üniversitesi')));
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(IskeletGovde), findsOneWidget);

      await t.tap(find.byTooltip('Diğer'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Ayarlar'));
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(AyarlarSayfasi), findsOneWidget);
      expect(_okulAdi('Bursa Üniversitesi'), findsOneWidget,
          reason: 'kullanıcının son seçimi B: Ayarlar\'da A yazmamalı');
      expect(_okulAdi('Ankara Üniversitesi'), findsNothing);

      depo.kapi['bursa']!.complete();
      await t.pumpAndSettle();
      expect(depo.secili, 'bursa');
      await t.pageBack(); // Ayarlar kapanır; ana sayfada B'nin menüsü görünür
      await t.pumpAndSettle();
      expect(find.byType(AyarlarSayfasi), findsNothing);
      expect(find.text('Yemek B'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
