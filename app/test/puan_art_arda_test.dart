// P5 madde 4: yorum bölümündeki (GeriBildirimBolumu) puan kartı, kayıt sürerken gelen yeni dokunuşları yok sayar
// (yemek ayrıntısındaki puan kartı gibi). Eskiden art arda hızlı dokunuşta iki istek yarışıyordu: ilk istek
// başarısız olunca puan, kaydedilmemiş bir değere (ikinci dokunuşun "önceki"sine) dönüyordu.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';

/// puanVer her çağrıda yeni bir kapı açar ve o kapı bırakılana dek bekler; kapı hatayla bırakılırsa istek de hata
/// verir. Başarıyla biterse puan yerel depoya yazılır. İstekler [istekler]e (yıldız) sırayla eklenir.
class _KapiliDepo extends YerelDepo {
  final List<int> istekler = [];
  final List<Completer<void>> kapilar = [];

  @override
  Future<void> puanVer(String slot, int yildiz) async {
    istekler.add(yildiz);
    final kapi = Completer<void>();
    kapilar.add(kapi);
    await kapi.future;
    return super.puanVer(slot, yildiz);
  }
}

Widget _sayfa(GeriBildirimDeposu depo) => MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child: GeriBildirimBolumu(depo: depo, slot: 's1'))));

String _puan(int n) => 'Puanın: $n / 5 (değiştirmek için dokun)';
const _kaydedilemedi = 'Puan kaydedilemedi. İnternet bağlantını kontrol et.';

void main() {
  // cihazda 2 yıldızlık (tek oylu) bir puan var
  setUp(() =>
      SharedPreferences.setMockInitialValues({'yorum_adi': 'Ali', 'yp/s1': 2}));

  testWidgets(
      'kayıt sürerken ikinci dokunuş yok sayılır: tek istek gider, ilk dokunuşun puanı kalır',
      (t) async {
    final depo = _KapiliDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();
    expect(find.text(_puan(2)), findsOneWidget);

    await t.tap(find.byTooltip('5 yıldız'));
    await t.pump();
    expect(find.text(_puan(5)), findsOneWidget, reason: 'puan hemen görünür');
    await t.tap(find.byTooltip('1 yıldız')); // kayıt sürerken ikinci dokunuş
    await t.pump();
    expect(depo.istekler, [5], reason: 'ikinci dokunuş istek açmamalı');
    expect(find.text(_puan(5)), findsOneWidget,
        reason: 'ikinci dokunuş görünen puanı değiştirmemeli');

    depo.kapilar.single.complete();
    await t.pumpAndSettle();
    expect(depo.istekler, [5]);
    expect(find.text(_puan(5)), findsOneWidget);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('yp/s1'), 5);
    expect(find.byType(SnackBar), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'ilk kayıt başarısız olursa puan ilk dokunuştan önceki değere döner, hata bir kez bildirilir',
      (t) async {
    final depo = _KapiliDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('5 yıldız'));
    await t.pump();
    await t.tap(find.byTooltip('1 yıldız')); // yok sayılır
    await t.pump();
    expect(depo.istekler, [5]);

    depo.kapilar.single.completeError(Exception('ağ yok'));
    await t.pumpAndSettle();
    expect(find.text(_kaydedilemedi), findsOneWidget);
    expect(find.text(_puan(2)), findsOneWidget,
        reason: 'kayıtlı puan 2 idi; kaydedilmemiş 5 ya da 1 görünmemeli');
    expect(find.text(_puan(5)), findsNothing);
    expect(find.text(_puan(1)), findsNothing);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('yp/s1'), 2);
    expect(t.takeException(), isNull);
  });

  testWidgets('kayıt bitince yeni puan verilebilir (koruma kalıcı değildir)',
      (t) async {
    final depo = _KapiliDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('5 yıldız'));
    await t.pump();
    depo.kapilar[0].complete();
    await t.pumpAndSettle();
    expect(find.text(_puan(5)), findsOneWidget);

    await t.tap(find.byTooltip('3 yıldız'));
    await t.pump();
    expect(depo.istekler, [5, 3],
        reason: 'ilk kayıt bitti: ikinci istek gider');
    depo.kapilar[1].complete();
    await t.pumpAndSettle();
    expect(find.text(_puan(3)), findsOneWidget);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('yp/s1'), 3);
  });

  testWidgets(
      'başarısız kayıttan sonra yeniden denenebilir (koruma hata yolunda da kalkar)',
      (t) async {
    final depo = _KapiliDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('4 yıldız'));
    await t.pump();
    depo.kapilar[0].completeError(Exception('ağ yok'));
    await t.pumpAndSettle();
    expect(find.text(_kaydedilemedi), findsOneWidget);

    await t.tap(find.byTooltip('4 yıldız'));
    await t.pump();
    expect(depo.istekler, [4, 4], reason: 'hata sonrası dokunuş yok sayılmaz');
    depo.kapilar[1].complete();
    await t.pumpAndSettle();
    expect(find.text(_puan(4)), findsOneWidget);
  });

  testWidgets(
      'kayıt sürerken sayfa kapanırsa ve istek sonra biterse istisna sızmaz',
      (t) async {
    final depo = _KapiliDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('5 yıldız'));
    await t.pump();
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    depo.kapilar.single.complete(); // bölüm yok edilmiş durumda
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
