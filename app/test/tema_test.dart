import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/screens/tema_secici.dart';
import 'package:yemekhane/tema.dart';

TemaRengi renkBul(String kimlik) =>
    temaRenkleri.firstWhere((r) => r.kimlik == kimlik);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('varsayılan: sistem modu ve turuncu (uygulamanın ilk rengi)', () async {
    final ayar = TemaAyari();
    await ayar.yukle();
    expect(ayar.mod, ThemeMode.system);
    expect(ayar.renk.kimlik, 'turuncu');
    expect(ayar.renk.renk, const Color(0xFFE8892B));
  });

  test('renk kimlikleri benzersiz ve en az beş seçenek var', () {
    final kimlikler = temaRenkleri.map((r) => r.kimlik).toSet();
    expect(kimlikler.length, temaRenkleri.length);
    expect(temaRenkleri.length, greaterThanOrEqualTo(5));
  });

  test('seçim kaydedilir ve yeni örnek aynı seçimi yükler', () async {
    final a = TemaAyari();
    await a.modSec(ThemeMode.dark);
    await a.renkSec(renkBul('mavi'));
    final b = TemaAyari();
    await b.yukle();
    expect(b.mod, ThemeMode.dark);
    expect(b.renk.kimlik, 'mavi');
  });

  test('tanınmayan kayıtlı değerler varsayılana düşer', () async {
    SharedPreferences.setMockInitialValues(
        {TemaAyari.modAnahtari: 'garip', TemaAyari.renkAnahtari: 'yok'});
    final ayar = TemaAyari();
    await ayar.yukle();
    expect(ayar.mod, ThemeMode.system);
    expect(ayar.renk.kimlik, 'turuncu');
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
    await ayar.renkSec(renkBul('mor'));
    expect(sayac, 2);
  });

  test('renk değişince renk şeması ve parlaklık buna göre üretilir', () async {
    final ayar = TemaAyari();
    final turuncu = ayar.tema(Brightness.light).colorScheme.primary;
    await ayar.renkSec(renkBul('mavi'));
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

    await tester.tap(find.byTooltip('Yeşil'));
    await tester.pump();
    expect(ayar.renk.kimlik, 'yesil');
    // seçili rengin üzerinde onay işareti görünür
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
