// Uygulama ikonu ve açılış ekranı varlıklarının üreticisi.
//
// `flutter test` yalnızca test/ klasörüne baktığından bu dosya normal test koşusunda ÇALIŞMAZ; ikonları
// yenilemek için app klasöründe şunu çalıştırın:
//
//   ~/development/flutter/bin/flutter test tool/ikon_uret_test.dart
//
// Tasarım tek kaynaktan çizilir: 108 birimlik adaptive ikon tuvalinde Safran zeminli, krem tabldot tepsisi
// (bir büyük, iki küçük bölme; bölmelerde tabak ve iki kase). Düz renkler; derinlik yalnızca tepsi gölgesi ve
// bölmelerdeki bir ton koyu zeminle verilir, metin yoktur. Marka renkleri lib/tema.dart'taki varsayılan (Safran)
// paletten türetilir.
// Üretilen dosyalar (test/ikon_test.dart bunları denetler):
//   android/app/src/main/res/mipmap-*dpi/ic_launcher.png, ic_launcher_round.png   (Android 7 ve öncesi)
//   android/app/src/main/res/drawable-*dpi/ic_launcher_foreground.png, ic_launcher_monochrome.png  (adaptive)
//   android/app/src/main/res/drawable-nodpi/splash_icon.png                       (Android 12+ açılış ikonu)
//   android/app/src/main/res/values/colors.xml, values-night/colors.xml
//   web/icons/Icon-192|512.png, Icon-maskable-192|512.png, web/favicon.png
//   ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png                           (alfa kanalsız)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/tema.dart';

const String _res = 'android/app/src/main/res';

/// Adaptive ikon tuvali (dp). Ortadaki 66'lık daire her maskede görünen güvenli bölgedir.
const double _tuval = 108;

