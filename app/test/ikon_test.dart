import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/tema.dart';

// Uygulama ikonu ve açılış ekranı kaynakları. PNG'ler ve colors.xml tool/ikon_uret_test.dart ile üretilir;
// bu testler üretilen dosyaların boyutlarını, XML bağlantılarını ve renk tutarlılığını denetler.
// Testler app/ klasöründen çalışır (flutter test varsayılanı).

const String _res = 'android/app/src/main/res';
const String _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const Map<String, double> _yogunluklar = {
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};
const List<int> _pngImzasi = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

String _oku(String yol) {
  final dosya = File(yol);
  expect(dosya.existsSync(), isTrue, reason: '$yol yok');
  return dosya.readAsStringSync();
}

/// PNG başlığından (IHDR) genişlik, yükseklik ve renk türü (2 = RGB, 6 = RGBA).
({int genislik, int yukseklik, int renkTuru}) _baslik(String yol) {
  final dosya = File(yol);
  expect(dosya.existsSync(), isTrue, reason: '$yol yok');
  final bayt = dosya.readAsBytesSync();
  expect(bayt.sublist(0, 8), _pngImzasi, reason: '$yol PNG değil');
  expect(String.fromCharCodes(bayt.sublist(12, 16)), 'IHDR',
      reason: '$yol IHDR ile başlamıyor');
  final veri = ByteData.sublistView(bayt);
  return (
    genislik: veri.getUint32(16),
    yukseklik: veri.getUint32(20),
    renkTuru: bayt[25]
  );
}

void _kare(String yol, int px) {
  final b = _baslik(yol);
  expect((b.genislik, b.yukseklik), (px, px), reason: '$yol boyutu');
}

