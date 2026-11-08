// Yorum bildirme, kişi engelleme ve gönderim süzgeci (Google Play kullanıcı içeriği politikası).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';
import 'package:yemekhane/yorum_moderasyon.dart';

/// "Başkalarının" yorumlarını döndüren yerel depo: kimlik 'ben', yorumları 'u2' ve 'u3' yazmış. Bildirimleri kaydeder.
class _BaskaYorumluDepo extends YerelDepo {
  final bildirilen = <(String, YorumBildirimNedeni)>[];
  final eklenen = <String>[];
  Object? bildirHatasi;

  final List<Yorum> liste = [
    Yorum('c1', 'u2', 'Ayşe', 'Çorba sıcaktı', DateTime(2026, 11, 2, 12),
        slot: 's1'),
    Yorum('c2', 'u3', 'Mehmet', 'Pilav lezzetliydi', DateTime(2026, 11, 2, 11),
        slot: 's1'),
    Yorum('c3', 'u2', 'Ayşe', 'Yarın yine gelirim', DateTime(2026, 11, 2, 10),
        slot: 's1'),
  ];

  @override
  Future<String> kullaniciId() async => 'ben';

  @override
  Future<List<Yorum>> yorumlar(String slot) async => List.of(liste);

  @override
  Future<void> yorumBildir(Yorum y, YorumBildirimNedeni neden) async {
    if (bildirHatasi != null) throw bildirHatasi!;
    bildirilen.add((y.id, neden));
  }

  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async =>
      eklenen.add(metin);
}

Widget _sayfa(GeriBildirimDeposu depo) => MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child: GeriBildirimBolumu(
                depo: depo, slot: 's1', puanGoster: false))));

Future<void> _ac(WidgetTester t, GeriBildirimDeposu depo) async {
  await t.pumpWidget(_sayfa(depo));
  await t.pumpAndSettle();
}

