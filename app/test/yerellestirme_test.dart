import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/main.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/tema.dart';

/// Ağa ve diske gitmeyen sahte veri deposu (Ayarlar yalnızca önbellek temizlerken kullanır).
class SahteDepo extends Depo {
  @override
  Future<int> onbellekTemizle() async => 0;
}

/// Uygulamanın gerçek [YemekhaneApp] kabuğunu açar; ana sayfanın yerine [ana] konur (gerçek ağ yok).
Future<void> _uygulamaAc(WidgetTester t, Widget ana, {TemaAyari? ayar}) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(YemekhaneApp(ayar: ayar ?? TemaAyari(), ana: ana));
  await t.pumpAndSettle();
}

/// [YemekhaneApp] içinden yerelleştirme nesnelerini yakalar.
class _Yakala extends StatelessWidget {
  final void Function(BuildContext) yakala;
  const _Yakala(this.yakala);

  @override
  Widget build(BuildContext context) {
    yakala(context);
    return const Scaffold(body: SizedBox());
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Türkçe yerelleştirme', () {
    testWidgets(
        'uygulama yalnızca Türkçe desteklenir ve dil tr olarak sabittir',
        (t) async {
      Locale? dil;
      await _uygulamaAc(t, _Yakala((c) => dil = Localizations.localeOf(c)));
      expect(dil, const Locale('tr'));
      final app = t.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale, const Locale('tr'));
      expect(app.supportedLocales, const [Locale('tr')]);
      expect(app.localizationsDelegates, isNotNull);
      expect(app.localizationsDelegates!.length, 3);
    });

    testWidgets('MaterialLocalizations Türkçe metin döndürür', (t) async {
      late MaterialLocalizations m;
      await _uygulamaAc(t, _Yakala((c) => m = MaterialLocalizations.of(c)));
      expect(m.licensesPageTitle, 'Lisanslar');
      expect(m.viewLicensesButtonLabel, 'Lisansları göster');
      expect(m.backButtonTooltip, 'Geri');
      expect(m.closeButtonTooltip, 'Kapat');
      expect(m.okButtonLabel, 'Tamam');
      expect(m.cancelButtonLabel, 'İptal');
      expect(m.searchFieldLabel, 'Ara');
      expect(m.datePickerHelpText, 'Tarih seçin');
      expect(m.aboutListTileTitle('Üni Yemek'), 'Üni Yemek Hakkında');
      // takvim: Türkçe ay adları, hafta Pazartesi'yle başlar, saat 24'lük
      expect(m.formatMonthYear(DateTime(2026, 11, 2)), 'Kasım 2026');
      expect(m.formatMonthYear(DateTime(2026, 8, 29)), 'Ağustos 2026');
      expect(m.formatFullDate(DateTime(2026, 11, 2)), '2 Kasım 2026 Pazartesi');
      expect(m.firstDayOfWeekIndex, 1);
      expect(m.formatTimeOfDay(const TimeOfDay(hour: 14, minute: 5)), '14:05');
    });

    testWidgets('WidgetsLocalizations ve CupertinoLocalizations de Türkçe',
        (t) async {
      late WidgetsLocalizations w;
      late CupertinoLocalizations cu;
      await _uygulamaAc(t, _Yakala((c) {
        w = WidgetsLocalizations.of(c);
        cu = CupertinoLocalizations.of(c);
      }));
      expect(w.textDirection, TextDirection.ltr);
      expect(cu.alertDialogLabel, 'Uyarı');
      expect(cu.cutButtonLabel, 'Kes');
      expect(cu.copyButtonLabel, 'Kopyala');
    });

