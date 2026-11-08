// Tema tasarımının gerçek menü verisi ve Manrope ile görsel doğrulaması.
// app içinde: flutter test tool/tema_gorselleri_test.dart
// Çıktılar yalnızca görevde belirtilen scratchpad/tema-gpt klasörüne yazılır.
// 04–06: bütün paletleri aynı karede görmek için uzatılmış ekran; diğerleri telefon boyutu.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/config.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/kalori_hedefi.dart';
import 'package:yemekhane/main.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/tema_secici.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

const _veri = '../data';
const _cikti =
    '/private/tmp/claude-501/-Volumes-Mac-SSD-yemekhane/da761bad-c9f4-4d53-9d49-d82f867232c1/scratchpad/tema-gpt';
const _fontlar =
    '/Volumes/Mac SSD/development/flutter/bin/cache/artifacts/material_fonts';

// ---- yerel dosyalardan yanıt veren sahte HttpClient (Image.network için) -------------------------------------------

File? _yerelDosya(Uri adres) {
  final tam = adres.toString();
  if (!tam.startsWith(veriTabanUrl)) return null;
  final yol = Uri.decodeFull(tam.substring(veriTabanUrl.length + 1));
  final f = File('$_veri/$yol');
  return f.existsSync() ? f : null;
}

class _Cevap extends Stream<List<int>> implements HttpClientResponse {
  _Cevap(this._bayt, this.statusCode);
  final Uint8List _bayt;
  @override
  final int statusCode;
  @override
  int get contentLength => _bayt.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_bayt).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Istek implements HttpClientRequest {
  _Istek(this._adres);
  final Uri _adres;
  @override
  final HttpHeaders headers = _Basliklar();
  @override
  Future<HttpClientResponse> close() async {
    final f = _yerelDosya(_adres);
    return f == null
        ? _Cevap(Uint8List(0), 404)
        : _Cevap(f.readAsBytesSync(), 200);
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Basliklar implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Istemci implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Istek(url);
  @override
  bool autoUncompress = true;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Gecersiz extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Istemci();
}

// ---- yardımcılar --------------------------------------------------------------------------------------------------

Future<void> _fontlariYukle() async {
  await (FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf')))
      .load();
  final ikon = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(
        File('$_fontlar/MaterialIcons-Regular.otf').readAsBytesSync())));
  await ikon.load();
}

/// Ağdan gelmesi gereken her şey (menü, fotoğraf) yerel ../data dosyalarından.
http.Client _yerelIstemci() => MockClient((r) async {
      final f = _yerelDosya(r.url);
      if (f == null) return http.Response('', 404);
      return http.Response.bytes(f.readAsBytesSync(), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

var _kok = GlobalKey();

Future<void> _bekle(WidgetTester t, [int tur = 12]) async {
  for (var i = 0; i < tur; i++) {
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump(const Duration(milliseconds: 120));
  }
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _kaydet(WidgetTester t, String ad) async {
  await _bekle(t, 6);
  await t.runAsync(() async {
    final sinir =
        _kok.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final resim = await sinir.toImage(pixelRatio: 2);
    final bayt = (await resim.toByteData(format: ui.ImageByteFormat.png))!;
    File('$_cikti/$ad.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bayt.buffer.asUint8List());
    stdout.writeln('yazıldı: $ad.png ${resim.width}x${resim.height}');
  });
}

Future<void> _ac(WidgetTester t,
    {required bool koyu,
    bool siyah = false,
    String palet = 'safran',
    Widget Function(TemaAyari)? ana,
    Size boyut = const Size(390, 780),
    double olcek = 1}) async {
  t.view.physicalSize = boyut;
  t.platformDispatcher.textScaleFactorTestValue = olcek;
  t.view.devicePixelRatio = 1;
  _kok = GlobalKey();
  final ayar = TemaAyari(
      mod: koyu ? ThemeMode.dark : ThemeMode.light,
      siyah: siyah,
      renk: temaRengiBul(palet));
  final depo = Depo(istemci: _yerelIstemci());
  await depo.universiteSec('ankara');
  final favoriler = FavoriDeposu();
  await favoriler.ekle('manti', 'Mantı');
  await t.pumpWidget(RepaintBoundary(
      key: _kok,
      child: YemekhaneApp(
          ayar: ayar,
          kaloriHedefi: KaloriHedefi(),
          ana: ana?.call(ayar) ??
              AnaSayfa(
                  temaAyari: ayar,
                  depo: depo,
                  geriBildirim: YerelDepo(),
                  favoriler: favoriler,
                  kaloriHedefi: KaloriHedefi(),
                  simdi: () => DateTime.utc(2026, 11, 4, 11, 20)))));
  // iskelet kalkana (menü yüklenene) kadar gerçek zamanla bekle
  for (var i = 0;
      i < 100 && find.byType(IskeletGovde).evaluate().isNotEmpty;
      i++) {
    await _bekle(t, 1);
  }
  await _bekle(t);
  expect(find.byType(IskeletGovde), findsNothing,
      reason: 'Görsel, veri yüklenmeden kaydedilmemeli.');
  if (ana == null) expect(find.text('Ankara Üniversitesi'), findsOneWidget);
}

Future<void> _menuden(WidgetTester t, String ogeAdi) async {
  await t.tap(find.byTooltip('Diğer'));
  await _bekle(t, 3);
  await t.tap(find.text(ogeAdi));
  await _bekle(t, 4);
}

void main() {
  setUpAll(() async {
    await _fontlariYukle();
    HttpOverrides.global = _Gecersiz();
  });
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Aynı test zone'unda kalınır: AssetBundle'ın önbelleklediği Future'lar önceki
  // testin durdurulmuş sahte saatinde beklemesin. Her karede ağaç yeni anahtarla kurulur.
  testWidgets('gerçek veriyle tema görsel seti', (t) async {
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    for (final (ad, koyu, siyah) in [
      ('01-safran-acik', false, false),
      ('02-safran-koyu', true, false),
      ('03-safran-siyah', true, true),
    ]) {
      await _ac(t, koyu: koyu, siyah: siyah);
      await _kaydet(t, ad);
    }

    for (final (ad, koyu, siyah) in [
      ('04-paletler-acik', false, false),
      ('05-paletler-koyu', true, false),
      ('06-paletler-siyah', true, true),
    ]) {
      await _ac(t,
          koyu: koyu,
          siyah: siyah,
          boyut: const Size(390, 1100),
          ana: (ayar) => Scaffold(body: TemaSecici(ayar: ayar)));
      await _kaydet(t, ad);
    }

    await _ac(t, koyu: false);
    await _menuden(t, 'Tema');
    await _kaydet(t, '07-gorunum-alt-sayfa');

    await _ac(t, koyu: false);
    await _menuden(t, 'Ayarlar');
    await _kaydet(t, '08-ayarlar-acik');

    await _ac(t,
        koyu: false,
        boyut: const Size(320, 640),
        olcek: 2,
        ana: (ayar) => Scaffold(body: TemaSecici(ayar: ayar)));
    await _kaydet(t, '09-gorunum-320-2x');

    await _ac(t, koyu: true, palet: 'deniz');
    await _kaydet(t, '10-deniz-koyu');

    await _ac(t, koyu: false);
    await t.drag(find.byType(ListView).first, const Offset(0, -260));
    await _bekle(t);
    await _kaydet(t, '11-safran-menu-acik');
  });
}
