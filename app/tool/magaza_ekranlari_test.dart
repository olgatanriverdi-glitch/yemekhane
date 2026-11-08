// Google Play mağaza görselleri üreticisi: telefon ekran görüntüleri (1170x2340, 2:1) ve 1024x500 öne çıkan görsel.
//
// `flutter test` yalnızca test/ klasörüne baktığından bu dosya normal test koşusunda ÇALIŞMAZ. Görselleri yenilemek için
// app klasöründe şunu çalıştırın:
//
//   ~/development/flutter/bin/flutter test tool/magaza_ekranlari_test.dart
//
// Gerçek uygulama gerçek veriyle çizilir: menüler ve fotoğraflar ../data klasöründen okunur (ağ yok; Depo'ya sahte
// istemci, Image.network'e yerel dosyalardan yanıt veren sahte HttpClient verilir). Test ortamının varsayılan yazı tipi
// (Ahem) kutu çizdiğinden Roboto ve MaterialIcons Flutter önbelleğindeki dosyalardan yüklenir.
// Çıktılar: ../magaza/ekranlar/*.png ve ../magaza/gorseller/ofne-cikan-1024x500.png
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
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

import 'opak_png.dart';

const _veri = '../data';
const _cikti = '../magaza/ekranlar';
final _fontlar =
    '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';

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
    final resim = await sinir.toImage(pixelRatio: 3);
    // Google Play alfasız 24 bit PNG ister: RGBA yerine beyaz zemine birleştirilmiş RGB yazılır
    final ham = (await resim.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    File('$_cikti/$ad.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(opakPng(resim.width, resim.height, ham));
    stdout.writeln('yazıldı: $ad.png ${resim.width}x${resim.height}');
  });
}

Future<void> _ac(WidgetTester t, {required bool koyu, Widget? ana}) async {
  t.view.physicalSize = const Size(390, 780);
  t.view.devicePixelRatio = 1;
  _kok = GlobalKey();
  final ayar = TemaAyari(mod: koyu ? ThemeMode.dark : ThemeMode.light);
  final depo = Depo(istemci: _yerelIstemci());
  await depo.universiteSec('ankara');
  final favoriler = FavoriDeposu();
  await favoriler.ekle('manti', 'Mantı');
  await t.pumpWidget(RepaintBoundary(
      key: _kok,
      child: YemekhaneApp(
          ayar: ayar,
          kaloriHedefi: KaloriHedefi(),
          ana: ana ??
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

  testWidgets('01 ana ekran', (t) async {
    await _ac(t, koyu: false);
    await _kaydet(t, '01-ana-ekran');
  });

  testWidgets('02 yemek ayrıntısı', (t) async {
    await _ac(t, koyu: false);
    await t.tap(find.textContaining('Kırmızı Mercimek'));
    await _bekle(t, 20);
    await _kaydet(t, '02-yemek-detayi');
  });

  testWidgets('03 yemek arama', (t) async {
    await _ac(t, koyu: false);
    await t.tap(find.byTooltip('Yemek ara'));
    await _bekle(t, 3);
    await t.enterText(find.byType(TextField), 'pilav');
    await t.pump(const Duration(milliseconds: 400));
    await _bekle(t, 25);
    await _kaydet(t, '03-yemek-arama');
  });

  testWidgets('04 haftalık menü', (t) async {
    await _ac(t, koyu: false);
    await _menuden(t, 'Haftalık menü');
    await _kaydet(t, '04-haftalik-menu');
  });

  testWidgets('05 tema (koyu)', (t) async {
    await _ac(t, koyu: true);
    await _menuden(t, 'Tema');
    await _kaydet(t, '05-tema-secici-koyu');
  });

  testWidgets('06 ayarlar', (t) async {
    await _ac(t, koyu: false);
    await _menuden(t, 'Ayarlar');
    await _kaydet(t, '06-ayarlar');
  });

  testWidgets('07 ana ekran koyu', (t) async {
    await _ac(t, koyu: true);
    await _kaydet(t, '07-ana-ekran-koyu');
  });
}
