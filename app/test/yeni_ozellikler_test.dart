import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/screens/gun_bilesenleri.dart';
import 'package:yemekhane/screens/university_picker.dart';

Ogun ogun(List<List<Object?>> satirlar) => Ogun(
    [for (final s in satirlar) YemekOgesi(s[0] as String, s[1] as int?)], null);

Universite uni(String id, String ad, String sehir, [String kisa = '']) =>
    Universite(
        id: id,
        ad: ad,
        kisa: kisa,
        sehir: sehir,
        kaynak: '',
        ogunler: const ['lunch'],
        fiyatlar: const []);

void main() {
  test('Türkçe büyük harf: i -> İ, ı -> I', () {
    expect(buyukTr('Bugünün yemeği'), 'BUGÜNÜN YEMEĞİ');
    expect(buyukTr('ışık'), 'IŞIK');
  });

  group('anaYemek', () {
    test('çorba/pilav/tatlı yerine etli yemeği seçer', () {
      final a = anaYemek(ogun([
        ['Mercimek Çorba', 233],
        ['Tavuk Sote', 328],
        ['Pirinç Pilavı', 360],
        ['Sütlaç', 400],
      ]));
      expect(a!.ad, 'Tavuk Sote');
    });

    test('birden çok etli yemekte kalorisi en yüksek olan', () {
      final a = anaYemek(ogun([
        ['Ezogelin Çorba', 230],
        ['Et Döner', 318],
        ['Izgara Tavuk Kanat', 386],
        ['Ayran', 74],
      ]));
      expect(a!.ad, 'Izgara Tavuk Kanat');
    });

    test('pilav üstü et döner pilav sayılmaz', () {
      final a = anaYemek(ogun([
        ['Mercimek Çorba', 100],
        ['Pilav Üstü Et Döner', 500],
        ['Ayran', 74],
      ]));
      expect(a!.ad, 'Pilav Üstü Et Döner');
    });

    test('etsiz menüde yan yemekler dışındaki en yüksek kaloriyi seçer', () {
      final a = anaYemek(ogun([
        ['Domates Çorba', 153],
        ['Zeytinyağlı Brokoli', 136],
        ['Arpa Şehriye Pilavı', 360],
        ['Meyve Suyu', 100],
      ]));
      expect(a!.ad, 'Zeytinyağlı Brokoli');
    });

    test('kalori yoksa ilk aday, öğün boşsa null', () {
      expect(
          anaYemek(ogun([
            ['Brokoli Çorba', null],
            ['Kıymalı Nohut', null],
            ['Pirinç Pilavı', null],
            ['Turşu', null],
          ]))!
              .ad,
          'Kıymalı Nohut');
      expect(anaYemek(Ogun([], null)), isNull);
      // hepsi yan yemekse yine de bir şey seçilir
      expect(
          anaYemek(ogun([
            ['Ayran', 74]
          ]))!
              .ad,
          'Ayran');
    });

    test('gerçek veride her dolu öğünde ana yemek bulunur', () {
      final idx = jsonDecode(File('assets/data/index.json').readAsStringSync())
          as Map<String, dynamic>;
      var sayi = 0;
      for (final e in idx['universities'] as List) {
        final id = (e as Map<String, dynamic>)['id'] as String;
        final menu = Menu.fromJson(
            jsonDecode(File('assets/data/$id/menu.json').readAsStringSync())
                as Map<String, dynamic>);
        for (final gun in menu.gunler.values) {
          for (final o in gun.values) {
            if (o.bos) continue;
            expect(anaYemek(o), isNotNull, reason: id);
            sayi++;
          }
        }
      }
      expect(sayi, greaterThan(100));
    });
  });

  group('şehre göre liste', () {
    test('Türkçe alfabe sırası: ç, ı, i, ş doğru yerde', () {
      final liste = [
        'Şanlıurfa',
        'Isparta',
        'İzmir',
        'Çanakkale',
        'Samsun',
        'Ankara'
      ]..sort(trKarsilastir);
      expect(liste,
          ['Ankara', 'Çanakkale', 'Isparta', 'İzmir', 'Samsun', 'Şanlıurfa']);
    });

    test('şehirler ve okullar sıralı gruplanır, şehri olmayan sona gider', () {
      final g = sehreGoreGrupla([
        uni('b', 'Ege Üniversitesi', 'İzmir'),
        uni('a', 'Hacettepe Üniversitesi', 'Ankara'),
        uni('c', 'Dokuz Eylül Üniversitesi', 'İzmir'),
        uni('d', 'Bilinmeyen', ''),
        uni('e', 'Çanakkale Onsekiz Mart Üniversitesi', 'Çanakkale'),
      ]);
      expect(g.map((e) => e.key), ['Ankara', 'Çanakkale', 'İzmir', 'Diğer']);
      expect(g[2].value.map((u) => u.id), ['c', 'b']);
    });

    test('gerçek veride her okul tam bir grupta', () {
      final idx = jsonDecode(File('assets/data/index.json').readAsStringSync())
          as Map<String, dynamic>;
      final uniler = [
        for (final e in idx['universities'] as List)
          Universite.fromJson(e as Map<String, dynamic>)
      ];
      final g = sehreGoreGrupla(uniler);
      expect(g.fold<int>(0, (t, e) => t + e.value.length), uniler.length);
      expect(g.length, greaterThan(8));
    });
  });

  testWidgets('okul seçici şehir başlıkları gösterir ve aramayla süzer',
      (tester) async {
    final uniler = [
      uni('a', 'Hacettepe Üniversitesi', 'Ankara', 'HÜ'),
      uni('b', 'Ege Üniversitesi', 'İzmir', 'EÜ'),
      uni('c', 'Dokuz Eylül Üniversitesi', 'İzmir', 'DEÜ'),
    ];
    await tester.pumpWidget(
        MaterialApp(home: UniversitePicker(uniler: uniler, secili: 'b')));
    expect(find.text('Ankara · 1'), findsOneWidget);
    expect(find.text('İzmir · 2'), findsOneWidget);
    expect(find.text('Ege Üniversitesi'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'izmir');
    await tester.pump();
    expect(find.text('Ankara · 1'), findsNothing);
    expect(find.text('İzmir · 2'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'yokboyleokul');
    await tester.pump();
    expect(find.text('Aramanla eşleşen üniversite yok.'), findsOneWidget);
  });

  testWidgets('bugünün yemeği kartı ana yemeği ve etiketi gösterir',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      GununYemegiKarti(
        etiket: 'Bugünün yemeği',
        ana: YemekOgesi('Tavuk Sote', 328),
        toplamKcal: 1000,
      )
    ]))));
    expect(find.text('BUGÜNÜN YEMEĞİ'), findsOneWidget);
    expect(find.text('Tavuk Sote'), findsOneWidget);
    expect(find.text('328 kkal'), findsOneWidget);
    expect(find.text('Öğün toplamı 1000 kkal'), findsOneWidget);
  });

  testWidgets('iskelet yükleme ekranı çizilir', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: YuklemeIskeleti())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel('Menü yükleniyor'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
