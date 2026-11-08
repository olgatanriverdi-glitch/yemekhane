import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';
import 'package:yemekhane/widgets/gun_secici.dart';
import 'package:yemekhane/widgets/ogun_karti.dart';

Widget sar(ThemeData t, Widget c, {double olcek = 1}) => MaterialApp(
      theme: t,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(olcek)),
        child: Scaffold(body: c),
      ),
    );

const _modlar = [
  (Brightness.light, false),
  (Brightness.dark, false),
  (Brightness.dark, true),
];

void main() {
  testWidgets('GunBasligi: imza simgesi görünür, semantik ağacın dışında',
      (tester) async {
    final palet = temaRengiBul('ask');
    await tester.pumpWidget(sar(
        temaUret(palet, Brightness.light),
        GunBasligi(
            tarihler: const ['2026-11-08', '2026-11-09'],
            secili: '2026-11-08',
            bugun: '2026-11-08',
            degisti: (_) {})));
    final f = find.byKey(const ValueKey('gun-imza'));
    expect(f, findsOneWidget);
    expect(tester.widget<Icon>(f).icon, Icons.favorite_rounded);
    expect(find.ancestor(of: f, matching: find.byType(ExcludeSemantics)),
        findsWidgets);
  });

  testWidgets('GunBasligi 320 px ve 2x yazıda taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final p in temaRenkleri) {
      await tester.pumpWidget(sar(
          temaUret(p, Brightness.light),
          GunBasligi(
              tarihler: const ['2026-11-08', '2026-11-09'],
              secili: '2026-11-09',
              bugun: '2026-11-08',
              degisti: (_) {}),
          olcek: 2));
      expect(tester.takeException(), isNull, reason: p.kimlik);
    }
  });

  testWidgets('YemekYok özel temada degrade zemin kullanır', (tester) async {
    for (final p in temaRenkleri) {
      await tester.pumpWidget(sar(temaUret(p, Brightness.light),
          const YemekYok(baslik: 'Menü yok', alt: 'Alt', ikon: Icons.event)));
      await tester.pumpAndSettle();
      final kap = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .first;
      expect(kap.gradient != null, p.ozel, reason: p.kimlik);
    }
  });

  testWidgets('OgunOzeti özel temada degrade, 320 px ve 2x yazıda taşmaz',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final p in temaRenkleri) {
      await tester.pumpWidget(sar(
          temaUret(p, Brightness.dark),
          const SingleChildScrollView(
              child: OgunOzeti(
                  kcal: 850,
                  fiyat: 45,
                  hedef: 2200,
                  ogleAksamKcal: 1500,
                  saat: ServisSaati('11:30-14:00', false))),
          olcek: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: p.kimlik);
      final d = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.borderRadius == BorderRadius.circular(20));
      expect(d.gradient != null, p.ozel, reason: p.kimlik);
    }
  });

  test('imza yazı rengi, zemin ve degrade uçlarında AA (13 tema x 3 mod)', () {
    for (final p in temaRenkleri) {
      for (final (mod, siyah) in _modlar) {
        final t = temaUret(p, mod, amoled: siyah);
        final imza = t.extension<TemaImzasi>()!;
        final uclar = <Color>[
          imza.zemin,
          ...?imza.degrade?.colors,
        ];
        for (final u in uclar) {
          expect(kontrastOrani(imza.zeminUstu, u), greaterThanOrEqualTo(4.5),
              reason: '${p.kimlik} $mod siyah=$siyah');
        }
      }
    }
  });
}