/// Yoğunluk niteleyicisi -> ölçek (mdpi = 1x); klasör adı "mipmap-<niteleyici>" biçimindedir.
const Map<String, double> _yogunluklar = {
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

// ---- Renkler: Safran paletinden ------------------------------------------------------------------

final TemaRengi _palet = temaRenkleri.first; // varsayılan palet (Safran)

Color _ton(double ton, double doygunluk, double aciklik) =>
    HSLColor.fromAHSL(1, ton % 360, doygunluk, aciklik).toColor();

/// İkon ve açılış ekranı zemini (marka rengi).
final Color _marka = _ton(_palet.ton, _palet.doygunluk, 0.50);

/// Bölmeler ve tepsi gölgesi: zeminin bir ton koyusu (düz renk, tek derinlik farkı).
final Color _derin = _ton(_palet.ton, _palet.doygunluk, 0.415);

/// Tepsinin kendisi.
final Color _krem = _ton(_palet.yuzeyTon, 0.90, 0.95);

/// Bölmelerdeki yemek daireleri (tabak ve iki kase): tepsiden bir ton koyu, bölmeden açık.
final Color _tabak = _ton(_palet.ton, 0.85, 0.80);

/// Flutter arayüzü çizilene dek pencere zemini: paletin açık / koyu yüzey rengi.
final Color _acikYuzey = renkSemasiUret(_palet, Brightness.light).surface;
final Color _koyuYuzey = renkSemasiUret(_palet, Brightness.dark).surface;

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

// ---- Tepsi geometrisi (108 birimlik tuvalde, merkez 54,54) ----------------------------------------
// Merkezden en uzak nokta (gölge dahil) ~31,8 birim: 33'lük güvenli daireye sığar.

final RRect _govde =
    RRect.fromLTRBR(26, 31.3, 82, 73.3, const Radius.circular(9.5));
const double _golgeKaymasi = 2.6;

RRect _bolme(double sol, double ust, double sag, double alt) =>
    RRect.fromLTRBR(sol, ust, sag, alt, const Radius.circular(4.6));

/// Bir büyük (solda) ve iki küçük (sağda, üst üste) bölme.
final List<RRect> _bolmeler = [
  _bolme(30.6, 35.9, 57.6, 68.7),
  _bolme(61.0, 35.9, 77.4, 50.6),
  _bolme(61.0, 54.0, 77.4, 68.7),
];

/// Her bölmenin ortasındaki yemek dairesi (merkez, yarıçap): büyükte tabak, küçüklerde kase.
final List<(Offset, double)> _tabaklar = [
  (const Offset(44.1, 52.3), 10.6),
  (const Offset(69.2, 43.25), 5.0),
  (const Offset(69.2, 61.35), 5.0),
];

/// Tam renkli tepsi: gölge, gövde, bölmeler, yemek daireleri.
void _tepsi(Canvas c) {
  c.drawRRect(
      _govde.shift(const Offset(0, _golgeKaymasi)), Paint()..color = _derin);
  c.drawRRect(_govde, Paint()..color = _krem);
  for (final b in _bolmeler) {
    c.drawRRect(b, Paint()..color = _derin);
  }
  for (final (merkez, yaricap) in _tabaklar) {
    c.drawCircle(merkez, yaricap, Paint()..color = _tabak);
  }
}

/// Tek renkli (Android 13 temalı ikon) sürüm: gövde dolu, bölmeler oyuk, yemek daireleri dolu.
void _tepsiSiluet(Canvas c) {
  final yol = Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(_govde);
  for (final b in _bolmeler) {
    yol.addRRect(b);
  }
  for (final (merkez, yaricap) in _tabaklar) {
    yol.addOval(Rect.fromCircle(center: merkez, radius: yaricap));
  }
  c.drawPath(yol, Paint()..color = const Color(0xFFFFFFFF));
}

/// 108 birimlik tasarımın merkezini [boyut] px'lik karenin ortasına, [birim] px/birim ölçekle koyar.
void _yerlestir(Canvas c, double boyut, double birim) {
  c.translate(boyut / 2, boyut / 2);
  c.scale(birim);
  c.translate(-_tuval / 2, -_tuval / 2);
}

typedef _Cizim = void Function(Canvas c, double boyut);

/// Saydam tuval üzerinde yalnızca ön plan (adaptive ikon katmanları ve açılış ikonu).
_Cizim get _onPlan => (c, s) {
      _yerlestir(c, s, s / _tuval);
      _tepsi(c);
    };

_Cizim get _tekRenk => (c, s) {
      _yerlestir(c, s, s / _tuval);
      _tepsiSiluet(c);
    };

enum _Sekil { kare, yuvarlakKare, daire }

/// Marka zeminli tam ikon (kare, yuvarlatılmış kare ya da daire). 1 tasarım birimi, kenarın
/// 1/[genislikBolen]'i kadar px olur; tepsi 56 birim genişliğinde olduğundan kenarın 56/[genislikBolen]'ini
/// kaplar (80 -> %70, 84 -> %67, 88 -> %64).
_Cizim _ikon(_Sekil sekil, double genislikBolen) => (c, s) {
      final zemin = Paint()..color = _marka;
      switch (sekil) {
        case _Sekil.kare:
          c.drawRect(Offset.zero & Size(s, s), zemin);
        case _Sekil.yuvarlakKare:
          c.drawRRect(
              RRect.fromRectAndRadius(
                  Offset.zero & Size(s, s), Radius.circular(s * 0.225)),
              zemin);
        case _Sekil.daire:
          c.drawCircle(Offset(s / 2, s / 2), s / 2, zemin);
      }
      c.save();
      _yerlestir(c, s, s / genislikBolen);
      _tepsi(c);
      c.restore();
    };

// ---- PNG yazımı ------------------------------------------------------------------------------------

int _yazilan = 0;

Future<ui.Image> _resimUret(int px, _Cizim cizim) async {
  final kayit = ui.PictureRecorder();
  cizim(Canvas(kayit), px.toDouble());
  final resim = kayit.endRecording();
  final goruntu = await resim.toImage(px, px);
  resim.dispose();
  return goruntu;
}

/// [opak] ise alfa kanalsız (RGB) PNG yazar; App Store 1024 px ikonda alfa kabul etmez.
Future<void> _png(String yol, int px, _Cizim cizim, {bool opak = false}) async {
  final goruntu = await _resimUret(px, cizim);
  final Uint8List bayt;
  if (opak) {
    final ham = (await goruntu.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    bayt = _rgbPng(px, px, ham);
  } else {
    final veri = (await goruntu.toByteData(format: ui.ImageByteFormat.png))!;
    bayt = veri.buffer.asUint8List(veri.offsetInBytes, veri.lengthInBytes);
  }
  goruntu.dispose();
  File(yol)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bayt);
  _yazilan++;
}

void _metin(String yol, String icerik) {
  File(yol)
    ..createSync(recursive: true)
    ..writeAsStringSync(icerik);
}

final List<int> _crcTablosu = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bayt) {
  var c = 0xFFFFFFFF;
  for (final b in bayt) {
    c = _crcTablosu[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _dortBayt(int n) => Uint8List(4)..buffer.asByteData().setUint32(0, n);

/// Ham RGBA'dan (alfası yok sayılır) sekiz bitlik RGB PNG üretir.
Uint8List _rgbPng(int genislik, int yukseklik, ByteData rgba) {
  final satirlar = BytesBuilder(copy: false);
  for (var y = 0; y < yukseklik; y++) {
    satirlar.addByte(0); // satır süzgeci yok
    for (var x = 0; x < genislik; x++) {
      final i = (y * genislik + x) * 4;
      satirlar
        ..addByte(rgba.getUint8(i))
        ..addByte(rgba.getUint8(i + 1))
        ..addByte(rgba.getUint8(i + 2));
    }
  }
  final baslik = BytesBuilder()
    ..add(_dortBayt(genislik))
    ..add(_dortBayt(yukseklik))
    ..add(const [8, 2, 0, 0, 0]); // 8 bit, RGB, sıkıştırma/süzgeç/geçişsiz
  final cikti = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void parca(String tur, List<int> veri) {
    final govde = [...ascii.encode(tur), ...veri];
    cikti
      ..add(_dortBayt(veri.length))
      ..add(govde)
      ..add(_dortBayt(_crc32(govde)));
  }

  parca('IHDR', baslik.toBytes());
  parca('IDAT', zlib.encode(satirlar.toBytes()));
  parca('IEND', const []);
  return cikti.toBytes();
}

// ---- Çıktılar --------------------------------------------------------------------------------------

Future<void> _androidUret() async {
  for (final MapEntry(key: ad, value: d) in _yogunluklar.entries) {
    await _png('$_res/mipmap-$ad/ic_launcher.png', (48 * d).round(),
        _ikon(_Sekil.yuvarlakKare, 80));
    await _png('$_res/mipmap-$ad/ic_launcher_round.png', (48 * d).round(),
        _ikon(_Sekil.daire, 88));
    await _png('$_res/drawable-$ad/ic_launcher_foreground.png',
        (108 * d).round(), _onPlan);
    await _png('$_res/drawable-$ad/ic_launcher_monochrome.png',
        (108 * d).round(), _tekRenk);
  }
  // Açılış ikonu tuvali 288dp; yoğunluktan bağımsız, 3x'te birebir keskin olsun diye 864 px.
  await _png('$_res/drawable-nodpi/splash_icon.png', 864, _onPlan);

  _metin('$_res/values/colors.xml', '''<?xml version="1.0" encoding="utf-8"?>
<!-- tool/ikon_uret_test.dart üretir; renkler lib/tema.dart'taki Safran paletinden türetilir. -->
<resources>
    <!-- Uygulama ikonunun (adaptive) ve açılış ekranının marka zemini. -->
    <color name="ic_launcher_background">${_hex(_marka)}</color>
    <!-- Açılış ekranı zemini: açık modda marka rengi (koyu modda values-night). -->
    <color name="acilis_zemini">${_hex(_marka)}</color>
    <!-- Flutter arayüzü çizilene dek pencere zemini: Safran açık yüzey. -->
    <color name="pencere_zemini">${_hex(_acikYuzey)}</color>
</resources>
''');
  _metin(
      '$_res/values-night/colors.xml', '''<?xml version="1.0" encoding="utf-8"?>
<!-- tool/ikon_uret_test.dart üretir; koyu moddaki zeminler Safran koyu yüzeyidir (parlak turuncu parlamasın). -->
<resources>
    <color name="acilis_zemini">${_hex(_koyuYuzey)}</color>
    <color name="pencere_zemini">${_hex(_koyuYuzey)}</color>
</resources>
''');
}

Future<void> _webUret() async {
  await _png('web/icons/Icon-192.png', 192, _ikon(_Sekil.kare, 80));
  await _png('web/icons/Icon-512.png', 512, _ikon(_Sekil.kare, 80));
  // Maskable: tüm tuval dolu, içerik merkezdeki %80'lik dairede (yarıçap 0,4).
  await _png('web/icons/Icon-maskable-192.png', 192, _ikon(_Sekil.kare, 84));
  await _png('web/icons/Icon-maskable-512.png', 512, _ikon(_Sekil.kare, 84));
  await _png('web/favicon.png', 64, _ikon(_Sekil.yuvarlakKare, 74));
}

/// Contents.json'daki her dosya için "boyut x ölçek" pikselinde alfa kanalsız ikon yazar.
Future<void> _iosUret() async {
  const klasor = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final icerik = jsonDecode(File('$klasor/Contents.json').readAsStringSync())
      as Map<String, dynamic>;
  for (final oge in (icerik['images'] as List).cast<Map<String, dynamic>>()) {
    final boyut = double.parse((oge['size'] as String).split('x').first);
    final olcek = int.parse((oge['scale'] as String).replaceAll('x', ''));
    await _png('$klasor/${oge['filename']}', (boyut * olcek).round(),
        _ikon(_Sekil.kare, 80),
        opak: true);
  }
}

void main() {
  testWidgets('ikonlar ve renk kaynakları üretilir', (tester) async {
    expect(File('pubspec.yaml').existsSync(), isTrue,
        reason: 'Bu dosya app/ klasöründen çalıştırılmalı.');
    await tester.runAsync(() async {
      await _androidUret();
      await _webUret();
      await _iosUret();
    });
    stdout.writeln('Üretilen PNG sayısı: $_yazilan');
    stdout.writeln(
        'marka ${_hex(_marka)}  derin ${_hex(_derin)}  krem ${_hex(_krem)}  tabak ${_hex(_tabak)}  '
        'açık yüzey ${_hex(_acikYuzey)}  koyu yüzey ${_hex(_koyuYuzey)}');
    expect(_yazilan, greaterThan(40));
  });
}
