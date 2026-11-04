// Bulgu 6 (yemek arama): Android 15+ (targetSdk 36) kenardan kenara çizimde gezinme çubuğu alt 48 dp'yi
// kaplarken arama sonuçları bu bölgeye girmemeli, ama çubuk yokken de fazladan boşluk kalmamalı.
// MediaQuery benzetimi; gerçek cihazda denenmedi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/yemek_ara.dart';
import 'package:yemekhane/tema.dart';

const _ekran = Size(400, 900);
const _cubuk = 48.0; // gezinme çubuğu yüksekliği (3 düğmeli gezinme)

/// Ağa ve diske gitmeyen sahte depo (desen: test/arama_test.dart).
class _Depo extends Depo {
  final Map<String, Menu> veri;
  _Depo(this.veri);
  @override
  Future<Menu> menu(String universiteId) async => veri[universiteId]!;
}

Universite _uni(String id, String ad, String kisa) => Universite(
    id: id,
    ad: ad,
    kisa: kisa,
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

/// Her gün öğlen "Tavuk Sote" olan 30 günlük menü: sonuç listesi ekrandan uzun olur.
Menu _menu(String id) => Menu(id, null, {
      for (var i = 0; i < 30; i++)
        isoTarih(DateTime.utc(2026, 11, 2 + i)): {
          'lunch': Ogun([YemekOgesi('Tavuk Sote', 100)], 100)
        }
    });

/// Sistem çubuğu alt kenarda [alt] dp yer kaplıyormuş gibi MediaQuery veren uygulama kabuğu.
Future<void> _ac(WidgetTester t, {required double alt}) async {
  t.view.physicalSize = _ekran;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ankara = _uni('ankara', 'Ankara Üniversitesi', 'AÜ');
  final gazi = _uni('gazi', 'Gazi Üniversitesi', 'GÜ');
  final depo = _Depo({'ankara': _menu('ankara'), 'gazi': _menu('gazi')});
  await t.pumpWidget(MaterialApp(
    theme: TemaAyari().tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
            padding: EdgeInsets.only(top: 24, bottom: alt),
            viewPadding: EdgeInsets.only(top: 24, bottom: alt)),
        child: w!),
    home: YemekAraSayfasi(
        depo: depo,
        uniler: [ankara, gazi],
        uni: ankara,
        menu: depo.veri['ankara'],
        bugun: '2026-11-02'),
  ));
  await t.pumpAndSettle();
}

/// Arama kutusuna [s] yazar ve 250 ms'lik bekleme sonrası sonuçların gelmesini bekler.
Future<void> _yaz(WidgetTester t, String s) async {
  await t.enterText(find.byType(TextField), s);
  await t.pump(const Duration(milliseconds: 300));
  await t.pumpAndSettle();
}

/// Sonuç listesini sonuna kadar kaydırır. Liste ilerledikçe uzunluğunu yeniden hesapladığından
/// sonuna kadar birkaç kez atlanır.
Future<void> _sonaKaydir(WidgetTester t) async {
  final konum = t
      .state<ScrollableState>(find.descendant(
          of: find.byType(CustomScrollView), matching: find.byType(Scrollable)))
      .position;
  for (var i = 0; i < 5; i++) {
    konum.jumpTo(konum.maxScrollExtent);
    await t.pumpAndSettle();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'yemek arama: sonuç listesi sonuna kaydırınca son satır gezinme çubuğuna girmez',
      (t) async {
    await _ac(t, alt: _cubuk);
    const guvenliAlt = 900.0 - _cubuk;
    // sonuç yokken de gövde çubuğun üstünde biter
    expect(t.getRect(find.byType(CustomScrollView)).bottom, guvenliAlt);

    await _yaz(t, 'tavuk');
    expect(find.byType(ListTile), findsWidgets);
    await _sonaKaydir(t);
    final son = t.getRect(find.byType(ListTile).last);
    // tam olarak bir kez bırakılır: ne çubuğa girer ne de ikinci bir boşluk kalır
    expect(son.bottom, closeTo(guvenliAlt, 0.5));
  });

  testWidgets('yemek arama: gezinme çubuğu yokken fazladan alt boşluk kalmaz',
      (t) async {
    await _ac(t, alt: 0);
    await _yaz(t, 'tavuk');
    await _sonaKaydir(t);
    expect(t.getRect(find.byType(ListTile).last).bottom, closeTo(900, 0.5));
  });
}
