import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/arama.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/screens/university_picker.dart';

Universite _uni(String id, String ad) => Universite(
    id: id,
    ad: ad,
    kisa: id,
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('trKarsilastir', () {
    test('Türkçe alfabe sırası: ç, ğ, ı, ö, ş, ü kendi yerinde', () {
      final liste = [
        'Zonguldak',
        'Şanlıurfa',
        'Sakarya',
        'İzmir',
        'Isparta',
        'Çanakkale',
        'Ankara',
        'Ürgüp',
        'Uşak',
        'Ömer',
        'Ordu',
        'Ege',
        'Eskişehir',
        'Çukurova',
        'Cumhuriyet',
        'Gaziantep',
        'Gazi',
        'Bursa',
        'Ağrı',
        'Adana',
      ]..sort(trKarsilastir);
      expect(liste, [
        'Adana',
        'Ağrı',
        'Ankara',
        'Bursa',
        'Cumhuriyet',
        'Çanakkale',
        'Çukurova',
        'Ege',
        'Eskişehir',
        'Gazi',
        'Gaziantep',
        'Isparta', // ı, i'den önce gelir
        'İzmir',
        'Ordu',
        'Ömer',
        'Sakarya',
        'Şanlıurfa',
        'Uşak',
        'Ürgüp',
        'Zonguldak',
      ]);
    });

    test('ğ, g ile h arasındadır; ı, h ile i arasındadır', () {
      expect(trKarsilastir('gz', 'ğa'), lessThan(0));
      expect(trKarsilastir('ğz', 'ha'), lessThan(0));
      expect(trKarsilastir('ha', 'ıa'), lessThan(0));
      expect(trKarsilastir('ıa', 'ia'), lessThan(0));
    });

    test('büyük / küçük harf ve İ / I farkı yok sayılır', () {
      expect(trKarsilastir('ANKARA', 'ankara'), 0);
      expect(trKarsilastir('IŞIK', 'ışık'), 0);
      expect(trKarsilastir('İstanbul', 'istanbul'), 0);
      expect(trKarsilastir('Çorum', 'çorum'), 0);
    });

    test('işaret: küçük -, büyük +, eşit 0; ortak başlangıçta kısa önce', () {
      expect(trKarsilastir('a', 'b'), lessThan(0));
      expect(trKarsilastir('b', 'a'), greaterThan(0));
      expect(trKarsilastir('abc', 'ab'), greaterThan(0));
      expect(trKarsilastir('ab', 'abc'), lessThan(0));
      expect(trKarsilastir('', 'a'), lessThan(0));
      expect(trKarsilastir('', ''), 0);
    });

    test('alfabede olmayan karakterler (rakam, q, w, x) harflerden sonra gelir',
        () {
      expect(trKarsilastir('zeki', 'qasim'), lessThan(0));
      expect(trKarsilastir('ab', 'a1'), lessThan(0));
      expect(trKarsilastir('x', 'z'), greaterThan(0));
    });

    test('okul seçici ve arama aynı fonksiyonla sıralar; kopya kalmadı', () {
      for (final dosya in [
        'lib/arama.dart',
        'lib/screens/university_picker.dart'
      ]) {
        final kaynak = File(dosya).readAsStringSync();
        expect(kaynak, isNot(contains('_trKarsilastir')),
            reason: '$dosya özel kopya içermemeli');
        expect(kaynak, isNot(contains('_trSira')),
            reason: '$dosya özel alfabe tablosu içermemeli');
        expect(kaynak, contains('trKarsilastir('), reason: dosya);
      }
    });
  });

  testWidgets('okul seçici: okullar Türkçe alfabe sırasıyla (Ç, C\'den sonra)',
      (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: UniversitePicker(uniler: [
      _uni('c', 'Çukurova Üniversitesi'),
      _uni('i', 'İnönü Üniversitesi'),
      _uni('s', 'Sakarya Üniversitesi'),
      _uni('a', 'Adnan Menderes Üniversitesi'),
      _uni('u', 'Uludağ Üniversitesi'),
      _uni('ci', 'Cumhuriyet Üniversitesi'),
    ])));
    final adlar = [
      for (final w in t.widgetList<ListTile>(find.byType(ListTile)))
        (w.title as Text).data!
    ];
    // aynı şehir başlığı altında tek grup: Türkçe alfabetik
    expect(adlar, [
      'Adnan Menderes Üniversitesi',
      'Cumhuriyet Üniversitesi',
      'Çukurova Üniversitesi',
      'İnönü Üniversitesi',
      'Sakarya Üniversitesi',
      'Uludağ Üniversitesi',
    ]);
  });

  test('yemekAra: aynı gün ve öğünde okullar Türkçe alfabetik sıralanır', () {
    Menu menu(String id) => Menu(id, null, {
          '2026-11-02': {
            'lunch': Ogun([YemekOgesi('Mercimek Çorbası', 120)], 120)
          }
        });
    final cukurova = _uni('c', 'Çukurova Üniversitesi');
    final cumhuriyet = _uni('ci', 'Cumhuriyet Üniversitesi');
    final izmir = _uni('i', 'İzmir Üniversitesi');
    final isparta = _uni('p', 'Isparta Üniversitesi');
    final sonuc = yemekAra({
      izmir: menu('i'),
      cukurova: menu('c'),
      isparta: menu('p'),
      cumhuriyet: menu('ci'),
    }, 'corba', '2026-11-02');
    expect([
      for (final s in sonuc) s.okul.ad
    ], [
      'Cumhuriyet Üniversitesi',
      'Çukurova Üniversitesi',
      'Isparta Üniversitesi', // ı
      'İzmir Üniversitesi', // i
    ]);
  });
}
