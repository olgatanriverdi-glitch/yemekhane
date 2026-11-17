// Denetim F-c: gizlilik politikası bağlantısı, reklam tercihi satırı ve rıza değişince ekrandaki reklam.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/config.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/reklam/reklam_karti.dart';
import 'package:yemekhane/reklam/reklam_yoneticisi.dart';
import 'package:yemekhane/reklam/reklam_ayari.dart';
import 'package:yemekhane/reklam/sahte_reklam_servisi.dart';
import 'package:yemekhane/reklam/uzak_ayar.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/tema.dart';

DateTime _sabah() => DateTime.utc(2026, 11, 2, 10, 0);

class _Depo extends Depo {
  @override
  Future<List<Universite>> universiteler() async => [];
  @override
  Future<String?> seciliUniversite() async => null;
  @override
  Future<List<String>> sonSecilenler() async => const [];
}

Widget _ayarlar({
  ReklamYoneticisi? reklam,
  required Future<bool> Function(Uri) ac,
}) =>
    MaterialApp(
      theme: TemaAyari().tema(Brightness.light),
      home: AyarlarSayfasi(
          temaAyari: TemaAyari(),
          depo: _Depo(),
          uniler: const [],
          uni: null,
          reklam: reklam,
          adresAc: ac,
          menuyuYenile: () async {}),
    );

List<String> _panoyuDinle(WidgetTester t) {
  final pano = <String>[];
  t.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (c) async {
    if (c.method == 'Clipboard.setData') {
      pano.add((c.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return pano;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {ilkAcilisAnahtari: '2026-10-20'}));

  group('Gizlilik politikası bağlantısı', () {
    testWidgets('dokununca harici açma çağrılır, panoya kopyalanmaz',
        (t) async {
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final pano = _panoyuDinle(t);
      final acilan = <Uri>[];
      await t.pumpWidget(_ayarlar(ac: (u) async {
        acilan.add(u);
        return true;
      }));
      expect(find.text('Tarayıcıda açar'), findsOneWidget);
      expect(find.text('Adresi panoya kopyalar'), findsNothing);
      await t.tap(find.text('Gizlilik politikası'));
      await t.pumpAndSettle();
      expect(acilan, [Uri.parse(gizlilikAdresi)]);
      expect(pano, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('açılamazsa panoya kopyalanır ve SnackBar çıkar', (t) async {
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final pano = _panoyuDinle(t);
      await t.pumpWidget(_ayarlar(ac: (u) async => false));
      await t.tap(find.text('Gizlilik politikası'));
      await t.pumpAndSettle();
      expect(pano, [gizlilikAdresi]);
      expect(find.text('Bağlantı açılamadı, adres panoya kopyalandı'),
          findsOneWidget);
    });

    testWidgets('açma hata fırlatırsa da panoya kopyalanır', (t) async {
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final pano = _panoyuDinle(t);
      await t.pumpWidget(_ayarlar(ac: (u) async => throw Exception('yok')));
      await t.tap(find.text('Gizlilik politikası'));
      await t.pumpAndSettle();
      expect(pano, [gizlilikAdresi]);
    });
  });

  group('Reklam tercihleri reklam anahtarından bağımsız', () {
    test('uzaktan aktif:false iken de UMP durumuna göre gerekli', () async {
      final s = SahteReklamServisi(tercih: true);
      final y = ReklamYoneticisi(
          servis: s,
          simdi: _sabah,
          ayarGetir: () async => const UzakReklamAyari(aktif: false));
      await y.ayarYukle();
      expect(y.acik, isFalse);
      expect(await y.tercihGerekli(), isTrue);
      y.dispose();
    });

    test('UMP gerektirmiyorsa false; servis kullanılamıyorsa false', () async {
      final y = ReklamYoneticisi(
          servis: SahteReklamServisi(tercih: false), simdi: _sabah);
      expect(await y.tercihGerekli(), isFalse);
      y.dispose();
      final k = ReklamYoneticisi(
          servis: SahteReklamServisi(kullanilabilir: false, tercih: true),
          simdi: _sabah);
      expect(await k.tercihGerekli(), isFalse);
      k.dispose();
    });

    testWidgets('reklamlar kapalıyken Ayarlar\'da Reklam tercihleri görünür',
        (t) async {
      t.view.physicalSize = const Size(400, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final y = ReklamYoneticisi(
          servis: SahteReklamServisi(tercih: true),
          simdi: _sabah,
          ayarGetir: () async => const UzakReklamAyari(aktif: false));
      await y.ayarYukle();
      await t.pumpWidget(_ayarlar(reklam: y, ac: (u) async => true));
      await t.pumpAndSettle();
      expect(find.text('Reklam tercihleri'), findsOneWidget);
      y.dispose();
    });
  });

  group('Rıza değişince ekrandaki reklam', () {
    testWidgets('eski reklam bırakılır, kart yeni rızayla yeniden yüklenir',
        (t) async {
      final s = SahteReklamServisi();
      final y = ReklamYoneticisi(servis: s, simdi: _sabah);
      await t.pumpWidget(MaterialApp(
          theme: TemaAyari().tema(Brightness.light),
          home: Scaffold(
              body: ListView(children: [
            ReklamKarti(anahtar: '2026-11-02|lunch', yonetici: y),
          ]))));
      await t.pump(const Duration(milliseconds: 2100));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('sahte-reklam-1')), findsOneWidget);

      y.tercihDegisti();
      await t.pump();
      expect(find.byKey(const ValueKey('sahte-reklam-1')), findsNothing,
          reason: 'eski rızayla istenen kart ekranda kalmamalı');
      expect(s.yuklenenler.first.kapandi, isTrue);

      await t.pump(const Duration(milliseconds: 2100));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(s.yukleSayisi, 2);
      expect(find.byKey(const ValueKey('sahte-reklam-2')), findsOneWidget);
      y.dispose();
    });

    testWidgets('rıza geri alındıysa kart gizli kalır, yeni istek atılmaz',
        (t) async {
      final s = SahteReklamServisi()..hazirlaSonuclari.addAll([true, false]);
      final y = ReklamYoneticisi(servis: s, simdi: _sabah);
      await t.pumpWidget(MaterialApp(
          theme: TemaAyari().tema(Brightness.light),
          home: Scaffold(
              body: ListView(children: [
            ReklamKarti(anahtar: '2026-11-02|lunch', yonetici: y),
          ]))));
      await t.pump(const Duration(milliseconds: 2100));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('sahte-reklam-1')), findsOneWidget);
      y.tercihDegisti();
      await t.pump(const Duration(milliseconds: 2100));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(s.yukleSayisi, 1);
      expect(find.byKey(const ValueKey('sahte-reklam-1')), findsNothing);
      y.dispose();
    });
  });
}
