// Ayarlar > Günlük menü bildirimi bölümü: anahtar, izin reddi, saat seçici (Türkçe), taşma ve erişilebilirlik.
// Gerçek eklenti yok: sahte servis çağrıları kaydeder (test/sahte_bildirim.dart).
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/bildirim_ayari.dart';
import 'package:yemekhane/main.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/bildirim_bolumu.dart';

import 'sahte_bildirim.dart';

/// Ağa ve diske gitmeyen sahte veri deposu (Ayarlar yalnızca önbellek temizlerken kullanır).
class _SahteDepo extends Depo {
  @override
  Future<int> onbellekTemizle() async => 0;

  @override
  Future<List<String>> sonSecilenler() async => const [];
}

Universite _ankara() => Universite(
    id: 'ankara',
    ad: 'Ankara Üniversitesi',
    kisa: 'AÜ',
    sehir: 'Ankara',
    kaynak: 'https://sks.ankara.edu.tr/yemek-hizmetleri-2/',
    ogunler: const ['lunch'],
    fiyatlar: const []);

AyarlarSayfasi _sayfa(BildirimAyari? ayar) => AyarlarSayfasi(
    temaAyari: TemaAyari(),
    depo: _SahteDepo(),
    uniler: [_ankara()],
    uni: _ankara(),
    menuyuYenile: () async {},
    bildirim: ayar);

Future<void> _ekran(WidgetTester t, Size boyut) async {
  t.view.physicalSize = boyut;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// Düz MaterialApp içinde Ayarlar (yerelleştirme varsayılan).
Future<void> _ac(WidgetTester t, BildirimAyari? ayar,
    {Size boyut = const Size(400, 900),
    double yaziOlcegi = 1.0,
    ThemeData? tema}) async {
  await _ekran(t, boyut);
  await t.pumpWidget(MaterialApp(
    theme: tema ?? TemaAyari().tema(Brightness.light),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c)
            .copyWith(textScaler: TextScaler.linear(yaziOlcegi)),
        child: w!),
    home: _sayfa(ayar),
  ));
  await t.pumpAndSettle();
}

/// Uygulamanın gerçek kabuğunda (Türkçe yerelleştirme) Ayarlar.
Future<void> _uygulamadaAc(WidgetTester t, BildirimAyari ayar) async {
  await _ekran(t, const Size(400, 900));
  await t.pumpWidget(YemekhaneApp(ayar: TemaAyari(), ana: _sayfa(ayar)));
  await t.pumpAndSettle();
}

Future<BildirimAyari> _ayar(SahteBildirimServisi s,
    {bool acik = false, int saatDk = 630}) async {
  final a = BildirimAyari(servis: s, acik: acik, saatDk: saatDk);
  await a.yukle();
  addTearDown(a.dispose);
  return a;
}

Finder get _anahtar => find.byType(SwitchListTile);
bool _acikMi(WidgetTester t) => t.widget<SwitchListTile>(_anahtar).value;

const _baslik = 'Günlük menü bildirimi';
const _not = 'Bildirim, uygulamayı son açtığın andaki menüyle hazırlanır; '
    'menüyü güncel tutmak için uygulamayı ara sıra aç.';
