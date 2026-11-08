// Reklam kartının ana ekrandaki görünümünü (SAHTE reklamla) PNG'ye çizer; açık ve koyu tema.
// `flutter test` yalnızca test/ klasörüne baktığından normal koşuda ÇALIŞMAZ. Çalıştırmak için (app klasöründe):
//
//   REKLAM_CIKTI=/yazilacak/klasor ~/development/flutter/bin/flutter test tool/reklam_gorunum_test.dart
//
// Gerçek yerel reklam şablonu Google'ın yerel kodudur; burada yalnızca yerleşim, boşluk, "Reklam" etiketi ve renkler
// görülür. Roboto ve MaterialIcons, Flutter önbelleğindeki dosyalardan yüklenir (tool/magaza_ekranlari_test.dart gibi).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/paylasim.dart';
import 'package:yemekhane/reklam/reklam_ayari.dart';
import 'package:yemekhane/reklam/reklam_yoneticisi.dart';
import 'package:yemekhane/reklam/sahte_reklam_servisi.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/hafta.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/yemek_detay.dart';
import 'package:yemekhane/tema.dart';

final _fontlar =
    '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';
final _cikti = Platform.environment['REKLAM_CIKTI'] ?? '/tmp';

class _Depo extends Depo {
  @override
  Future<List<Universite>> universiteler() async => [
        Universite(
            id: 'ankara',
            ad: 'Ankara Üniversitesi',
            kisa: 'ankara',
            sehir: 'Ankara',
            kaynak: '',
            ogunler: const ['lunch', 'dinner'],
            fiyatlar: const [])
      ];
  @override
  Future<Menu> menu(String id) async => Menu('ankara', null, {
        '2026-11-04': {
          'lunch': Ogun([
            YemekOgesi('Mercimek Çorbası', 120),
            YemekOgesi('Tavuk Sote', 380),
            YemekOgesi('Bulgur Pilavı', 250),
            YemekOgesi('Cacık', 60),
          ], 810),
        },
      });
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

Future<void> _yukleFont() async {
  final roboto = FontLoader('Roboto');
  for (final ad in ['Regular', 'Medium', 'Bold', 'Light']) {
    roboto.addFont(Future.value(ByteData.sublistView(
        File('$_fontlar/Roboto-$ad.ttf').readAsBytesSync())));
  }
  await roboto.load();
  final ikon = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(
        File('$_fontlar/MaterialIcons-Regular.otf').readAsBytesSync())));
  await ikon.load();
}

class _Paylasim implements PaylasimServisi {
  @override
  Future<void> paylas(String metin, {String? konu}) async {}
}

Universite _uni() => Universite(
    id: 'ankara',
    ad: 'Ankara Üniversitesi',
    kisa: 'ankara',
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch', 'dinner'],
    fiyatlar: const []);

Menu _hafta() => Menu('ankara', null, {
      for (var d = 2; d <= 8; d++)
        '2026-11-0$d': {
          'lunch': Ogun([
            YemekOgesi('Mercimek Çorbası', 120),
            YemekOgesi('Tavuk Sote', 380),
            YemekOgesi('Bulgur Pilavı', 250),
            YemekOgesi('Cacık', 60),
          ], 810),
        },
    });

