// Bulgu 9: yenileme (aşağı çekme / Yenile / 3 saat sonra otomatik) kullanıcının bilerek açtığı boş
// "Vejetaryen" sekmesini değiştirmemeli.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';

class _SahteDepo extends Depo {
  int menuCagri = 0;
  final Universite uni;
  final Menu menuVeri;
  _SahteDepo(this.uni, this.menuVeri);
  @override
  Future<List<Universite>> universiteler() async => [uni];
  @override
  Future<Menu> menu(String universiteId) async {
    menuCagri++;
    return menuVeri;
  }

  @override
  Future<String?> seciliUniversite() async => uni.id;
  @override
  Future<void> universiteSec(String id) async {}
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  String? fotoUrl(String universiteId, String? foto) => null;
  @override
  String? yemekFotoUrl(String? img) => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'boş Vejetaryen sekmesi açıkken aşağı çekip yenilemek sekmeyi değiştirmez',
      (t) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final depo = _SahteDepo(
        Universite(
            id: 'a',
            ad: 'Ankara Üniversitesi',
            kisa: 'a',
            sehir: 'Ankara',
            kaynak: '',
            ogunler: const ['lunch', 'vegetarian'],
            fiyatlar: const []),
        Menu('a', null, {
          '2026-11-02': {
            // o gün vejetaryen menü yayınlanmamış
            'lunch': Ogun([YemekOgesi('Mercimek Çorbası', 120)], 120),
          }
        }));
    final ayar = TemaAyari();
    await t.pumpWidget(MaterialApp(
        theme: ayar.tema(Brightness.light),
        home: AnaSayfa(
            temaAyari: ayar,
            depo: depo,
            geriBildirim: YerelDepo(),
            simdi: () => DateTime.utc(2026, 11, 2, 10, 0))));
    await t.pumpAndSettle();
    expect(find.text('Mercimek Çorbası'), findsOneWidget);

    await t.tap(find.descendant(
        of: find.byType(SegmentedButton<String>),
        matching: find.text('Vejetaryen')));
    await t.pumpAndSettle();
    const oneri = 'Okul bu gün için ayrı bir vejetaryen menü yayınlamadı.';
    expect(find.text(oneri), findsOneWidget);

    final once = depo.menuCagri;
    await t.fling(find.text(oneri), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(depo.menuCagri, greaterThan(once),
        reason: 'yenileme gerçekten çalıştı');
    expect(find.text(oneri), findsOneWidget,
        reason:
            'kullanıcı Vejetaryen sekmesini seçmişti; yenileme onu Öğle\'ye atmamalı');
    expect(find.byType(EtsizOneri), findsOneWidget);
  });
}
