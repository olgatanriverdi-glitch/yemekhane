import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/screens/university_picker.dart';

Universite _u(String id, String ad, String kisa, String sehir) => Universite(
    id: id,
    ad: ad,
    kisa: kisa,
    sehir: sehir,
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

void main() {
  final uniler = [
    _u('odtu', 'Orta Doğu Teknik Üniversitesi', 'ODTÜ', 'Ankara'),
    _u('itu', 'İstanbul Teknik Üniversitesi', 'İTÜ', 'İstanbul'),
    _u('ege', 'Ege Üniversitesi', 'Ege', 'İzmir'),
    _u('cu', 'Çukurova Üniversitesi', 'ÇÜ', 'Adana'),
  ];

  Future<void> ac(WidgetTester t, {String? secili}) => t.pumpWidget(
      MaterialApp(home: UniversitePicker(uniler: uniler, secili: secili)));

  testWidgets('Türkçe sıralama, seçili okul en üstte', (t) async {
    await ac(t, secili: 'odtu');
    final basliklar = t
        .widgetList<ListTile>(find.byType(ListTile))
        .map((e) => (e.title as Text).data)
        .toList();
    expect(basliklar, [
      'Orta Doğu Teknik Üniversitesi',
      'Çukurova Üniversitesi',
      'Ege Üniversitesi',
      'İstanbul Teknik Üniversitesi',
    ]);
    expect(find.textContaining('Yakında'), findsOneWidget);
  });

  testWidgets('arama: istanbul -> İTÜ, sonuç yoksa mesaj', (t) async {
    await ac(t);
    await t.enterText(find.byType(SearchBar), 'istanbul');
    await t.pump();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('Yakında'), findsNothing);
    await t.enterText(find.byType(SearchBar), 'itü');
    await t.pump();
    expect(find.byType(ListTile), findsOneWidget);
    await t.enterText(find.byType(SearchBar), 'zzz');
    await t.pump();
    expect(find.text('Sonuç bulunamadı'), findsOneWidget);
  });

  test('bozuk gün ve öğe atlanır', () {
    final m = Menu.fromJson({
      'university': 'x',
      'updated': 'bozuk',
      'days': {
        '2026-10-12': {
          'lunch': {
            'items': [
              {'name': 'Çorba'},
              {'kcal': 5},
              'yanlış',
            ]
          },
          'dinner': 'bozuk',
        },
        'tarih-degil': {'lunch': {}},
        '2026-10-13': 'bozuk',
      }
    });
    expect(m.guncellendi, isNull);
    expect(m.gunler['2026-10-12']!['lunch']!.ogeler.length, 1);
    expect(m.gunler['2026-10-12']!.containsKey('dinner'), isFalse);
    expect(m.gunler.containsKey('tarih-degil'), isFalse);
    expect(m.gunler['2026-10-13'], isNull);
  });

  test('turkiyeSimdi UTC+3', () {
    final fark = turkiyeSimdi().difference(DateTime.now().toUtc());
    expect((fark - const Duration(hours: 3)).inSeconds.abs() < 2, isTrue);
  });
}
