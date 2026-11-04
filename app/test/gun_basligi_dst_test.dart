// Bulgu 10: GunBasligi "Yarın" etiketi yaz saati geçişi olan saat dilimlerinde bozuluyordu.
// Bu test saat diliminden bağımsız geçer; hatayı görmek için:
//   TZ=Europe/Berlin flutter test test/gun_basligi_dst_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemekhane/widgets/gun_secici.dart';

Widget _baslik(String secili, String bugun) => MaterialApp(
    home: Scaffold(
        body: GunBasligi(
            tarihler: const ['2026-03-28', '2026-03-29', '2026-03-30'],
            secili: secili,
            bugun: bugun,
            degisti: (_) {})));

void main() {
  testWidgets(
      'yaz saati geçişinden sonraki gün "Yarın" yazar (29 Mart 2026 -> 30 Mart)',
      (t) async {
    await t.pumpWidget(_baslik('2026-03-30', '2026-03-29'));
    expect(find.text('Yarın'), findsOneWidget);
    expect(find.text('Bugün'), findsNothing);
  });

  testWidgets(
      'geçiş gününün kendisi "Bugün", bir önceki gün "Pazar"/gün adı değil Yarın değil',
      (t) async {
    await t.pumpWidget(_baslik('2026-03-29', '2026-03-29'));
    expect(find.text('Bugün'), findsOneWidget);
    await t.pumpWidget(_baslik('2026-03-29', '2026-03-28'));
    expect(find.text('Yarın'), findsOneWidget);
  });
}