/// [sira]. yorumun "..." menüsünü açar.
Future<void> _menuAc(WidgetTester t, [int sira = 0]) async {
  await t.tap(find.byTooltip('Yorum seçenekleri').at(sira));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {'yorum_adi': 'Ali', 'topluluk_kurallari_surum': 1}));

  group('yorum menüsü', () {
    testWidgets('başkasının yorumunda "..." menüsü, kendi yorumunda Sil',
        (t) async {
      final depo = YerelDepo();
      await depo.yorumEkle('s1', 'Ali', 'Benim yorumum');
      await _ac(t, depo);
      expect(find.byTooltip('Sil'), findsOneWidget);
      expect(find.byTooltip('Yorum seçenekleri'), findsNothing);

      await t.pumpWidget(const SizedBox());
      await _ac(t, _BaskaYorumluDepo());
      expect(find.byTooltip('Yorum seçenekleri'), findsNWidgets(3));
      expect(find.byTooltip('Sil'), findsNothing);
    });

    testWidgets('menüde Bildir ve Bu kişiyi engelle var', (t) async {
      await _ac(t, _BaskaYorumluDepo());
      await _menuAc(t);
      expect(find.text('Bildir'), findsOneWidget);
      expect(find.text('Bu kişiyi engelle'), findsOneWidget);
    });

    testWidgets('menü düğmesi en az 48 dp', (t) async {
      await _ac(t, _BaskaYorumluDepo());
      final boyut = t.getSize(find.byTooltip('Yorum seçenekleri').first);
      expect(boyut.width, greaterThanOrEqualTo(48));
      expect(boyut.height, greaterThanOrEqualTo(48));
    });
  });

  group('bildir', () {
    testWidgets('neden seçenekleri listelenir', (t) async {
      await _ac(t, _BaskaYorumluDepo());
      await _menuAc(t);
      await t.tap(find.text('Bildir'));
      await t.pumpAndSettle();
      for (final e in ['Hakaret / küfür', 'Spam', 'Uygunsuz içerik', 'Diğer']) {
        expect(find.text(e), findsOneWidget);
      }
    });

    testWidgets(
        'başarılı bildirim: depoya iletilir, teşekkür mesajı, yorum bu cihazda gizlenir',
        (t) async {
      final depo = _BaskaYorumluDepo();
      await _ac(t, depo);
      await _menuAc(t); // c1
      await t.tap(find.text('Bildir'));
      await t.pumpAndSettle();
      await t.tap(find.text('Spam'));
      await t.pumpAndSettle();

      expect(depo.bildirilen, [('c1', YorumBildirimNedeni.spam)]);
      expect(find.text('Teşekkürler, bildirimin alındı'), findsOneWidget);
      expect(find.text('Çorba sıcaktı'), findsNothing);
      expect(find.text('Pilav lezzetliydi'), findsOneWidget);
      // yalnızca o yorum: aynı kişinin diğer yorumu kalır
      expect(find.text('Yarın yine gelirim'), findsOneWidget);
      expect(await const YorumModerasyonu().gizlenenYorumlar(), {'c1'});

      // bölüm yeniden kurulunca da gizli kalır
      await t.pumpWidget(const SizedBox());
      await _ac(t, depo);
      expect(find.text('Çorba sıcaktı'), findsNothing);
    });

    testWidgets('neden kodları depoya iletilir', (t) async {
      for (final (etiket, neden) in [
        ('Hakaret / küfür', YorumBildirimNedeni.hakaret),
        ('Uygunsuz içerik', YorumBildirimNedeni.uygunsuz),
        ('Diğer', YorumBildirimNedeni.diger),
      ]) {
        SharedPreferences.setMockInitialValues(
            {'yorum_adi': 'Ali', 'topluluk_kurallari_surum': 1});
        final depo = _BaskaYorumluDepo();
        await t.pumpWidget(const SizedBox());
        await _ac(t, depo);
        await _menuAc(t);
        await t.tap(find.text('Bildir'));
        await t.pumpAndSettle();
        await t.tap(find.text(etiket));
        await t.pumpAndSettle();
        expect(depo.bildirilen.single.$2, neden);
      }
    });

    testWidgets('neden seçilmeden vazgeçilirse bildirim gitmez ve yorum kalır',
        (t) async {
      final depo = _BaskaYorumluDepo();
      await _ac(t, depo);
      await _menuAc(t);
      await t.tap(find.text('Bildir'));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(5, 5)); // diyaloğun dışına dokun
      await t.pumpAndSettle();
      expect(depo.bildirilen, isEmpty);
      expect(find.text('Çorba sıcaktı'), findsOneWidget);
    });

    testWidgets('hata olursa "Bildirim gönderilemedi" ve yorum gizlenmez',
        (t) async {
      final depo = _BaskaYorumluDepo()..bildirHatasi = Exception('403');
      await _ac(t, depo);
      await _menuAc(t);
      await t.tap(find.text('Bildir'));
      await t.pumpAndSettle();
      await t.tap(find.text('Diğer'));
      await t.pumpAndSettle();
      expect(find.text('Bildirim gönderilemedi'), findsOneWidget);
      expect(find.text('Çorba sıcaktı'), findsOneWidget);
      expect(await const YorumModerasyonu().gizlenenYorumlar(), isEmpty);
    });

    testWidgets('YerelDepo.yorumBildir zararsızdır', (t) async {
      final y = Yorum('c', 'u', 'Ad', 'Metin', DateTime(2026, 11, 2));
      await YerelDepo().yorumBildir(y, YorumBildirimNedeni.spam);
    });
  });

  group('engelle', () {
    testWidgets(
        'onaydan sonra o kişinin bütün yorumları görünmez, kalıcı saklanır',
        (t) async {
      final depo = _BaskaYorumluDepo();
      await _ac(t, depo);
      await _menuAc(t); // c1 (u2)
      await t.tap(find.text('Bu kişiyi engelle'));
      await t.pumpAndSettle();
      expect(find.text('Bu kişi engellensin mi?'), findsOneWidget);
      await t.tap(find.text('Engelle'));
      await t.pumpAndSettle();

      expect(find.text('Çorba sıcaktı'), findsNothing);
      expect(find.text('Yarın yine gelirim'), findsNothing); // aynı kişi (u2)
      expect(find.text('Pilav lezzetliydi'), findsOneWidget); // u3 kalır
      expect(await const YorumModerasyonu().engellenenler(), {'u2'});
      // başlıktaki sayı yalnızca görünen yorumları sayar
      expect(find.text('Yorumlar (1)'), findsOneWidget);
    });

    testWidgets('vazgeçilirse kimse engellenmez', (t) async {
      await _ac(t, _BaskaYorumluDepo());
      await _menuAc(t);
      await t.tap(find.text('Bu kişiyi engelle'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(find.text('Çorba sıcaktı'), findsOneWidget);
      expect(await const YorumModerasyonu().engellenenler(), isEmpty);
    });

    testWidgets('önceden engellenenlerin yorumları açılışta görünmez',
        (t) async {
      SharedPreferences.setMockInitialValues({
        'yorum_adi': 'Ali',
        'topluluk_kurallari_surum': 1,
        YorumModerasyonu.engellenenAnahtari: ['u3'],
      });
      await _ac(t, _BaskaYorumluDepo());
      expect(find.text('Pilav lezzetliydi'), findsNothing);
      expect(find.text('Çorba sıcaktı'), findsOneWidget);
    });

    test('moderasyon deposu: tekrar eklenmez, sınırlıdır, temizlenir',
        () async {
      SharedPreferences.setMockInitialValues({});
      const m = YorumModerasyonu();
      await m.engelle('a');
      await m.engelle('a');
      await m.engelle('');
      expect(await m.engellenenler(), {'a'});
      for (var i = 0; i < YorumModerasyonu.enCok + 20; i++) {
        await m.yorumuGizle('y$i');
      }
      final gizli = await m.gizlenenYorumlar();
      expect(gizli.length, YorumModerasyonu.enCok);
      expect(gizli.contains('y${YorumModerasyonu.enCok + 19}'), isTrue);
      expect(gizli.contains('y0'), isFalse); // en eskiler düşer
      await m.engelleriTemizle();
      expect(await m.engellenenler(), isEmpty);
    });
  });

  group('gönderim süzgeci ve kurallar notu', () {
    testWidgets('kurallar notu yorum kutusunun altında görünür', (t) async {
      await _ac(t, _BaskaYorumluDepo());
      expect(
          find.text(
              'Yorumlar herkese açıktır. Hakaret ve kişisel bilgi paylaşma.'),
          findsOneWidget);
    });

    testWidgets('küfürlü yorum gönderilmez', (t) async {
      final depo = _BaskaYorumluDepo();
      await _ac(t, depo);
      await t.enterText(find.byType(TextField), 'siktir git');
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();
      expect(depo.eklenen, isEmpty);
      expect(find.text('Yorumun uygunsuz ifade içeriyor.'), findsOneWidget);
    });

    testWidgets('bağlantılı yorum gönderilmez', (t) async {
      final depo = _BaskaYorumluDepo();
      await _ac(t, depo);
      await t.enterText(find.byType(TextField), 'bak www.ornek.com');
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();
      expect(depo.eklenen, isEmpty);
      expect(find.text('Yorumda bağlantı paylaşılamaz.'), findsOneWidget);
    });

    testWidgets('masum yorum ("sikke", "sık sık") gönderilir', (t) async {
      final depo = _BaskaYorumluDepo();
      await _ac(t, depo);
      await t.enterText(
          find.byType(TextField), 'sikke gibi pilav, sık sık gel');
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();
      expect(depo.eklenen, ['sikke gibi pilav, sık sık gel']);
    });

    testWidgets('uygunsuz takma ad ile yorum gönderilmez ve ad hatırlanmaz',
        (t) async {
      SharedPreferences.setMockInitialValues(
          {'yorum_adi': 'Siktir', 'topluluk_kurallari_surum': 1});
      final depo = _BaskaYorumluDepo();
      await _ac(t, depo);
      await t.enterText(find.byType(TextField), 'Güzeldi');
      await t.tap(find.byTooltip('Gönder'));
      await t.pumpAndSettle();
      expect(depo.eklenen, isEmpty);
      expect(find.text('Takma adın uygun değil. Başka bir ad dene.'),
          findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('yorum_adi'),
          isNull);
    });
  });

  group('taşma ve erişilebilirlik', () {
    for (final olcek in [1.0, 1.5]) {
      testWidgets('320x640, yazı ölçeği $olcek: yorum satırı ve menü taşmaz',
          (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final depo = _BaskaYorumluDepo();
        depo.liste.add(Yorum('c9', 'u9', 'ÇokUzunBirTakmaAdYirmiKr',
            'Çok uzun bir yorum metni ' * 8, DateTime(2026, 11, 2, 9),
            slot: 's1'));
        await t.pumpWidget(MaterialApp(
            builder: (c, w) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(olcek)),
                child: w!),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: GeriBildirimBolumu(
                        depo: depo, slot: 's1', puanGoster: false)))));
        await t.pumpAndSettle();
        await _menuAc(t);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('menü düğmesi kılavuzlardan geçer (dokunma hedefi, etiket)',
        (t) async {
      final anlam = t.ensureSemantics();
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await _ac(t, _BaskaYorumluDepo());
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      anlam.dispose();
    });

    testWidgets('açık menü ve neden diyaloğu etiketli ve 48 dp', (t) async {
      final anlam = t.ensureSemantics();
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await _ac(t, _BaskaYorumluDepo());
      await _menuAc(t);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await t.tap(find.text('Bildir'));
      await t.pumpAndSettle();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      anlam.dispose();
    });
  });
}
