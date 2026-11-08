import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/main.dart';
import 'package:yemekhane/screens/tema_secici.dart';
import 'package:yemekhane/tema.dart';

// TTF cmap/4: Türkçe harfler başka bir yazı tipine düşmeden gerçekten mevcut mu?
bool _glifVar(ByteData veri, int kod) {
  var cmap = 0;
  for (var i = 0; i < veri.getUint16(4); i++) {
    final kayit = 12 + 16 * i;
    if (veri.getUint32(kayit) == 0x636d6170) {
      cmap = veri.getUint32(kayit + 8);
      break;
    }
  }
  if (cmap == 0) return false;
  for (var i = 0; i < veri.getUint16(cmap + 2); i++) {
    final alt = cmap + veri.getUint32(cmap + 8 + 8 * i);
    if (veri.getUint16(alt) != 4) continue;
    final adet = veri.getUint16(alt + 6) ~/ 2;
    for (var j = 0; j < adet; j++) {
      final son = veri.getUint16(alt + 14 + 2 * j);
      final ilk = veri.getUint16(alt + 16 + 2 * adet + 2 * j);
      if (kod < ilk || kod > son) continue;
      final fark = veri.getUint16(alt + 16 + 4 * adet + 2 * j);
      final yer = alt + 16 + 6 * adet + 2 * j;
      final uzaklik = veri.getUint16(yer);
      final glif = uzaklik == 0
          ? (kod + fark) & 0xffff
          : veri.getUint16(yer + uzaklik + 2 * (kod - ilk));
      return glif != 0;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final (aile, dosya) in [
      ('Manrope', 'assets/fonts/Manrope-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(aile)..addFont(rootBundle.load(dosya))).load();
    }
  });

  test('sekiz temel palet ve 4–6 özel tema; eski kimlikler ve modlar korunur',
      () async {
    expect(temaRenkleri.where((p) => !p.ozel), hasLength(8));
    expect(temaRenkleri.where((p) => p.ozel).length, inInclusiveRange(4, 6));
    for (final (eski, yeni) in [
      ('turuncu', 'safran'),
      ('kirmizi', 'domates'),
      ('pembe', 'gul'),
      ('mor', 'lavanta'),
      ('mavi', 'gece'),
      ('turkuaz', 'deniz'),
      ('yesil', 'zeytin'),
      ('grafit', 'grafit'),
    ]) {
      SharedPreferences.setMockInitialValues({TemaAyari.renkAnahtari: eski});
      final ayar = TemaAyari();
      await ayar.yukle();
      expect(ayar.renk.kimlik, yeni);
    }
    for (final (mod, siyah, kayit) in [
      (ThemeMode.system, false, 'sistem'),
      (ThemeMode.light, false, 'acik'),
      (ThemeMode.dark, false, 'koyu'),
      (ThemeMode.dark, true, 'siyah'),
    ]) {
      final ayar = TemaAyari(mod: ThemeMode.light);
      if (mod == ThemeMode.light) await ayar.modSec(ThemeMode.system);
      await ayar.modSec(mod, siyah: siyah);
      expect(
          (await SharedPreferences.getInstance())
              .getString(TemaAyari.modAnahtari),
          kayit);
      final yuklenen = TemaAyari();
      await yuklenen.yukle();
      expect(yuklenen.mod, mod);
      expect(yuklenen.siyah, siyah);
    }
  });

  test(
      'Manrope uygulamaya paketlenir, Türkçe glifleri içerir ve 1 MB altındadır',
      () async {
    final font = await rootBundle.load('assets/fonts/Manrope-Variable.ttf');
    for (final harf in 'ğĞşŞıİçÇöÖüÜ'.runes) {
      expect(_glifVar(font, harf), isTrue, reason: String.fromCharCode(harf));
    }
    final lisans = File('assets/fonts/OFL.txt').readAsStringSync();
    expect(lisans, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(font.lengthInBytes + lisans.length, lessThan(1000000));
    expect(
        temaUret(temaRenkleri.first, Brightness.light)
            .textTheme
            .bodyLarge
            ?.fontFamily,
        'Manrope');
  });

  test('Manrope OFL lisansı lisans ekranında tam metinle sunulur', () async {
    temaLisanslariniKaydet();
    final kayitlar = await LicenseRegistry.licenses
        .where((e) => e.packages.contains('Manrope'))
        .toList();
    expect(kayitlar, hasLength(1));
    final metin = kayitlar.single.paragraphs.map((p) => p.text).join('\n');
    expect(metin, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(metin, contains('TERMINATION'));
    expect(metin, contains('OTHER DEALINGS IN THE FONT SOFTWARE.'));
  });

  for (final p in temaRenkleri) {
    for (final (parlaklik, siyah) in [
      (Brightness.light, false),
      (Brightness.dark, false),
      (Brightness.dark, true),
    ]) {
      final ad = '${p.ad}/${parlaklik.name}/${siyah ? 'siyah' : 'normal'}';
      test('$ad: tüm yüzey katmanlarında metin ve vurgular AA', () {
        final r = renkSemasiUret(p, parlaklik, amoled: siyah);
        for (final zemin in [
          r.surface,
          r.surfaceContainerLowest,
          r.surfaceContainerLow,
          r.surfaceContainer,
          r.surfaceContainerHigh,
          r.surfaceContainerHighest
        ]) {
          for (final yazi in [
            r.onSurface,
            r.onSurfaceVariant,
            r.primary,
            r.secondary,
            r.tertiary,
            r.error
          ]) {
            expect(kontrastOrani(yazi, zemin), greaterThanOrEqualTo(4.5),
                reason: ad);
          }
        }
        final katmanlar = [
          r.surfaceContainerLowest,
          r.surfaceContainerLow,
          r.surfaceContainer,
          r.surfaceContainerHigh,
          r.surfaceContainerHighest
        ].map((r) => r.computeLuminance()).toList();
        for (var i = 1; i < katmanlar.length; i++) {
          expect(
              katmanlar[i],
              parlaklik == Brightness.light
                  ? lessThan(katmanlar[i - 1])
                  : greaterThan(katmanlar[i - 1]));
        }
        if (siyah) expect(r.surface.toARGB32(), 0xff000000);
      });
    }
  }

  for (final genislik in [320.0, 390.0]) {
    for (final olcek in [1.0, 1.5, 2.0]) {
      testWidgets(
          'gerçek Manrope: ${genislik}x640 / $olcek; tüm mod ve paletler erişilebilir',
          (t) async {
        t.view.physicalSize = Size(genislik, 640);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = olcek;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final anlam = t.ensureSemantics();
        final ayar = TemaAyari(mod: ThemeMode.light);
        addTearDown(ayar.dispose);
        try {
          await t.pumpWidget(YemekhaneApp(
              ayar: ayar, ana: Scaffold(body: TemaSecici(ayar: ayar))));
          await t.pumpAndSettle();
          for (final ad in ['Sistem', 'Açık', 'Koyu', 'Siyah']) {
            await t.ensureVisible(find.bySemanticsLabel(ad));
            await t.pumpAndSettle();
            await t.tap(find.text(ad));
            await t.pumpAndSettle();
            final dugum = t.getSemantics(find.text(ad));
            expect(dugum.rect.width, greaterThanOrEqualTo(48));
            expect(dugum.rect.height, greaterThanOrEqualTo(48), reason: ad);
            expect(dugum.getSemanticsData().label, ad);
            expect(dugum.getSemanticsData().flagsCollection.isSelected,
                ui.Tristate.isTrue);
            for (final p in temaRenkleri) {
              await t.ensureVisible(find.bySemanticsLabel(p.ad));
              await t.pumpAndSettle();
              await t.tap(find.text(p.ad));
              await t.pumpAndSettle();
              expect(ayar.renk.kimlik, p.kimlik);
              final dugum = t.getSemantics(find.text(p.ad));
              expect(dugum.getSemanticsData().label, p.ad);
              expect(dugum.getSemanticsData().flagsCollection.isSelected,
                  ui.Tristate.isTrue);
              expect(t.takeException(), isNull, reason: '$ad / ${p.ad}');
            }
          }
        } finally {
          anlam.dispose();
        }
      });
    }
  }
}
