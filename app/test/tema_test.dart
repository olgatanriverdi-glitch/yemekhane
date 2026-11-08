import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/screens/tema_secici.dart';
import 'package:yemekhane/tema.dart';

TemaRengi renkBul(String kimlik) =>
    temaRenkleri.firstWhere((r) => r.kimlik == kimlik);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('varsayılan: sistem modu ve Safran (sıcak turuncu)', () async {
    final ayar = TemaAyari();
    await ayar.yukle();
    expect(ayar.mod, ThemeMode.system);
    expect(ayar.siyah, isFalse);
    expect(ayar.renk.kimlik, 'safran');
  });

  test('eski renk kimlikleri yeni paletlere eşlenir', () async {
    SharedPreferences.setMockInitialValues({TemaAyari.renkAnahtari: 'mavi'});
    final ayar = TemaAyari();
    await ayar.yukle();
    expect(ayar.renk.kimlik, 'gece');
    expect(temaRengiBul('turuncu').kimlik, 'safran');
    expect(temaRengiBul('yesil').kimlik, 'zeytin');
  });

  test('siyah (AMOLED) seçimi kaydedilir; eski koyu kaydı bozulmaz', () async {
    final a = TemaAyari();
    await a.modSec(ThemeMode.dark, siyah: true);
    final b = TemaAyari();
    await b.yukle();
    expect(b.mod, ThemeMode.dark);
    expect(b.siyah, isTrue);
    expect(b.tema(Brightness.dark).colorScheme.surface, const Color(0xFF000000));
    await b.modSec(ThemeMode.dark);
    expect(b.siyah, isFalse);
    expect(b.tema(Brightness.dark).colorScheme.surface,
        isNot(const Color(0xFF000000)));
  });

  test('tüm paletler açık/koyu/siyah modda WCAG AA (>= 4.5) kontrasta sahip', () {
    for (final p in temaRenkleri) {
      for (final (parlaklik, amoled) in [
        (Brightness.light, false),
        (Brightness.dark, false),
        (Brightness.dark, true),
      ]) {
        final r = renkSemasiUret(p, parlaklik, amoled: amoled);
        final ad = '${p.kimlik}/${parlaklik.name}${amoled ? '/siyah' : ''}';
        void kontrol(String ne, Color on, Color zemin) => expect(
            kontrastOrani(on, zemin), greaterThanOrEqualTo(4.5),
            reason: '$ad $ne');
        kontrol('onSurface/surface', r.onSurface, r.surface);
        kontrol('onSurface/card', r.onSurface, r.surfaceContainerLow);
        kontrol('onSurfaceVariant/surface', r.onSurfaceVariant, r.surface);
        kontrol('onSurfaceVariant/highest', r.onSurfaceVariant,
            r.surfaceContainerHighest);
        kontrol('onPrimary/primary', r.onPrimary, r.primary);
        kontrol('onPrimaryContainer/primaryContainer', r.onPrimaryContainer,
            r.primaryContainer);
        kontrol('onSecondaryContainer/secondaryContainer',
            r.onSecondaryContainer, r.secondaryContainer);
        kontrol('onTertiaryContainer/tertiaryContainer',
            r.onTertiaryContainer, r.tertiaryContainer);
        kontrol('primary/surface', r.primary, r.surface);
        kontrol('onError/error', r.onError, r.error);
      }
    }
  });

  test('en az yedi isimli palet var', () {
    expect(temaRenkleri.length, greaterThanOrEqualTo(7));
  });

  test('renk kimlikleri benzersiz ve en az beş seçenek var', () {
    final kimlikler = temaRenkleri.map((r) => r.kimlik).toSet();
    expect(kimlikler.length, temaRenkleri.length);
    expect(temaRenkleri.length, greaterThanOrEqualTo(5));
  });

  test('seçim kaydedilir ve yeni örnek aynı seçimi yükler', () async {
    final a = TemaAyari();
    await a.modSec(ThemeMode.dark);
    await a.renkSec(renkBul('gece'));
    final b = TemaAyari();
    await b.yukle();
    expect(b.mod, ThemeMode.dark);
    expect(b.renk.kimlik, 'gece');
  });

  test('tanınmayan kayıtlı değerler varsayılana düşer', () async {
    SharedPreferences.setMockInitialValues(
        {TemaAyari.modAnahtari: 'garip', TemaAyari.renkAnahtari: 'yok'});
    final ayar = TemaAyari();
    await ayar.yukle();
    expect(ayar.mod, ThemeMode.system);
    expect(ayar.renk.kimlik, 'safran');
  });

  test('seçim değişince dinleyenler bir kez haberdar edilir, aynı seçim sessizdir',
      () async {
    final ayar = TemaAyari();
    var sayac = 0;
    ayar.addListener(() => sayac++);
    await ayar.modSec(ThemeMode.light);
    expect(sayac, 1);
    await ayar.modSec(ThemeMode.light); // aynı seçim
    expect(sayac, 1);
    await ayar.renkSec(renkBul('lavanta'));
    expect(sayac, 2);
  });

  test('renk değişince renk şeması ve parlaklık buna göre üretilir', () async {
    final ayar = TemaAyari();
    final turuncu = ayar.tema(Brightness.light).colorScheme.primary;
    await ayar.renkSec(renkBul('gece'));
    final mavi = ayar.tema(Brightness.light).colorScheme.primary;
    expect(mavi, isNot(turuncu));
    expect(ayar.tema(Brightness.dark).colorScheme.brightness, Brightness.dark);
    expect(ayar.tema(Brightness.light).useMaterial3, isTrue);
  });

  testWidgets('seçici: mod ve renk seçilince ayar güncellenir', (tester) async {
    final ayar = TemaAyari();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TemaSecici(ayar: ayar))));
    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('Sistem'), findsOneWidget);

    await tester.tap(find.text('Koyu'));
    await tester.pump();
    expect(ayar.mod, ThemeMode.dark);

    await tester.tap(find.text('Siyah'));
    await tester.pump();
    expect(ayar.siyah, isTrue);

    await tester.ensureVisible(find.text('Zeytin'));
    await tester.pump();
    await tester.tap(find.text('Zeytin'));
    await tester.pump();
    expect(ayar.renk.kimlik, 'zeytin');
    // seçili palet kartında onay işareti görünür
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
