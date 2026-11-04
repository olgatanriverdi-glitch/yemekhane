import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/university_picker.dart';
import 'package:yemekhane/tema.dart';

Universite _u(String id, String ad, String kisa, String sehir) => Universite(
    id: id,
    ad: ad,
    kisa: kisa,
    sehir: sehir,
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('yemekIkonu: ad -> simge, Türkçe harf duyarsız', () {
    expect(yemekIkonu('Mercimek Çorbası'), Icons.soup_kitchen);
    expect(yemekIkonu('MERCIMEK CORBASI'), Icons.soup_kitchen);
    expect(yemekIkonu('Sütlaç'), Icons.cake);
    expect(yemekIkonu('Fıstıklı Baklava'), Icons.cake);
    expect(yemekIkonu('Revani'), Icons.cake);
    expect(yemekIkonu('Havuçlu Kek'), Icons.cake);
    expect(yemekIkonu('Kekikli Tavuk'), Icons.restaurant);
    expect(yemekIkonu('Çoban Salata'), Icons.eco);
    expect(yemekIkonu('Pirinç Pilavı'), Icons.rice_bowl);
    expect(yemekIkonu('Makarna'), Icons.rice_bowl);
    expect(yemekIkonu('Bulgur Pilavı'), Icons.rice_bowl);
    expect(yemekIkonu('Ayran'), Icons.local_drink);
    expect(yemekIkonu('Komposto'), Icons.local_drink);
    expect(yemekIkonu('Meyve Suyu'), Icons.local_drink);
    expect(yemekIkonu('Muz'), Icons.apple);
    expect(yemekIkonu('Meyve'), Icons.apple);
    expect(yemekIkonu('Tavuk Sote'), Icons.restaurant);
    expect(yemekIkonu(''), Icons.restaurant);
  });

  for (final parlaklik in Brightness.values) {
    testWidgets(
        'öğün kartı 320x640, yazı 1.5x, uzun adlarla taşmaz ($parlaklik)',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final ogun = Ogun([
        YemekOgesi(
            'Çok Uzun Adlı Kremalı Mantarlı Közlenmiş Patlıcanlı Tavuk Sote Spesiyal Yemeği',
            1234,
            'dishes/a.jpg',
            'abcdef0123'),
        YemekOgesi('Mercimek Çorbası', 120),
        YemekOgesi('Pirinç Pilavı', 300),
      ], 1654);
      await t.pumpWidget(MaterialApp(
        theme: TemaAyari().tema(parlaklik),
        builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: w!),
        home: Scaffold(
          body: OgunKarti(
              ogun: ogun,
              fiyat: 50,
              saat: const ServisSaati('11:30–14:00', true),
              yemekFoto: (_) => null,
              geriBildirim: YerelDepo(),
              slot: 's',
              uniId: 'x'),
        ),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('Toplam 1654 kkal'), findsOneWidget);
      expect(find.text('Öğrenci 50 ₺'), findsOneWidget);
      expect(find.text('Genelde 11:30–14:00'), findsOneWidget);
      expect(find.text('1234 kkal'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  }

  testWidgets('özet: kalori yoksa o satır gösterilmez', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OgunKarti(
            ogun: Ogun([YemekOgesi('Ayran', null)], null),
            yemekFoto: (_) => null,
            geriBildirim: YerelDepo(),
            slot: 's',
            uniId: 'x'),
      ),
    ));
    await t.pump();
    expect(find.textContaining('Toplam'), findsNothing);
    expect(find.textContaining('Öğrenci'), findsNothing);
    expect(find.byIcon(Icons.local_drink), findsOneWidget);
  });

  test('sonSecilenler: en yeni başta, tekrarsız', () async {
    final d = Depo();
    await d.universiteSec('a');
    await d.universiteSec('b');
    await d.universiteSec('a');
    expect(await d.sonSecilenler(), ['a', 'b']);
  });

  group('okul seçici', () {
    final uniler = [
      _u('odtu', 'Orta Doğu Teknik Üniversitesi', 'ODTÜ', 'Ankara'),
      _u('gazi', 'Gazi Üniversitesi', 'Gazi', 'Ankara'),
      _u('itu', 'İstanbul Teknik Üniversitesi', 'İTÜ', 'İstanbul'),
      _u('ege', 'Ege Üniversitesi', 'Ege', 'İzmir'),
    ];

    testWidgets('şehir başlıkları ve son seçilenler; aramada gizlenir',
        (t) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          home: UniversitePicker(
              uniler: uniler,
              secili: 'odtu',
              sonSecilenler: const ['ege', 'odtu', 'itu'])));
      expect(find.text('Son seçilenler'), findsOneWidget);
      expect(find.text('Ankara'), findsWidgets); // başlık + alt başlıklar
      expect(find.byIcon(Icons.location_city_outlined), findsNWidgets(3));
      // ege ve itu hem son seçilenlerde hem şehir grubunda; seçili okul tekrarlanmaz
      expect(find.text('Ege Üniversitesi'), findsNWidgets(2));
      expect(find.text('Orta Doğu Teknik Üniversitesi'), findsOneWidget);

      await t.enterText(find.byType(SearchBar), 'ankara');
      await t.pump();
      expect(find.text('Son seçilenler'), findsNothing);
      expect(find.byIcon(Icons.location_city_outlined), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(2));
    });
  });
}
