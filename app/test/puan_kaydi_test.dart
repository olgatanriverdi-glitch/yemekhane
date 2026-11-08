// P4 ek testleri: yorum bölümünde puan kaydı. Puan kaydedildiyse özet okunamasa da "kaydedilemedi" denmez ve puan
// geri alınmaz (yemek ayrıntısındaki puan kartı gibi). Sayfa kapandıktan sonra biten isteklerin hatası (puan,
// silme) ve başarısı (yorum) istisna sızdırmaz. Yorum gönderiminin hata yolları yorum_hata_test.dart'ta.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';

/// puanVer başarılı; puanOzeti sayfa yüklenirken (ilk çağrı) çalışır, sonrakilerde ağ hatası verir.
class _OzetiOkunamayanDepo extends YerelDepo {
  int ozetCagri = 0;
  @override
  Future<PuanOzeti> puanOzeti(String slot) async {
    ozetCagri++;
    if (ozetCagri >= 2) throw Exception('ağ koptu');
    return super.puanOzeti(slot);
  }
}

/// Puan kaydı hata verir.
class _PuanVermeyenDepo extends YerelDepo {
  @override
  Future<void> puanVer(String slot, int yildiz) async =>
      throw Exception('ağ yok');
}

/// puanVer ve yorumSil, dışarıdan bırakılana dek bekler, sonra hata verir.
class _YavasHataliDepo extends YerelDepo {
  final kapi = Completer<void>();
  @override
  Future<void> puanVer(String slot, int yildiz) async {
    await kapi.future;
    throw Exception('ağ yok');
  }

  @override
  Future<void> yorumSil(Yorum y) async {
    await kapi.future;
    throw Exception('ağ yok');
  }
}

/// yorumEkle dışarıdan bırakılana dek bekler, sonra BAŞARIYLA biter.
class _YavasBasariliDepo extends YerelDepo {
  final kapi = Completer<void>();
  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async {
    await kapi.future;
    return super.yorumEkle(slot, ad, metin);
  }
}

/// Yorum eklenir ama sonraki liste isteği (2. yorumlar çağrısı) hata verir.
class _ListeYenilenemeyenDepo extends YerelDepo {
  int yorumlarCagri = 0;
  @override
  Future<List<Yorum>> yorumlar(String slot) async {
    yorumlarCagri++;
    if (yorumlarCagri >= 2) throw Exception('ağ koptu');
    return super.yorumlar(slot);
  }
}

/// Yorum eklemek hata verir.
class _YorumEklemeyenDepo extends YerelDepo {
  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async =>
      throw Exception('ağ yok');
}

Widget _sayfa(GeriBildirimDeposu depo, {bool puanGoster = true}) => MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child: GeriBildirimBolumu(
                depo: depo, slot: 's1', puanGoster: puanGoster))));

Widget _bos() => const MaterialApp(home: Scaffold(body: SizedBox()));

/// Cihazda 2 yıldızlık (tek oylu) bir puan ve kayıtlı takma ad olan başlangıç durumu.
void _ikiYildizli() => SharedPreferences.setMockInitialValues({
      'yorum_adi': 'Ali',
      'topluluk_kurallari_surum': 1,
      'yp/s1': 2,
    });

const _sabit = 'Puanın: 2 / 5 (değiştirmek için dokun)';
const _bes = 'Puanın: 5 / 5 (değiştirmek için dokun)';
const _kaydedilemedi = 'Puan kaydedilemedi. İnternet bağlantını kontrol et.';

