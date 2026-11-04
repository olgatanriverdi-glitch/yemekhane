import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/okul_basligi.dart';
import 'package:yemekhane/widgets/son_guncelleme.dart';

/// home.dart'tan ayrılan küçük parçalar (okul başlığı, "Son güncelleme" notu): görünümleri ve ana sayfaya
/// bağlanışları bölmeden önceki gibi kalmalı.
class _SahteDepo extends Depo {
  final Universite uni;
  final Menu menuVeri;
  _SahteDepo(this.uni, this.menuVeri);

  @override
  Future<List<Universite>> universiteler() async => [uni];
  @override
  Future<Menu> menu(String universiteId) async => menuVeri;
  @override
  Future<String?> seciliUniversite() async => uni.id;
  @override
  Future<void> universiteSec(String id) async {}
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  String? fotoUrl(String universiteId, String? foto) => null;
  @override
  String? yemekFotoUrl(String? img) => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SonGuncelleme', () {
    Future<void> goster(WidgetTester t,
            {required bool cevrimdisi, required bool eskimis}) =>
        t.pumpWidget(MaterialApp(
            home: Scaffold(
                body: SonGuncelleme(
                    zaman: DateTime(2026, 10, 31, 8, 5),
                    cevrimdisi: cevrimdisi,
                    eskimis: eskimis))));

    testWidgets('gün, ay adı ve iki haneli saat:dakika yazar', (t) async {
      await goster(t, cevrimdisi: false, eskimis: false);
      expect(find.text('Son güncelleme: 31 Ekim 08:05'), findsOneWidget);
    });

    testWidgets('çevrimdışı ve güncel olmayan menü notları eklenir', (t) async {
      await goster(t, cevrimdisi: true, eskimis: false);
      expect(
          find.text(
              'Son güncelleme: 31 Ekim 08:05 · Çevrimdışı: son bilinen veri'),
          findsOneWidget);
      await goster(t, cevrimdisi: false, eskimis: true);
      expect(find.text('Son güncelleme: 31 Ekim 08:05 · Menü güncel değil'),
          findsOneWidget);
      await goster(t, cevrimdisi: true, eskimis: true);
      expect(
          find.text('Son güncelleme: 31 Ekim 08:05 · Çevrimdışı: son bilinen '
              'veri · Menü güncel değil'),
          findsOneWidget);
    });

    testWidgets(
        'ana sayfa menünün güncellenme saatini ve durum notlarını yazar',
        (t) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final uni = Universite(
          id: 'ankara',
          ad: 'Ankara Üniversitesi',
          kisa: 'AÜ',
          sehir: 'Ankara',
          kaynak: '',
          ogunler: const ['lunch'],
          fiyatlar: const [],
          eskimis: true);
      final menu = Menu('ankara', DateTime(2026, 11, 2, 8, 5), {
        '2026-11-02': {
          'lunch': Ogun([YemekOgesi('Mercimek Çorbası', 120)], 120)
        },
      });
      final depo = _SahteDepo(uni, menu)..cevrimdisi = true;
      final ayar = TemaAyari();
      await t.pumpWidget(MaterialApp(
        theme: ayar.tema(Brightness.light),
        home: AnaSayfa(
            temaAyari: ayar,
            depo: depo,
            geriBildirim: YerelDepo(),
            simdi: () => DateTime.utc(2026, 11, 2, 10, 0)),
      ));
      await t.pumpAndSettle();
      expect(
          find.text('Son güncelleme: 2 Kasım 08:05 · Çevrimdışı: son bilinen '
              'veri · Menü güncel değil'),
          findsOneWidget);
    });
  });

  group('OkulBasligi', () {
    testWidgets('ad ve açılır ok görünür; dokununca sec çağrılır', (t) async {
      var sayi = 0;
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: OkulBasligi(ad: 'Gazi Üniversitesi', sec: () => sayi++))));
      expect(find.text('Gazi Üniversitesi'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      await t.tap(find.text('Gazi Üniversitesi'));
      expect(sayi, 1);
    });

    testWidgets('sec boşsa dokunmak bir şey yapmaz', (t) async {
      await t.pumpWidget(const MaterialApp(
          home:
              Scaffold(body: OkulBasligi(ad: 'Gazi Üniversitesi', sec: null))));
      await t.tap(find.text('Gazi Üniversitesi'));
      expect(t.takeException(), isNull);
    });

    testWidgets('dar yerde uzun ad tek satırda kısaltılır, taşma olmaz',
        (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: w!),
        home: Scaffold(
            appBar: AppBar(
                title: const OkulBasligi(
                    ad: 'Ankara Hacı Bayram Veli Sağlık Bilimleri ve Teknoloji Üniversitesi',
                    sec: null),
                actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.favorite)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
            ])),
      ));
      expect(t.takeException(), isNull);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });
  });
}
