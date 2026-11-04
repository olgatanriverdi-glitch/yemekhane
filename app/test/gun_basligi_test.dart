import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/config.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/gun_secici.dart';

const _bugun = '2026-08-28'; // Cuma

/// Gün çubuğu bu günlerden oluşur; seçili gün [secili].
const _tarihler = [
  '2026-08-28', // Cuma (bugün)
  '2026-08-29', // Cumartesi (yarın)
  '2026-09-26', // Cumartesi
  '2026-09-30', // Çarşamba
  '2026-11-02', // Pazartesi
  '2026-12-31', // Perşembe
];

final _temalar = <String, ThemeData>{
  'açık': TemaAyari().tema(Brightness.light),
  'koyu': TemaAyari().tema(Brightness.dark),
  'siyah': temaUret(temaRenkleri.first, Brightness.dark, amoled: true),
};

String _tarihSatiri(String tarih) {
  final d = DateTime.parse(tarih);
  return '${d.day} ${ayAdlari[d.month - 1]} ${d.year} · ${gunAdlari[d.weekday - 1]}';
}

Future<List<String>> _ac(WidgetTester t, String secili,
    {Size boyut = const Size(320, 640),
    double yaziOlcegi = 1.5,
    ThemeData? tema}) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final secilenler = <String>[];
  await t.pumpWidget(MaterialApp(
    theme: tema ?? TemaAyari().tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c)
            .copyWith(textScaler: TextScaler.linear(yaziOlcegi)),
        child: w!),
    home: Scaffold(
      body: Column(children: [
        GunBasligi(
            tarihler: _tarihler,
            secili: secili,
            bugun: _bugun,
            degisti: secilenler.add),
        const Expanded(child: SizedBox()),
      ]),
    ),
  ));
  return secilenler;
}

/// Bir [Text]in kaç satıra dizildiği: seçim kutularının farklı üst konumlarının sayısı.
int _satirSayisi(WidgetTester t, Finder f) {
  final p = t.renderObject<RenderParagraph>(f);
  final kutular = p.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: p.text.toPlainText().length));
  return {for (final k in kutular) k.top.round()}.length;
}

void main() {
  group('GunBasligi 320x640, yazı 1.5x', () {
    for (final e in _temalar.entries) {
      for (final tarih in _tarihler) {
        testWidgets('$tarih (${e.key} tema): yükseklik <= 100 dp, taşma yok',
            (t) async {
          await _ac(t, tarih, tema: e.value);
          expect(t.takeException(), isNull);
          final boy = t.getSize(find.byType(GunBasligi)).height;
          expect(boy, lessThanOrEqualTo(100), reason: '$tarih: $boy dp');
          // oklar 48 dp'den küçülmez; başlık onlardan fazla yer tutmaz
          expect(boy, greaterThanOrEqualTo(48));
        });
      }
    }

    for (final tarih in _tarihler) {
      testWidgets('$tarih: başlık ve tarih satırı tek satırda kalır (sarmaz)',
          (t) async {
        await _ac(t, tarih);
        final satir = find.text(_tarihSatiri(tarih));
        expect(satir, findsOneWidget);
        expect(_satirSayisi(t, satir), 1);
        // başlık ("Bugün", "Yarın" ya da gün adı) de tek satır
        final baslik = find.descendant(
            of: find.byType(GunBasligi),
            matching: find.byWidgetPredicate((w) =>
                w is Text &&
                w.data != null &&
                w.data != _tarihSatiri(tarih) &&
                w.data!.isNotEmpty));
        expect(baslik, findsOneWidget);
        expect(_satirSayisi(t, baslik), 1);
      });
    }

    testWidgets('en uzun gün adı ve tarih: sığacak kadar küçülür, taşmaz',
        (t) async {
      await _ac(t, '2026-09-26'); // Cumartesi, 26 Eylül 2026 · Cumartesi
      expect(t.takeException(), isNull);
      final kutu = find.descendant(
          of: find.byType(GunBasligi), matching: find.byType(FittedBox));
      expect(kutu, findsNWidgets(2));
      // tarih satırı okların arasındaki alana (320 - 16 - 2*48 = 208 dp) sığar
      final satirKutusu = t.getSize(kutu.last);
      expect(satirKutusu.width, lessThanOrEqualTo(208));
    });
  });

  group('GunBasligi diğer ölçüler', () {
    for (final olcek in [1.0, 2.0]) {
      testWidgets('320x640, yazı ${olcek}x: taşma yok, tek satır', (t) async {
        await _ac(t, '2026-09-26', yaziOlcegi: olcek);
        expect(t.takeException(), isNull);
        expect(_satirSayisi(t, find.text(_tarihSatiri('2026-09-26'))), 1);
        if (olcek == 2.0) {
          // iki kat yazıda bile eskisi gibi 330 dp'yi bulmaz
          expect(t.getSize(find.byType(GunBasligi)).height,
              lessThanOrEqualTo(150));
        }
      });
    }

    testWidgets('390x844, yazı 1.0x (normal görünüm): iki satır, iki ok',
        (t) async {
      await _ac(t, '2026-08-28', boyut: const Size(390, 844), yaziOlcegi: 1.0);
      expect(t.takeException(), isNull);
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text(_tarihSatiri('2026-08-28')), findsOneWidget);
      expect(find.byTooltip('Önceki gün'), findsOneWidget);
      expect(find.byTooltip('Sonraki gün'), findsOneWidget);
      expect(t.getSize(find.byType(GunBasligi)).height, lessThanOrEqualTo(80));
    });

    testWidgets('"Bugün" / "Yarın" / gün adı başlıkları değişmedi', (t) async {
      await _ac(t, '2026-08-28');
      expect(find.text('Bugün'), findsOneWidget);
      await _ac(t, '2026-08-29');
      expect(find.text('Yarın'), findsOneWidget);
      await _ac(t, '2026-09-30');
      expect(find.text('Çarşamba'), findsWidgets); // başlık + tarih satırı
      expect(find.text('30 Eylül 2026 · Çarşamba'), findsOneWidget);
    });
  });

  group('GunBasligi okları', () {
    testWidgets('dokunma hedefleri >= 48 dp ve gün değişir', (t) async {
      final secilenler = await _ac(t, '2026-09-26');
      for (final ipucu in ['Önceki gün', 'Sonraki gün']) {
        final b = t.getSize(find.widgetWithIcon(IconButton,
            ipucu == 'Önceki gün' ? Icons.chevron_left : Icons.chevron_right));
        expect(b.width, greaterThanOrEqualTo(48), reason: ipucu);
        expect(b.height, greaterThanOrEqualTo(48), reason: ipucu);
      }
      await t.tap(find.byTooltip('Sonraki gün'));
      await t.tap(find.byTooltip('Önceki gün'));
      expect(secilenler, ['2026-09-30', '2026-08-29']);
    });

    testWidgets('ilk günde "Önceki", son günde "Sonraki" ok pasif', (t) async {
      await _ac(t, _tarihler.first);
      expect(
          t
              .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.chevron_left))
              .onPressed,
          isNull);
      await _ac(t, _tarihler.last);
      expect(
          t
              .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.chevron_right))
              .onPressed,
          isNull);
    });

    testWidgets('ekran okuyucu: başlık ve tarih metni okunur', (t) async {
      final anlam = t.ensureSemantics();
      await _ac(t, '2026-09-26');
      expect(find.bySemanticsLabel('Cumartesi'), findsOneWidget);
      expect(find.bySemanticsLabel(_tarihSatiri('2026-09-26')), findsOneWidget);
      anlam.dispose();
    });
  });
}