void main() {
  setUp(_ikiYildizli);

  group('puan kaydı', () {
    testWidgets(
        'puan kaydedildi ama özet okunamadı: seçilen puan kalır, ortalama eskisi gibi görünür, hata bildirimi çıkmaz',
        (t) async {
      final depo = _OzetiOkunamayanDepo();
      await t.pumpWidget(_sayfa(depo));
      await t.pumpAndSettle();
      expect(find.text('2.0 · 1 oy'), findsOneWidget);
      expect(find.text(_sabit), findsOneWidget);

      await t.tap(find.byTooltip('5 yıldız'));
      await t.pumpAndSettle();
      expect(depo.ozetCagri, 2, reason: 'özet gerçekten istendi ve hata verdi');
      expect(find.text(_bes), findsOneWidget,
          reason: 'puan kaydedildi: geri alınmamalı');
      expect(find.text('2.0 · 1 oy'), findsOneWidget,
          reason: 'özet okunamadı: yalnızca eski ortalama kalır');
      expect(find.textContaining('kaydedilemedi'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('yp/s1'), 5, reason: 'puan gerçekten kaydedildi');
      expect(t.takeException(), isNull);
    });

    testWidgets('özet okunabilirse ortalama güncellenir', (t) async {
      await t.pumpWidget(_sayfa(YerelDepo()));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('5 yıldız'));
      await t.pumpAndSettle();
      expect(find.text(_bes), findsOneWidget);
      expect(find.text('5.0 · 1 oy'), findsOneWidget);
      expect(find.text('2.0 · 1 oy'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'puan kaydedilemezse puan eski haline döner ve hata bildirilir (eski davranış)',
        (t) async {
      await t.pumpWidget(_sayfa(_PuanVermeyenDepo()));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('5 yıldız'));
      await t.pumpAndSettle();
      expect(find.text(_kaydedilemedi), findsOneWidget);
      expect(find.text(_sabit), findsOneWidget,
          reason: 'kayıt başarısız: önceki puan geri gelir');
      expect(find.text(_bes), findsNothing);
      expect(find.text('2.0 · 1 oy'), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('yp/s1'), 2);
    });

    testWidgets(
        'puan isteği sürerken sayfa kapanır ve istek sonra hata verirse istisna sızmaz',
        (t) async {
      final depo = _YavasHataliDepo();
      await t.pumpWidget(_sayfa(depo));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('4 yıldız'));
      await t.pump();
      await t.pumpWidget(_bos());
      depo.kapi
          .complete(); // istek artık hata ile biter; bölüm yok edilmiş durumda
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('yorum silme', () {
    testWidgets(
        'silme isteği sürerken sayfa kapanır ve istek sonra hata verirse istisna sızmaz',
        (t) async {
      SharedPreferences.setMockInitialValues({
        'yorum_adi': 'Ali',
        'topluluk_kurallari_surum': 1,
        'yy/s1': [
          jsonEncode({
            'id': '1',
            'ad': 'Ali',
            'metin': 'Güzeldi',
            'zaman': DateTime.now().toIso8601String()
          })
        ],
      });
      final depo = _YavasHataliDepo();
      await t.pumpWidget(_sayfa(depo, puanGoster: false));
      await t.pumpAndSettle();
      expect(find.text('Güzeldi'), findsOneWidget);
      await t.tap(find.byTooltip('Sil'));
      await t.pump();
      await t.pumpWidget(_bos());
      depo.kapi.complete();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('yorum gönderimi (ek durumlar)', () {
    testWidgets(
        'yorum kaydedildi ama liste yenilenemedi: metin temizlenir, kullanıcıya doğru bilgi verilir',
        (t) async {
      final depo = _ListeYenilenemeyenDepo();
      await t.pumpWidget(_sayfa(depo, puanGoster: false));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Çok güzeldi');
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();
      expect(depo.yorumlarCagri, 2,
          reason: 'liste gerçekten yenilenmeye çalışıldı');
      expect(find.text('Yorumun gönderildi, liste şimdilik yenilenemedi.'),
          findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '',
          reason: 'yorum gönderildi: metin alanı boşalır');
      final gonder = t.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded));
      expect(gonder.onPressed, isNotNull, reason: 'gönderim bitti');
      final p = await SharedPreferences.getInstance();
      expect(p.getStringList('yy/s1'), hasLength(1));
    });

    testWidgets(
        'yorum eklenemezse metin alanında kalır ve eski hata metni çıkar (eski davranış)',
        (t) async {
      await t.pumpWidget(_sayfa(_YorumEklemeyenDepo(), puanGoster: false));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Çok güzeldi');
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();
      expect(find.text('Yorum gönderilemedi. Daha sonra tekrar dene.'),
          findsOneWidget);
      expect(find.textContaining('Yorumun gönderildi'), findsNothing);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
          'Çok güzeldi',
          reason: 'kullanıcı yeniden yazmak zorunda kalmasın');
      final gonder = t.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send_rounded));
      expect(gonder.onPressed, isNotNull, reason: 'yeniden denenebilir');
    });

    testWidgets(
        'gönderim sürerken sayfa kapanır ve istek başarıyla biterse istisna sızmaz',
        (t) async {
      final depo = _YavasBasariliDepo();
      await t.pumpWidget(_sayfa(depo, puanGoster: false));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Merhaba');
      await t.tap(find.byTooltip('Gönder'));
      await t.pump();
      await t.pumpWidget(_bos());
      depo.kapi
          .complete(); // kapanmış sayfanın metin denetleyicisine dokunulmamalı
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final p = await SharedPreferences.getInstance();
      expect(p.getStringList('yy/s1'), hasLength(1),
          reason: 'yorum yine de kaydedildi');
    });
  });
}
