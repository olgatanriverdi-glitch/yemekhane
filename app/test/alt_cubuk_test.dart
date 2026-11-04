// Bulgu 6: Android 15+ (targetSdk 36) kenardan kenara çizim. Gezinme çubuğu alt 48 dp'yi kaplarken
// hiçbir içerik bu bölgeye girmemeli. MediaQuery benzetimi; gerçek cihazda denenmedi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/paylasim.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/university_picker.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/paylasim_sayfasi.dart';
import 'package:yemekhane/widgets/son_guncelleme.dart';

const _ekran = Size(400, 900);
const _cubuk = 48.0; // gezinme çubuğu yüksekliği (3 düğmeli gezinme)
const _guvenliAlt = 900.0 - _cubuk;

class _SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> veri;
  _SahteDepo(this.liste, this.veri);
  @override
  Future<List<Universite>> universiteler() async => liste;
  @override
  Future<Menu> menu(String universiteId) async => veri[universiteId]!;
  @override
  Future<String?> seciliUniversite() async => liste.first.id;
  @override
  Future<void> universiteSec(String id) async {}
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  String? fotoUrl(String universiteId, String? foto) => null;
  @override
  String? yemekFotoUrl(String? img) => null;
}

class _SahtePaylasim implements PaylasimServisi {
  @override
  Future<void> paylas(String metin, {String? konu}) async {}
}

Universite _uni(String id, String ad) => Universite(
    id: id,
    ad: ad,
    kisa: id,
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

/// Sistem çubuğu alt 48 dp'yi kaplıyormuş gibi MediaQuery veren uygulama kabuğu.
Widget _kabuk(Widget ana) => MaterialApp(
      theme: TemaAyari().tema(Brightness.light),
      builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: _cubuk),
              viewPadding: const EdgeInsets.only(top: 24, bottom: _cubuk)),
          child: w!),
      home: ana,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'ana sayfa: "Son güncelleme" satırı gezinme çubuğunun üstünde kalır',
      (t) async {
    t.view.physicalSize = _ekran;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final depo = _SahteDepo([
      _uni('a', 'Ankara Üniversitesi')
    ], {
      'a': Menu('a', DateTime(2026, 10, 31, 8, 5), {
        '2026-11-02': {
          'lunch': Ogun([YemekOgesi('Mercimek Çorbası', 120)], 120)
        }
      })
    });
    final ayar = TemaAyari();
    await t.pumpWidget(_kabuk(AnaSayfa(
        temaAyari: ayar,
        depo: depo,
        geriBildirim: YerelDepo(),
        simdi: () => DateTime.utc(2026, 11, 2, 10, 0))));
    await t.pumpAndSettle();
    expect(find.byType(SonGuncelleme), findsOneWidget);
    expect(t.getRect(find.byType(SonGuncelleme)).bottom,
        lessThanOrEqualTo(_guvenliAlt));
  });

  testWidgets(
      'okul seçici: liste sonuna kaydırınca son satır gezinme çubuğuna girmez',
      (t) async {
    t.view.physicalSize = _ekran;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_kabuk(UniversitePicker(
        uniler: [for (var i = 0; i < 40; i++) _uni('u$i', 'Okul $i')])));
    await t.pumpAndSettle();
    // arama kutusunun da bir Scrollable'ı var: listeninkini seç, sonuna atla
    final konum = t
        .state<ScrollableState>(find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first)
        .position;
    // liste ilerledikçe uzunluğunu yeniden hesapladığından sonuna kadar birkaç kez atlanır
    for (var i = 0; i < 5; i++) {
      konum.jumpTo(konum.maxScrollExtent);
      await t.pumpAndSettle();
    }
    final son = find.textContaining('Okulun listede yok mu');
    expect(son, findsOneWidget);
    expect(t.getRect(son).bottom, lessThanOrEqualTo(_guvenliAlt));
  });

  testWidgets('paylaşım alt sayfası: son satır gezinme çubuğuna girmez',
      (t) async {
    t.view.physicalSize = _ekran;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late BuildContext baglam;
    await t.pumpWidget(_kabuk(Scaffold(body: Builder(builder: (c) {
      baglam = c;
      return const SizedBox();
    }))));
    paylasimSayfasiGoster(baglam,
        servis: _SahtePaylasim(),
        uni: _uni('a', 'Ankara Üniversitesi'),
        tarih: '2026-11-02',
        gun: {
          'lunch': Ogun([YemekOgesi('Mercimek Çorbası', 120)], 120)
        },
        ogun: 'lunch');
    await t.pumpAndSettle();
    expect(find.byType(PaylasimSayfasi), findsOneWidget);
    final son = find.widgetWithText(ListTile, 'Panoya kopyala');
    expect(t.getRect(son).bottom, lessThanOrEqualTo(_guvenliAlt));
  });
}
