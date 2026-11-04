// Bulgu 8: yorum gönderme hata yolları.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';

/// Yorum eklemeyi başarır ama sonraki liste isteği (2. yorumlar çağrısı) hata verir.
class _ListeYenilenemeyenDepo extends YerelDepo {
  int yorumlarCagri = 0;
  @override
  Future<List<Yorum>> yorumlar(String slot) async {
    yorumlarCagri++;
    if (yorumlarCagri >= 2) throw Exception('ağ koptu');
    return super.yorumlar(slot);
  }
}

/// yorumEkle, dışarıdan bırakılana dek bekler, sonra hata verir.
class _YavasHataliDepo extends YerelDepo {
  final kapi = Completer<void>();
  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async {
    await kapi.future;
    throw Exception('ağ yok');
  }
}

Widget _sayfa(GeriBildirimDeposu depo) => MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child: GeriBildirimBolumu(
                depo: depo, slot: 's1', puanGoster: false))));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'yorum_adi': 'Ali'}));

  testWidgets(
      'yorum kaydedildi ama liste yenilenemediyse "gönderilemedi" denmez',
      (t) async {
    final depo = _ListeYenilenemeyenDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Çok güzeldi');
    await t.tap(find.byTooltip('Gönder'));
    await t.pumpAndSettle();
    final p = await SharedPreferences.getInstance();
    expect(p.getStringList('yy/s1'), hasLength(1),
        reason: 'yorum gerçekten kaydedildi');
    expect(find.textContaining('gönderilemedi'), findsNothing,
        reason: 'kullanıcı yorumu tekrar yazıp çift yorum bırakmasın');
  });

  testWidgets(
      'gönderim sürerken sayfa kapanır ve istek sonra hata verirse istisna sızmaz',
      (t) async {
    final depo = _YavasHataliDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Merhaba');
    await t.tap(find.byTooltip('Gönder'));
    await t.pump();
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    depo.kapi
        .complete(); // istek artık hata ile biter; bölüm yok edilmiş durumda
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
