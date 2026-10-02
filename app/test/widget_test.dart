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
}