/// [govde] widget'ını tema ve sahte reklamla çizer, [ad].png olarak kaydeder.
Future<void> _foto(WidgetTester t, bool koyu, String ad, Size boyut,
    Widget Function(ReklamYoneticisi y, TemaAyari ayar) govde,
    {Future<void> Function(WidgetTester t)? sonra}) async {
  final kok = GlobalKey();
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari(mod: koyu ? ThemeMode.dark : ThemeMode.light);
  final y = ReklamYoneticisi(
      servis: SahteReklamServisi(),
      simdi: () => DateTime.utc(2026, 11, 4, 11, 20));
  await t.pumpWidget(RepaintBoundary(
      key: kok,
      child: MaterialApp(
        theme: ayar.tema(Brightness.light),
        darkTheme: ayar.tema(Brightness.dark),
        themeMode: koyu ? ThemeMode.dark : ThemeMode.light,
        home: govde(y, ayar),
      )));
  await t.pumpAndSettle();
  await y.baslat();
  await t.pump(const Duration(seconds: 3));
  await t.pump(const Duration(milliseconds: 400));
  await t.pumpAndSettle();
  if (sonra != null) await sonra(t);
  await t.runAsync(() async {
    final sinir =
        kok.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final resim = await sinir.toImage(pixelRatio: 2);
    final bayt = (await resim.toByteData(format: ui.ImageByteFormat.png))!;
    File('$_cikti/$ad.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bayt.buffer.asUint8List());
  });
  await t.pumpWidget(const SizedBox());
  y.dispose();
}

Future<void> _ciz(WidgetTester t, bool koyu, String ad) => _foto(
    t,
    koyu,
    ad,
    const Size(390, 1000),
    (y, ayar) => AnaSayfa(
        temaAyari: ayar,
        depo: _Depo(),
        geriBildirim: YerelDepo(),
        simdi: () => DateTime.utc(2026, 11, 4, 11, 20),
        reklam: y));

Future<void> _haftaCiz(WidgetTester t, bool koyu, String ad) => _foto(
    t,
    koyu,
    ad,
    const Size(390, 900),
    (y, ayar) => HaftaSayfasi(
        uni: _uni(),
        menu: _hafta(),
        bugun: '2026-11-04',
        tarih: '2026-11-04',
        ogun: 'lunch',
        paylasim: _Paylasim(),
        reklam: y));

Future<void> _detayCiz(WidgetTester t, bool koyu, String ad) => _foto(
        t,
        koyu,
        ad,
        const Size(390, 1200),
        (y, ayar) => YemekDetaySayfasi(
            yemek: YemekOgesi('Tavuk Sote', 380, null, 'tavuk-sote'),
            uni: _uni(),
            menu: _hafta(),
            bugun: '2026-11-04',
            geriBildirim: YerelDepo(),
            reklam: y), sonra: (t) async {
      await t.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
    });

Future<void> _odulluCiz(WidgetTester t, bool koyu, String ad) => _foto(
        t,
        koyu,
        ad,
        const Size(390, 700),
        (y, ayar) => AnaSayfa(
            temaAyari: ayar,
            depo: _Depo(),
            geriBildirim: YerelDepo(),
            simdi: () => DateTime.utc(2026, 11, 4, 11, 20),
            reklam: y), sonra: (t) async {
      await t.dragUntilVisible(
          find.text('Reklamları 24 saat kapat'),
          find
              .descendant(
                  of: find.byType(OgunKarti), matching: find.byType(Scrollable))
              .first,
          const Offset(0, -80));
      await t.pumpAndSettle();
      await t.tap(find.text('Reklamları 24 saat kapat'));
      await t.pumpAndSettle();
    });

void main() {
  setUpAll(_yukleFont);
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues(
      {ilkAcilisAnahtari: '2026-10-01'}));

  testWidgets('ana açık', (t) => _ciz(t, false, 'reklam-v2-ana-acik'));
  testWidgets('ana koyu', (t) => _ciz(t, true, 'reklam-v2-ana-koyu'));
  testWidgets('hafta açık', (t) => _haftaCiz(t, false, 'reklam-v2-hafta-acik'));
  testWidgets('hafta koyu', (t) => _haftaCiz(t, true, 'reklam-v2-hafta-koyu'));
  testWidgets('detay açık', (t) => _detayCiz(t, false, 'reklam-v2-detay-acik'));
  testWidgets('detay koyu', (t) => _detayCiz(t, true, 'reklam-v2-detay-koyu'));
  testWidgets(
      'ödüllü açık', (t) => _odulluCiz(t, false, 'reklam-v2-odullu-acik'));
  testWidgets(
      'ödüllü koyu', (t) => _odulluCiz(t, true, 'reklam-v2-odullu-koyu'));
}
