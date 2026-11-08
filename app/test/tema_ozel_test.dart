import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/main.dart';
import 'package:yemekhane/screens/tema_secici.dart';
import 'package:yemekhane/tema.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final ozel = temaRenkleri.where((p) => p.ozel).toList();

  test('temel sekiz palet korunur; özel temaların kimlikleri ve imzaları ayrı',
      () {
    expect(temaRenkleri.where((p) => !p.ozel).map((p) => p.kimlik), [
      'safran',
      'domates',
      'gul',
      'lavanta',
      'gece',
      'deniz',
      'zeytin',
      'grafit',
    ]);
    expect(ozel.map((p) => p.ad),
        ['Aşk', 'Lokum', 'Kahve', 'Bahar', 'Gece Yarısı']);
    expect(temaRenkleri.map((p) => p.kimlik).toSet(),
        hasLength(temaRenkleri.length));
    expect(ozel.map((p) => p.imzaSimgesi).toSet(), hasLength(ozel.length));
    expect(temaRengiBul('ask').imzaSimgesi, Icons.favorite_rounded);
    expect(temaRengiBul('kahve').imzaSimgesi, Icons.local_cafe_outlined);
    expect(temaRengiBul('bahar').imzaSimgesi, Icons.local_florist_outlined);
    expect(temaRengiBul('bilinmeyen').kimlik, 'safran');
    expect(temaRengiBul('pembe').kimlik, 'gul');
  });

  test('Aşk, Gül’den daha canlı vurgu ve daha renkli bordo katmanlar taşır',
      () {
    final ask = temaRengiBul('ask'), gul = temaRengiBul('gul');
    final a = renkSemasiUret(ask, Brightness.light);
    final g = renkSemasiUret(gul, Brightness.light);
    expect(HSLColor.fromColor(a.primary).saturation,
        greaterThan(HSLColor.fromColor(g.primary).saturation + 0.20));
    expect(HSLColor.fromColor(a.surface).saturation,
        greaterThan(HSLColor.fromColor(g.surface).saturation + 0.30));
    for (final siyah in [false, true]) {
      final a = renkSemasiUret(ask, Brightness.dark, amoled: siyah);
      final g = renkSemasiUret(gul, Brightness.dark, amoled: siyah);
      expect(
          HSLColor.fromColor(a.surfaceContainerLow).saturation,
          greaterThan(
              HSLColor.fromColor(g.surfaceContainerLow).saturation + 0.25));
    }
  });

  for (final p in ozel) {
    test('${p.ad}: tüm modlarda kaydedilir, yeni örnekte imzasıyla yüklenir',
        () async {
      for (final (mod, siyah) in [
        (ThemeMode.system, false),
        (ThemeMode.light, false),
        (ThemeMode.dark, false),
        (ThemeMode.dark, true),
      ]) {
        SharedPreferences.setMockInitialValues({
          TemaAyari.renkAnahtari: 'mavi',
          TemaAyari.modAnahtari: 'koyu',
        });
        final a = TemaAyari();
        await a.yukle();
        await a.renkSec(p);
        await a.modSec(mod, siyah: siyah);
        final b = TemaAyari();
        await b.yukle();
        expect(b.renk.kimlik, p.kimlik);
        expect(b.mod, mod);
        expect(b.siyah, siyah);
        expect(
            (await SharedPreferences.getInstance())
                .getString(TemaAyari.renkAnahtari),
            p.kimlik);
        expect(b.tema(Brightness.dark).extension<TemaImzasi>()!.simge,
            p.imzaSimgesi);
        a.dispose();
        b.dispose();
      }
    });

    for (final (parlaklik, siyah) in [
      (Brightness.light, false),
      (Brightness.dark, false),
      (Brightness.dark, true),
    ]) {
      test('${p.ad}/${parlaklik.name}/$siyah: imza ve degradenin her tonu AA',
          () {
        final tema = temaUret(p, parlaklik, amoled: siyah);
        final imza = tema.extension<TemaImzasi>()!;
        expect(imza.simge, p.imzaSimgesi);
        expect(kontrastOrani(imza.renk, tema.colorScheme.surface),
            greaterThanOrEqualTo(4.5));
        expect(kontrastOrani(imza.zeminUstu, imza.zemin),
            greaterThanOrEqualTo(4.5));
        final renkler = imza.degrade!.colors;
        for (var i = 0; i <= 20; i++) {
          final zemin = Color.lerp(renkler.first, renkler.last, i / 20)!;
          expect(
              kontrastOrani(imza.zeminUstu, zemin), greaterThanOrEqualTo(4.5));
        }
      });
    }
  }

  test('imza copyWith ve lerp, tema geçişinde renkleri ve simgeyi korur', () {
    final a = temaUret(temaRengiBul('ask'), Brightness.light)
        .extension<TemaImzasi>()!;
    final b = temaUret(temaRengiBul('kahve'), Brightness.dark)
        .extension<TemaImzasi>()!;
    expect(a.copyWith().simge, a.simge);
    expect(a.copyWith().degrade, a.degrade);
    final kopya = a.copyWith(
        simge: b.simge,
        renk: b.renk,
        zemin: b.zemin,
        zeminUstu: b.zeminUstu,
        degrade: b.degrade);
    expect(kopya.simge, b.simge);
    expect(kopya.renk, b.renk);
    expect(kopya.zemin, b.zemin);
    expect(kopya.zeminUstu, b.zeminUstu);
    expect(kopya.degrade, b.degrade);
    expect(a.lerp(null, 0.5), same(a));
    expect(a.lerp(b, 0).renk, a.renk);
    expect(a.lerp(b, 1).zemin, b.zemin);
    final orta = a.lerp(b, 0.5);
    expect(orta.renk, Color.lerp(a.renk, b.renk, 0.5));
    expect(orta.zemin, Color.lerp(a.zemin, b.zemin, 0.5));
    expect(orta.zeminUstu, Color.lerp(a.zeminUstu, b.zeminUstu, 0.5));
    expect(orta.degrade, LinearGradient.lerp(a.degrade, b.degrade, 0.5));
    expect(orta.simge, b.simge);
  });

  testWidgets(
      'TemaImzasi.of, extension’ı okur; yoksa mevcut şemadan varsayılan üretir',
      (t) async {
    TemaImzasi? bulunan;
    Widget kabuk(ThemeData tema) => MaterialApp(
          theme: tema,
          themeAnimationDuration: Duration.zero,
          home: Builder(builder: (context) {
            bulunan = TemaImzasi.of(context);
            return const SizedBox.shrink();
          }),
        );
    final ask = temaUret(temaRengiBul('ask'), Brightness.light);
    await t.pumpWidget(kabuk(ask));
    expect(bulunan, same(ask.extension<TemaImzasi>()));
    final sade = ThemeData(colorScheme: ask.colorScheme);
    await t.pumpWidget(kabuk(sade));
    expect(bulunan!.simge, Icons.restaurant_rounded);
    expect(bulunan!.renk, sade.colorScheme.primary);
    expect(bulunan!.zemin, sade.colorScheme.primaryContainer);
    expect(bulunan!.zeminUstu, sade.colorScheme.onPrimaryContainer);
    expect(bulunan!.degrade, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'özel grup sekiz paletin altında; simgeler, açıklamalar ve seçim erişilebilir',
      (t) async {
    final anlam = t.ensureSemantics();
    final ayar = TemaAyari(mod: ThemeMode.light);
    addTearDown(ayar.dispose);
    try {
      await t.pumpWidget(YemekhaneApp(
          ayar: ayar, ana: Scaffold(body: TemaSecici(ayar: ayar))));
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.text('Özel temalar')).dy,
          greaterThan(t.getBottomLeft(find.text('Grafit')).dy));
      for (final p in ozel) {
        await t.ensureVisible(find.bySemanticsLabel(p.ad));
        await t.pumpAndSettle();
        final alan = find
            .ancestor(of: find.text(p.ad), matching: find.byType(Semantics))
            .first;
        expect(find.descendant(of: alan, matching: find.byIcon(p.imzaSimgesi)),
            findsOneWidget);
        expect(t.getSemantics(find.text(p.ad)).getSemanticsData().hint,
            p.aciklama);
        await t.tap(find.text(p.ad));
        await t.pumpAndSettle();
        expect(ayar.renk.kimlik, p.kimlik);
        expect(t.takeException(), isNull);
      }
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    } finally {
      anlam.dispose();
    }
  });
}