    testWidgets('tarih seçici Türkçe: başlık, ay, düğmeler', (t) async {
      await _uygulamaAc(
          t,
          Scaffold(
            body: Builder(
              builder: (c) => Center(
                child: ElevatedButton(
                  onPressed: () => showDatePicker(
                      context: c,
                      initialDate: DateTime(2026, 11, 2),
                      firstDate: DateTime(2026, 10, 1),
                      lastDate: DateTime(2026, 12, 31)),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ));
      await t.tap(find.text('Aç'));
      await t.pumpAndSettle();
      expect(find.text('Tarih seçin'), findsOneWidget);
      expect(find.text('Kasım 2026'), findsOneWidget);
      expect(find.text('Tamam'), findsOneWidget);
      expect(find.text('İptal'), findsOneWidget);
      expect(find.text('Select date'), findsNothing);
      expect(find.text('OK'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('saat seçici Türkçe: düğmeler ve 24 saatlik gösterim',
        (t) async {
      await _uygulamaAc(
          t,
          Scaffold(
            body: Builder(
              builder: (c) => Center(
                child: ElevatedButton(
                  onPressed: () => showTimePicker(
                      context: c,
                      initialTime: const TimeOfDay(hour: 14, minute: 5)),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ));
      await t.tap(find.text('Aç'));
      await t.pumpAndSettle();
      expect(find.text('Tamam'), findsOneWidget);
      expect(find.text('İptal'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('AM'), findsNothing); // 12 saatlik gösterim yok
      expect(find.text('PM'), findsNothing);
    });

    testWidgets('sistem tooltip\'leri Türkçe: açılan sayfada "Geri" düğmesi',
        (t) async {
      await _uygulamaAc(
          t,
          Scaffold(
            body: Builder(
              builder: (c) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
                      builder: (_) => Scaffold(appBar: AppBar()))),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ));
      await t.tap(find.text('Aç'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Geri'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('Ayarlar > Açık kaynak lisansları sayfasının başlığı Türkçe',
        (t) async {
      await _uygulamaAc(
          t,
          AyarlarSayfasi(
              temaAyari: TemaAyari(),
              depo: SahteDepo(),
              uniler: const <Universite>[],
              uni: null,
              menuyuYenile: () async {}));
      await t.scrollUntilVisible(find.text('Açık kaynak lisansları'), 100,
          scrollable: find.byType(Scrollable).first);
      // yeni temada satırlar daha ferah: satırı tamamen görünür yapıp ortasına dokun
      await t.ensureVisible(find.text('Açık kaynak lisansları'));
      await t.pumpAndSettle();
      await t.tap(find.text('Açık kaynak lisansları'));
      await t.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('Lisanslar'), findsOneWidget); // eskiden "Licenses"
      expect(find.text('Licenses'), findsNothing);
      expect(find.text('Üni Yemek'), findsWidgets);
      expect(find.byTooltip('Geri'), findsOneWidget);
    });

    testWidgets('açık / koyu / siyah tema Türkçe kabukta da kurulur',
        (t) async {
      for (final ayar in [
        TemaAyari(mod: ThemeMode.light),
        TemaAyari(mod: ThemeMode.dark),
        TemaAyari(mod: ThemeMode.dark, siyah: true),
      ]) {
        await _uygulamaAc(t, _Yakala((c) {}), ayar: ayar);
        expect(t.takeException(), isNull);
      }
    });
  });

  group('web açılış renkleri', () {
    final acikYuzey =
        _hex(renkSemasiUret(temaRenkleri.first, Brightness.light).surface);
    final koyuYuzey =
        _hex(renkSemasiUret(temaRenkleri.first, Brightness.dark).surface);

    test('Safran temasının yüzey renkleri #F6F3EE (açık) ve #1C170F (koyu)',
        () {
      expect(acikYuzey, '#F6F3EE');
      expect(koyuYuzey, '#1C170F');
    });

    test('index.html: theme-color ve gövde zemini tema yüzeyiyle aynı', () {
      final html = File('web/index.html').readAsStringSync();
      expect(
          html,
          contains(
              '<meta name="theme-color" content="$acikYuzey" media="(prefers-color-scheme: light)">'));
      expect(
          html,
          contains(
              '<meta name="theme-color" content="$koyuYuzey" media="(prefers-color-scheme: dark)">'));
      // gövdenin satır içi (CSS ile ezilemeyen) koyu zemini kalmamalı
      expect(html, isNot(contains('<body style=')));
      expect(html, isNot(contains('#16120d')));
      expect(
          html, contains('html, body { margin: 0; background: $acikYuzey; }'));
      expect(html, contains('(prefers-color-scheme: dark)'));
      expect(html, contains('html, body { background: $koyuYuzey; }'));
    });

    test('manifest.json: background_color açık yüzey, geçerli JSON', () {
      final m = jsonDecode(File('web/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
      expect((m['background_color'] as String).toUpperCase(), acikYuzey);
      expect(m['name'], 'Üni Yemek');
      expect(m['lang'], 'tr');
    });
  });

  group('iOS Info.plist', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    test('geliştirme bölgesi tr', () {
      expect(
          plist,
          matches(RegExp(
              r'<key>CFBundleDevelopmentRegion</key>\s*<string>tr</string>')));
      expect(plist, isNot(contains(r'$(DEVELOPMENT_LANGUAGE)')));
    });

    test('CFBundleLocalizations yalnızca tr: sistem arayüzü Türkçe gelir', () {
      expect(
          plist,
          matches(RegExp(
              r'<key>CFBundleLocalizations</key>\s*<array>\s*<string>tr</string>\s*</array>')));
      expect(RegExp('<key>CFBundleLocalizations</key>').allMatches(plist),
          hasLength(1));
    });

    test('görünen ad ve sürüm anahtarları korunmuş', () {
      expect(
          plist,
          matches(RegExp(
              r'<key>CFBundleDisplayName</key>\s*<string>Üni Yemek</string>')));
      expect(plist, contains(r'$(FLUTTER_BUILD_NAME)'));
      expect(plist, contains(r'$(FLUTTER_BUILD_NUMBER)'));
    });
  });

  test('pubspec.yaml: flutter_localizations (SDK) ve Dart >=3.10 alt sınırı',
      () {
    final satirlar = File('pubspec.yaml').readAsLinesSync();
    final i = satirlar.indexWhere((l) => l == '  flutter_localizations:');
    expect(i, greaterThan(0), reason: 'flutter_localizations bağımlılığı');
    expect(satirlar[i + 1], '    sdk: flutter');
    expect(satirlar, contains('  sdk: ">=3.10.0 <4.0.0"'));
  });
}