const _izinMetni =
    'Bildirim izni verilmedi. Bildirim almak için telefonun ayarlarından '
    "Üni Yemek'e izin verip tekrar dene.";

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('görünüm', () {
    testWidgets(
        'varsayılan: anahtar kapalı, açıklama notu görünür, saat satırı yok',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, await _ayar(s));
      expect(find.text(_baslik), findsOneWidget);
      expect(
          find.text('Seçtiğin saatte günün menüsünü bildirir'), findsOneWidget);
      expect(_acikMi(t), isFalse);
      expect(find.text('Bildirim saati'), findsNothing);
      expect(find.text(_not), findsOneWidget);
      expect(find.text(_izinMetni), findsNothing);
      expect(s.cagrilar, isEmpty, reason: 'ekranı açmak servise dokunmaz');
    });

    testWidgets('kayıtlı açık ayar: anahtar açık, saat satırı ve saat görünür',
        (t) async {
      await _ac(
          t, await _ayar(SahteBildirimServisi(), acik: true, saatDk: 495));
      expect(_acikMi(t), isTrue);
      expect(find.text('Bildirim saati'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
    });

    testWidgets('bildirim ayarı verilmezse bölüm hiç gösterilmez', (t) async {
      await _ac(t, null);
      expect(find.text(_baslik), findsNothing);
      expect(find.byType(BildirimAyariBolumu), findsNothing);
      expect(find.text('Önbelleği temizle'), findsOneWidget);
    });

    testWidgets(
        'platform bildirimi desteklemiyorsa (web / masaüstü) bölüm gizlenir',
        (t) async {
      // çerçeve, test gövdesi bitmeden önce geçersiz kılmanın geri alınmasını ister (addTearDown geç kalır)
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await _ac(t, await _ayar(SahteBildirimServisi()));
        expect(find.byType(BildirimAyariBolumu), findsNothing);
        expect(find.text(_baslik), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('açma ve kapama', () {
    testWidgets(
        'anahtarı açınca izin istenir, anahtar açılır, saat satırı çıkar',
        (t) async {
      final s = SahteBildirimServisi();
      final ayar = await _ayar(s);
      await _ac(t, ayar);
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(s.sayi('izin'), 1);
      expect(_acikMi(t), isTrue);
      expect(ayar.acik, isTrue);
      expect(find.text('Bildirim saati'), findsOneWidget);
      expect(find.text('10:30'), findsOneWidget);
      expect(find.text(_izinMetni), findsNothing);
    });

    testWidgets('izin reddedilirse anahtar kapalı kalır ve açıklama görünür',
        (t) async {
      final s = SahteBildirimServisi(izin: false);
      final ayar = await _ayar(s);
      await _ac(t, ayar);
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(s.cagrilar, ['izin']);
      expect(_acikMi(t), isFalse);
      expect(ayar.acik, isFalse);
      expect(find.text(_izinMetni), findsOneWidget);
      expect(find.text('Bildirim saati'), findsNothing);
      expect(find.text(_not), findsOneWidget);
    });

    testWidgets(
        'reddedildikten sonra izin verilip yeniden denenirse açıklama kalkar',
        (t) async {
      final s = SahteBildirimServisi(izin: false);
      final ayar = await _ayar(s);
      await _ac(t, ayar);
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(find.text(_izinMetni), findsOneWidget);
      s.izin = true;
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(_acikMi(t), isTrue);
      expect(find.text(_izinMetni), findsNothing);
      expect(s.sayi('izin'), 2);
    });

    testWidgets('izin isteği hata verirse de anahtar kapalı kalır', (t) async {
      final s = SahteBildirimServisi()..izinHata = true;
      await _ac(t, await _ayar(s));
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(_acikMi(t), isFalse);
      expect(find.text(_izinMetni), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'anahtarı kapatınca bildirimler iptal edilir, saat satırı kalkar',
        (t) async {
      final s = SahteBildirimServisi();
      final ayar = await _ayar(s, acik: true);
      await _ac(t, ayar);
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(_acikMi(t), isFalse);
      expect(ayar.acik, isFalse);
      expect(s.cagrilar, ['iptal']);
      expect(find.text('Bildirim saati'), findsNothing);
    });

    testWidgets('açık ayar kalıcıdır: kapatma kaydedilir', (t) async {
      final ayar = await _ayar(SahteBildirimServisi());
      await _ac(t, ayar);
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect((await SharedPreferences.getInstance()).getBool('bildirim_acik'),
          isTrue);
    });
  });

  group('saat seçici (Türkçe)', () {
    testWidgets('satıra dokununca Türkçe saat seçici açılır; Tamam saati korur',
        (t) async {
      final s = SahteBildirimServisi();
      final ayar = await _ayar(s, acik: true);
      await _uygulamadaAc(t, ayar);
      await t.tap(find.text('Bildirim saati'));
      await t.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.text('Tamam'), findsOneWidget);
      expect(find.text('İptal'), findsOneWidget);
      // seçici 24 saatlik: AM / PM yok
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(ayar.saatDk, 630);
      expect(s.cagrilar, isEmpty);
    });

    testWidgets('İptal saati değiştirmez', (t) async {
      final s = SahteBildirimServisi();
      final ayar = await _ayar(s, acik: true);
      await _uygulamadaAc(t, ayar);
      await t.tap(find.text('Bildirim saati'));
      await t.pumpAndSettle();
      await t.tap(find.text('İptal'));
      await t.pumpAndSettle();
      expect(ayar.saatDk, 630);
      expect(find.text('10:30'), findsOneWidget);
    });

    testWidgets(
        'metin girişiyle saat değişince gösterilir, kaydedilir ve yeniden planlanır',
        (t) async {
      final s = SahteBildirimServisi();
      final ayar = await _ayar(s, acik: true);
      await ayar.durumuBildir(
          _ankara(),
          Menu('ankara', null, {
            '2026-11-03': {
              'lunch': Ogun([YemekOgesi('Mercimek Çorbası', null)], null)
            }
          }),
          const {},
          () => DateTime.utc(2026, 11, 2, 10, 0));
      s.cagrilar.clear();
      await _uygulamadaAc(t, ayar);
      await t.tap(find.text('Bildirim saati'));
      await t.pumpAndSettle();
      // seçici Türkçe: giriş modu düğmesi ve alan etiketleri
      await t.tap(find.byTooltip('Metin giriş moduna geç'));
      await t.pumpAndSettle();
      expect(find.text('Saat'), findsOneWidget);
      expect(find.text('Dakika'), findsOneWidget);
      final alanlar = find.descendant(
          of: find.byType(TimePickerDialog), matching: find.byType(TextField));
      await t.enterText(alanlar.at(0), '8');
      await t.enterText(alanlar.at(1), '45');
      await t.pumpAndSettle();
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      expect(ayar.saatDk, 8 * 60 + 45);
      expect(find.text('08:45'), findsOneWidget);
      expect(
          (await SharedPreferences.getInstance()).getInt('bildirim_saat'), 525);
      expect(s.cagrilar, ['iptal', 'planla']);
      expect(s.sonPlan.single.zaman, DateTime.utc(2026, 11, 3, 8, 45));
    });
  });

  group('taşma', () {
    // Ayarlar kaydırılabilir bir liste: taşma denetimi için pencere içeriğin tamamı görünecek kadar uzatılır
    // (yatay taşma 320 dp genişlikte aranır; kaydırma bölgesinin dışında kalan satırlar kurulmazdı)
    for (final (ad, olcek) in [
      ('320 dp', 1.0),
      ('320 dp, yazı 1.5x', 1.5),
      ('320 dp, yazı 2.0x', 2.0),
    ]) {
      testWidgets('$ad: açık, kapalı ve izin açıklamalı hâl taşmaz', (t) async {
        for (final (acik, izin) in [
          (false, true),
          (true, true),
          (false, false)
        ]) {
          final s = SahteBildirimServisi(izin: izin);
          await _ac(t, await _ayar(s, acik: acik),
              boyut: const Size(320, 3000), yaziOlcegi: olcek);
          if (!izin) {
            await t.tap(_anahtar);
            await t.pumpAndSettle();
            expect(find.text(_izinMetni), findsOneWidget);
          }
          expect(find.text(_not), findsOneWidget);
          expect(t.takeException(), isNull,
              reason: '$ad acik=$acik izin=$izin');
        }
      });
    }

    testWidgets('320x640 ekranda anahtar kaydırınca erişilebilir ve açılır',
        (t) async {
      final s = SahteBildirimServisi();
      await _ac(t, await _ayar(s),
          boyut: const Size(320, 640), yaziOlcegi: 2.0);
      await t.ensureVisible(_anahtar);
      await t.pumpAndSettle();
      await t.tap(_anahtar);
      await t.pumpAndSettle();
      expect(_acikMi(t), isTrue);
      expect(t.takeException(), isNull);
    });
  });

  test(
      'izin açıklaması (error) ve not (onSurfaceVariant) metinleri tüm paletlerde ve modlarda AA (>= 4.5) kontrasta sahip',
      () {
    final ihlaller = <String>[];
    for (final p in temaRenkleri) {
      for (final (parlaklik, siyah) in [
        (Brightness.light, false),
        (Brightness.dark, false),
        (Brightness.dark, true),
      ]) {
        final r = renkSemasiUret(p, parlaklik, amoled: siyah);
        final ad = '${p.kimlik}/${parlaklik.name}${siyah ? '/siyah' : ''}';
        for (final (ne, renk) in [
          ('error', r.error),
          ('onSurfaceVariant', r.onSurfaceVariant),
        ]) {
          final oran = kontrastOrani(renk, r.surface);
          if (oran < 4.5) {
            ihlaller.add('$ad $ne/surface: ${oran.toStringAsFixed(2)}');
          }
        }
      }
    }
    expect(ihlaller, isEmpty, reason: ihlaller.join('\n'));
  });

  group('erişilebilirlik (320 dp)', () {
    final temalar = <String, ThemeData>{
      'açık': TemaAyari().tema(Brightness.light),
      'koyu': TemaAyari().tema(Brightness.dark),
      'siyah': temaUret(temaRenkleri.first, Brightness.dark, amoled: true),
    };
    for (final e in temalar.entries) {
      testWidgets('${e.key} tema: dokunma hedefi, etiket ve metin kontrastı',
          (t) async {
        final h = t.ensureSemantics();
        // saat satırı ve izin açıklaması birlikte görünsün diye: önce izin reddi, sonra açık hâl ayrı denenir
        final reddeden = SahteBildirimServisi(izin: false);
        await _ac(t, await _ayar(reddeden),
            boyut: const Size(320, 1200), tema: e.value);
        await t.tap(_anahtar);
        await t.pumpAndSettle();
        expect(find.text(_izinMetni), findsOneWidget);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));

        await _ac(t, await _ayar(SahteBildirimServisi(), acik: true),
            boyut: const Size(320, 1200), tema: e.value);
        expect(find.text('Bildirim saati'), findsOneWidget);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }

    testWidgets(
        'anahtar ve saat satırı ekran okuyucuya etiketli düğüm olarak gelir',
        (t) async {
      final h = t.ensureSemantics();
      await _ac(t, await _ayar(SahteBildirimServisi(), acik: true));
      final anahtar = t.getSemantics(_anahtar);
      expect(anahtar.label, contains(_baslik));
      expect(anahtar.getSemanticsData().flagsCollection.isToggled,
          Tristate.isTrue);
      final saat =
          t.getSemantics(find.widgetWithText(ListTile, 'Bildirim saati'));
      expect(saat.label, contains('Bildirim saati'));
      expect(saat.label, contains('10:30'));
      expect(saat.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      h.dispose();
    });
  });
}
