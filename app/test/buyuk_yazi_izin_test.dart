// F-d: %200 yazı ölçeğinde öğün sekmeleri / servis şeridi küçültülmez; sistemden geri alınan bildirim izni.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/bildirim_ayari.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/widgets/bildirim_bolumu.dart';
import 'package:yemekhane/widgets/ogun_bilgi.dart';
import 'package:yemekhane/widgets/simdi_seridi.dart';

import 'sahte_bildirim.dart';

Future<void> _kur(WidgetTester t, Widget w, double olcek) async {
  t.view.physicalSize = const Size(320, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
      builder: (c, x) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(olcek)),
          child: x!),
      home: Scaffold(body: w)));
  await t.pumpAndSettle();
}

double _yazi(WidgetTester t, Finder f) =>
    t.widget<Text>(f).style?.fontSize ?? 14;

void main() {
  group('öğün seçici %200, 320 dp', () {
    const turler = ['breakfast', 'lunch', 'dinner', 'vegetarian'];

    testWidgets('taşma yok, etiket küçültülmez, kaydırılabilir', (t) async {
      String? secilen;
      await _kur(
          t,
          OgunSecici(
              turler: turler, aktif: 'lunch', degisti: (s) => secilen = s),
          2.0);
      expect(t.takeException(), isNull);
      expect(find.byType(FittedBox), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      for (final a in ogunAdlari.values) {
        final bulunan = find.text(a);
        expect(bulunan, findsOneWidget);
        // metin ölçeği doğrudan uygulanır; FittedBox olmadığından ek küçültme yok
        expect(t.getSize(bulunan).height,
            greaterThanOrEqualTo(_yazi(t, bulunan) * 2 * 0.9),
            reason: a);
      }
      await t.ensureVisible(find.text('Vejetaryen'));
      await t.tap(find.text('Vejetaryen'));
      await t.pump();
      expect(secilen, 'vegetarian');
    });

    testWidgets('normal ölçekte (1.0) eski düzen: FittedBox, kaydırma yok',
        (t) async {
      await _kur(
          t, OgunSecici(turler: turler, aktif: 'lunch', degisti: (_) {}), 1.0);
      expect(find.byType(FittedBox), findsWidgets);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('servis şeridi %200, 320 dp', () {
    testWidgets('metin çok satıra iner, küçültülmez, taşma yok', (t) async {
      const saat = ServisSaati('11:00–14:00', false);
      await _kur(
          t,
          SimdiSeridi(
              ogun: 'lunch',
              saat: saat,
              bugunMu: true,
              simdi: () => DateTime.utc(2026, 11, 2, 10, 35)),
          2.0);
      expect(t.takeException(), isNull);
      expect(find.byType(FittedBox), findsNothing);
      final metin = find.descendant(
          of: find.byType(SimdiSeridi), matching: find.byType(Text));
      expect(metin, findsOneWidget);
      expect(t.widget<Text>(metin).maxLines, isNull);
      // tek satırdan yüksek: alta inmiş
      expect(t.getSize(metin).height, greaterThan(14 * 2 * 1.2 * 1.5));
    });
  });

  group('bildirim izni sistemden geri alınınca', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('izin kapalıysa ayar kapanır, kayıtlı plan iptal edilir', () async {
      final servis = SahteBildirimServisi()..izinDurumu = false;
      var okuma = 0;
      final a = BildirimAyari(
          servis: servis,
          acik: true,
          izinOku: () async {
            okuma++;
            return servis.izinDurumu;
          });
      addTearDown(a.dispose);
      await a.yukle();
      await a.izinDurumunuDenetle();
      expect(okuma, 1);
      expect(a.acik, isFalse);
      expect(a.izinGeriAlindi, isTrue);
      expect(servis.sayi('iptal'), 1);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(BildirimAyari.acikAnahtari), isFalse);
    });

    test('izin açıksa dokunulmaz; kapalı ayarda izin okunmaz', () async {
      final servis = SahteBildirimServisi();
      final a = BildirimAyari(servis: servis, acik: true);
      addTearDown(a.dispose);
      await a.yukle();
      await a.izinDurumunuDenetle();
      expect(a.acik, isTrue);
      expect(a.izinGeriAlindi, isFalse);
      expect(servis.sayi('iptal'), 0);

      final kapali = SahteBildirimServisi();
      final b = BildirimAyari(servis: kapali);
      addTearDown(b.dispose);
      await b.yukle();
      await b.izinDurumunuDenetle();
      expect(kapali.izinOkumaSayisi, 0);
    });

    test('izin geri verilince ayar kendiliğinden açılmaz; anahtarla açılır',
        () async {
      final servis = SahteBildirimServisi()..izinDurumu = false;
      final a = BildirimAyari(servis: servis, acik: true);
      addTearDown(a.dispose);
      await a.yukle();
      await a.izinDurumunuDenetle();
      servis.izinDurumu = true;
      await a.izinDurumunuDenetle();
      expect(a.acik, isFalse);
      expect(await a.ac(), isTrue);
      expect(a.acik, isTrue);
      expect(a.izinGeriAlindi, isFalse);
    });

    testWidgets('Ayarlar açılırken kontrol: anahtar kapalı, açıklama görünür',
        (t) async {
      final servis = SahteBildirimServisi()..izinDurumu = false;
      final a = BildirimAyari(servis: servis, acik: true);
      addTearDown(a.dispose);
      await t.pumpWidget(
          MaterialApp(home: Scaffold(body: BildirimAyariBolumu(ayar: a))));
      await t.pumpAndSettle();
      expect(
          t.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(find.textContaining('telefonun ayarlarından kapatılmış'),
          findsOneWidget);
    });
  });
}
