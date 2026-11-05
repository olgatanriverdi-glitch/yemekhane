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
import 'package:yemekhane/reklam/reklam_ayari.dart';
import 'package:yemekhane/reklam/reklam_yoneticisi.dart';
import 'package:yemekhane/reklam/sahte_reklam_servisi.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
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

Future<void> _ciz(WidgetTester t, bool koyu, String ad) async {
  final kok = GlobalKey();
  t.view.physicalSize = const Size(390, 900);
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
        home: AnaSayfa(
            temaAyari: ayar,
            depo: _Depo(),
            geriBildirim: YerelDepo(),
            simdi: () => DateTime.utc(2026, 11, 4, 11, 20),
            reklam: y),
      )));
  await t.pumpAndSettle();
  await t.pump(const Duration(seconds: 3));
  await t.pump(const Duration(milliseconds: 400));
  await t.pumpAndSettle();
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

void main() {
  setUpAll(_yukleFont);
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues(
      {ilkAcilisAnahtari: '2026-10-01'}));

  testWidgets('açık tema', (t) => _ciz(t, false, 'reklam-acik'));
  testWidgets('koyu tema', (t) => _ciz(t, true, 'reklam-koyu'));
}