/// colors.xml içindeki `<color name="ad">#RRGGBB</color>` değeri (büyük harf).
String _renk(String xmlYolu, String ad) {
  final m = RegExp('<color name="$ad">(#[0-9A-Fa-f]{6})</color>')
      .firstMatch(_oku(xmlYolu));
  expect(m, isNotNull, reason: '$xmlYolu içinde $ad tanımlı değil');
  return m!.group(1)!.toUpperCase();
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color _renkDegeri(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

/// Çözülmüş PNG: ham RGBA (alfa önceden çarpılmış) pikselleri.
class _Resim {
  final int genislik, yukseklik;
  final ByteData veri;
  _Resim(this.genislik, this.yukseklik, this.veri);

  ({int r, int g, int b, int a}) piksel(int x, int y) {
    final i = (y * genislik + x) * 4;
    return (
      r: veri.getUint8(i),
      g: veri.getUint8(i + 1),
      b: veri.getUint8(i + 2),
      a: veri.getUint8(i + 3)
    );
  }

  String hex(int x, int y) {
    final p = piksel(x, y);
    String h(int n) => n.toRadixString(16).padLeft(2, '0');
    return '#${h(p.r)}${h(p.g)}${h(p.b)}'.toUpperCase();
  }
}

Future<_Resim> _coz(String yol) async {
  final codec = await ui.instantiateImageCodec(File(yol).readAsBytesSync());
  final kare = await codec.getNextFrame();
  final resim = (await kare.image.toByteData())!;
  final sonuc = _Resim(kare.image.width, kare.image.height, resim);
  kare.image.dispose();
  codec.dispose();
  return sonuc;
}

void main() {
  group('Android ikon PNG boyutları', () {
    test('mipmap ikonları (düz ve yuvarlak) 48 dp x yoğunluk', () {
      _yogunluklar.forEach((ad, d) {
        _kare('$_res/mipmap-$ad/ic_launcher.png', (48 * d).round());
        _kare('$_res/mipmap-$ad/ic_launcher_round.png', (48 * d).round());
      });
    });

    test('adaptive ön plan ve tek renkli katman 108 dp x yoğunluk', () {
      _yogunluklar.forEach((ad, d) {
        _kare(
            '$_res/drawable-$ad/ic_launcher_foreground.png', (108 * d).round());
        _kare(
            '$_res/drawable-$ad/ic_launcher_monochrome.png', (108 * d).round());
      });
    });

    test('Android 12 açılış ikonu 864 px', () {
      _kare('$_res/drawable-nodpi/splash_icon.png', 864);
    });

    test('en küçük ve en büyük mipmap ikonu 48 ve 192 px', () {
      _kare('$_res/mipmap-mdpi/ic_launcher.png', 48);
      _kare('$_res/mipmap-xxxhdpi/ic_launcher.png', 192);
    });
  });

  group('Adaptive ikon', () {
    for (final ad in ['ic_launcher', 'ic_launcher_round']) {
      test('$ad.xml: marka zemini, ön plan ve tek renkli katman', () {
        final xml = _oku('$_res/mipmap-anydpi-v26/$ad.xml');
        expect(xml, contains('<adaptive-icon'));
        expect(
            RegExp(r'<background\s+android:drawable="@color/ic_launcher_background"')
                .hasMatch(xml),
            isTrue);
        expect(
            RegExp(r'<foreground\s+android:drawable="@drawable/ic_launcher_foreground"')
                .hasMatch(xml),
            isTrue);
        expect(
            RegExp(r'<monochrome\s+android:drawable="@drawable/ic_launcher_monochrome"')
                .hasMatch(xml),
            isTrue);
      });
    }

    testWidgets(
        'ön plan ve tek renkli katman yalnızca merkezdeki 66 dp\'lik güvenli dairede çizilir',
        (tester) async {
      await tester.runAsync(() async {
        for (final ad in ['ic_launcher_foreground', 'ic_launcher_monochrome']) {
          final r = await _coz('$_res/drawable-xxxhdpi/$ad.png');
          expect((r.genislik, r.yukseklik), (432, 432));
          const yaricap = 66 / 108 * 432 / 2; // 132 px
          var cizili = 0;
          final disarida = <String>[];
          for (var y = 0; y < r.yukseklik; y++) {
            for (var x = 0; x < r.genislik; x++) {
              if (r.piksel(x, y).a == 0) continue;
              cizili++;
              final dx = x + 0.5 - r.genislik / 2,
                  dy = y + 0.5 - r.yukseklik / 2;
              if (dx * dx + dy * dy > (yaricap + 1) * (yaricap + 1)) {
                disarida.add('($x,$y)');
              }
            }
          }
          expect(disarida, isEmpty,
              reason: '$ad güvenli bölgenin dışında çiziyor');
          expect(cizili, greaterThan(432 * 432 ~/ 10),
              reason: '$ad neredeyse boş');
        }
      });
    });

    testWidgets(
        'tek renkli katman yalnızca beyaz ve oyuk içerir (bölmeler saydam)',
        (tester) async {
      await tester.runAsync(() async {
        final r =
            await _coz('$_res/drawable-xxxhdpi/ic_launcher_monochrome.png');
        var tam = 0, bos = 0;
        for (var y = 0; y < r.yukseklik; y++) {
          for (var x = 0; x < r.genislik; x++) {
            final p = r.piksel(x, y);
            if (p.a == 255) {
              tam++;
              expect((p.r, p.g, p.b), (255, 255, 255),
                  reason: '($x,$y) beyaz değil');
            } else if (p.a == 0) {
              bos++;
            }
          }
        }
        expect(tam, greaterThan(1000));
        expect(bos, greaterThan(1000));
        // 4 px/birim: büyük bölmedeki tabak dairesinin merkezi (44,1; 52,3) dolu, aynı bölmenin
        // tabağın dışında kalan köşesi (33; 38) oyuk.
        expect(r.piksel(176, 209).a, 255);
        expect(r.piksel(132, 152).a, 0);
      });
    });
  });

  group('Renkler', () {
    test('colors.xml marka, açılış ve pencere zeminlerini tanımlar', () {
      for (final ad in [
        'ic_launcher_background',
        'acilis_zemini',
        'pencere_zemini'
      ]) {
        _renk('$_res/values/colors.xml', ad);
      }
      for (final ad in ['acilis_zemini', 'pencere_zemini']) {
        _renk('$_res/values-night/colors.xml', ad);
      }
    });

    test('marka rengi Safran paletinin tonu ve doygunluğundadır', () {
      final safran = temaRengiBul('safran');
      final marka = HSLColor.fromColor(_renkDegeri(
          _renk('$_res/values/colors.xml', 'ic_launcher_background')));
      expect((marka.hue - safran.ton).abs(), lessThan(2));
      expect((marka.saturation - safran.doygunluk).abs(), lessThan(0.03));
    });

    test(
        'açık ve koyu zeminler Safran paletinin yüzey renkleridir; açılış koyu modda koyudur',
        () {
      final safran = temaRengiBul('safran');
      expect(_renk('$_res/values/colors.xml', 'pencere_zemini'),
          _hex(renkSemasiUret(safran, Brightness.light).surface));
      expect(_renk('$_res/values-night/colors.xml', 'pencere_zemini'),
          _hex(renkSemasiUret(safran, Brightness.dark).surface));
      expect(_renk('$_res/values-night/colors.xml', 'acilis_zemini'),
          _hex(renkSemasiUret(safran, Brightness.dark).surface));
      // Açık modda açılış zemini marka rengidir.
      expect(_renk('$_res/values/colors.xml', 'acilis_zemini'),
          _renk('$_res/values/colors.xml', 'ic_launcher_background'));
    });

    testWidgets('PNG ikonların zemini colors.xml marka rengiyle aynı',
        (tester) async {
      await tester.runAsync(() async {
        final marka =
            _renk('$_res/values/colors.xml', 'ic_launcher_background');
        for (final yol in [
          'web/icons/Icon-192.png',
          'web/icons/Icon-512.png',
          'web/icons/Icon-maskable-192.png',
          'web/icons/Icon-maskable-512.png',
          '$_ios/Icon-App-1024x1024@1x.png',
          '$_ios/Icon-App-60x60@3x.png',
        ]) {
          final r = await _coz(yol);
          expect(r.hex(1, 1), marka, reason: '$yol sol üst köşe');
          expect(r.piksel(1, 1).a, 255,
              reason: '$yol köşesi saydam olmamalı (apple-touch-icon)');
        }
        for (final yol in [
          '$_res/mipmap-xxxhdpi/ic_launcher.png',
          '$_res/mipmap-mdpi/ic_launcher.png'
        ]) {
          final r = await _coz(yol);
          expect(r.hex(r.genislik ~/ 2, 1), marka, reason: '$yol üst orta');
        }
        // Yuvarlatılmış köşe saydamdır.
        expect(
            (await _coz('$_res/mipmap-xxxhdpi/ic_launcher.png')).piksel(0, 0).a,
            0);
      });
    });

    test('web manifest theme_color marka rengiyle aynı', () {
      final manifest =
          jsonDecode(_oku('web/manifest.json')) as Map<String, dynamic>;
      expect((manifest['theme_color'] as String).toUpperCase(),
          _renk('$_res/values/colors.xml', 'ic_launcher_background'));
    });
  });

  group('Açılış ekranı', () {
    for (final (klasor, parent) in [
      ('values-v31', 'Theme.Light.NoTitleBar'),
      ('values-night-v31', 'Theme.Black.NoTitleBar'),
    ]) {
      test('$klasor: sistem açılış ekranı zemini ve ikonu tanımlı', () {
        final xml = _oku('$_res/$klasor/styles.xml');
        expect(
            xml,
            contains(
                '<style name="LaunchTheme" parent="@android:style/$parent">'));
        expect(
            RegExp(r'<item name="android:windowSplashScreenBackground">@color/acilis_zemini</item>')
                .hasMatch(xml),
            isTrue);
        expect(
            RegExp(r'<item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>')
                .hasMatch(xml),
            isTrue);
        expect(
            RegExp(r'<item name="android:windowBackground">@drawable/launch_background</item>')
                .hasMatch(xml),
            isTrue);
      });
    }

    for (final klasor in ['drawable', 'drawable-v21']) {
      test(
          '$klasor/launch_background.xml: marka zemini ve ortada ön plan bitmap',
          () {
        final xml = _oku('$_res/$klasor/launch_background.xml');
        expect(xml, contains('@color/acilis_zemini'));
        expect(xml, contains('<bitmap'));
        expect(xml, contains('android:gravity="center"'));
        expect(xml, contains('@drawable/ic_launcher_foreground'));
        expect(xml, isNot(contains('@android:color/white')));
      });
    }

    for (final klasor in ['values', 'values-night']) {
      test('$klasor/styles.xml: NormalTheme zemini uygulama yüzeyiyle uyumlu',
          () {
        final xml = _oku('$_res/$klasor/styles.xml');
        final normal = RegExp(r'<style name="NormalTheme"[^>]*>(.*?)</style>',
                dotAll: true)
            .firstMatch(xml);
        expect(normal, isNotNull);
        expect(
            normal!.group(1),
            contains(
                '<item name="android:windowBackground">@color/pencere_zemini</item>'));
        // Açılış teması da eski beyaz zemine dönmemeli.
        expect(xml, contains('@drawable/launch_background'));
      });
    }
  });

  group('Manifest ve kaynak bağlantıları', () {
    test(
        'uygulama adı Üni Yemek; ikon ve yuvarlak ikon tanımlı kaynaklara çıkar',
        () {
      final xml = _oku('android/app/src/main/AndroidManifest.xml');
      expect(xml, contains('android:label="Üni Yemek"'));
      expect(xml, contains('android:icon="@mipmap/ic_launcher"'));
      expect(xml, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
      for (final ad in ['ic_launcher', 'ic_launcher_round']) {
        expect(File('$_res/mipmap-anydpi-v26/$ad.xml').existsSync(), isTrue);
        for (final yogunluk in _yogunluklar.keys) {
          expect(File('$_res/mipmap-$yogunluk/$ad.png').existsSync(), isTrue,
              reason: 'Android 7.1 ve öncesi için $ad.png ($yogunluk) gerekli');
        }
      }
    });

    test(
        'res XML dosyalarındaki @color / @drawable / @mipmap başvuruları tanımlı kaynaklara çıkar',
        () {
      final res = Directory(_res);
      final dosyalar = res.listSync(recursive: true).whereType<File>().toList();
      final renkler = <String>{};
      for (final f in dosyalar.where((f) => f.path.endsWith('/colors.xml'))) {
        for (final m in RegExp(r'<color name="(\w+)"')
            .allMatches(f.readAsStringSync())) {
          renkler.add(m.group(1)!);
        }
      }
      String ad(File f) =>
          f.uri.pathSegments.last.replaceFirst(RegExp(r'\.\w+$'), '');
      final cizilebilir = {
        for (final f in dosyalar)
          if (RegExp(r'/(drawable|mipmap)[^/]*/[^/]+$').hasMatch(f.path)) ad(f),
      };
      final kaynaklar = [
        ...dosyalar.where((f) => f.path.endsWith('.xml')),
        File('android/app/src/main/AndroidManifest.xml'),
      ];
      var bakilan = 0;
      for (final f in kaynaklar) {
        for (final m in RegExp(r'@(color|drawable|mipmap)/(\w+)')
            .allMatches(f.readAsStringSync())) {
          bakilan++;
          final tanimli = m.group(1) == 'color' ? renkler : cizilebilir;
          expect(tanimli, contains(m.group(2)),
              reason: '${f.path}: ${m.group(0)} tanımlı değil');
        }
      }
      expect(bakilan, greaterThan(10));
    });
  });

  group('Web ve iOS ikonları', () {
    test('web/manifest.json ikonları var ve bildirilen boyutta', () {
      final manifest =
          jsonDecode(_oku('web/manifest.json')) as Map<String, dynamic>;
      final ikonlar = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      expect(ikonlar.length, 4);
      for (final ikon in ikonlar) {
        final px = int.parse((ikon['sizes'] as String).split('x').first);
        _kare('web/${ikon['src']}', px);
      }
      expect(ikonlar.where((i) => i['purpose'] == 'maskable').length, 2);
      expect(manifest['name'], 'Üni Yemek');
    });

    test('favicon 64 px', () {
      _kare('web/favicon.png', 64);
    });

    test(
        'iOS AppIcon seti Contents.json ile uyumlu: boyut = size x scale, alfa kanalsız',
        () {
      final icerik =
          jsonDecode(_oku('$_ios/Contents.json')) as Map<String, dynamic>;
      final resimler = (icerik['images'] as List).cast<Map<String, dynamic>>();
      expect(resimler.length, greaterThanOrEqualTo(18));
      for (final r in resimler) {
        final boyut = double.parse((r['size'] as String).split('x').first);
        final olcek = int.parse((r['scale'] as String).replaceAll('x', ''));
        final yol = '$_ios/${r['filename']}';
        _kare(yol, (boyut * olcek).round());
        expect(_baslik(yol).renkTuru, 2,
            reason: '$yol alfa kanalı içermemeli (App Store)');
      }
    });
  });
}
