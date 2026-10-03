import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/models.dart';

void main() {
  test('index.json ve menu.json modele çevrilir', () {
    final idx = jsonDecode(File('assets/data/index.json').readAsStringSync())
        as Map<String, dynamic>;
    final uniler = (idx['universities'] as List)
        .map((e) => Universite.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(uniler.first.id, 'ankara');
    expect(uniler.first.ogrenciFiyati('lunch'), 50);
    expect(uniler.first.ogrenciFiyati('dinner'), 100);

    final menu = Menu.fromJson(
        jsonDecode(File('assets/data/ankara/menu.json').readAsStringSync())
            as Map<String, dynamic>);
    expect(menu.tarihler, isNotEmpty);
    final tarih = menu.tarihler.firstWhere((t) =>
        menu.gunler[t]!['lunch'] != null && !menu.gunler[t]!['lunch']!.bos);
    expect(
        menu.gunler[tarih]!['lunch']!.ogeler.length, greaterThanOrEqualTo(3));
    expect(isoTarih(DateTime(2026, 9, 1)), '2026-09-01');
  });

  test('Gazi: yalnızca öğle + vejetaryen, yemek fotoğrafı yolu okunur', () {
    final idx = jsonDecode(File('assets/data/index.json').readAsStringSync())
        as Map<String, dynamic>;
    final gazi = (idx['universities'] as List)
        .map((e) => Universite.fromJson(e as Map<String, dynamic>))
        .firstWhere((u) => u.id == 'gazi');
    expect(gazi.ogunler, containsAll(['lunch', 'vegetarian']));
    expect(gazi.ogunler.contains('dinner'), isFalse);
    expect(gazi.ogrenciFiyati('lunch'), 50);

    final menu = Menu.fromJson(
        jsonDecode(File('assets/data/gazi/menu.json').readAsStringSync())
            as Map<String, dynamic>);
    final ogeler = menu.gunler[menu.tarihler.first]!['lunch']!.ogeler;
    expect(ogeler.any((o) => o.img != null && o.img!.startsWith('dishes/')),
        isTrue);
  });

  test(
      'Gazi: tatil günleri not olarak gelir, gün listesi hafta sonlarını içerir',
      () {
    final menu = Menu.fromJson(
        jsonDecode(File('assets/data/gazi/menu.json').readAsStringSync())
            as Map<String, dynamic>);
    final tatil = menu.gunler['2026-10-28']!['lunch']!;
    expect(tatil.bos, isTrue);
    expect(tatil.not, 'Tatil');
    final liste = gunListesi(menu, '2026-10-09');
    expect(liste, containsAll(['2026-10-10', '2026-10-11', '2026-10-28']));
    expect(
        menu.gunler.containsKey('2026-10-10'), isFalse); // hafta sonu: menü yok
  });
}
