// Ana sayfa yükleme hatası metinleri (lib/yukleme_hatasi.dart): boş okul listesi bağlantı hatasından ayrı bir
// mesajla gösterilir. home.dart 450 satır sınırı için taşınan bu mantığın davranışı değişmemelidir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/yukleme_hatasi.dart';

const _bos = 'Üniversite listesi boş. Birazdan tekrar dene.';
const _baglanti = 'Menü yüklenemedi. İnternet bağlantını kontrol et.';

/// Okul listesi [liste] ya da [hata] ile gelen sahte depo.
class _Depo extends Depo {
  List<Universite> liste;
  Object? hata;
  _Depo(this.liste, {this.hata});

  @override
  Future<List<Universite>> universiteler() async {
    if (hata != null) throw hata!;
    return liste;
  }

  @override
  Future<Menu> menu(String universiteId) async => Menu('a', null, {
        '2026-11-02': {
          'lunch': Ogun([YemekOgesi('Yemek A', 100)], 100)
        }
      });

  @override
  Future<String?> seciliUniversite() async => 'a';

  @override
  Future<void> universiteSec(String id) async {}

  @override
  Future<List<String>> sonSecilenler() async => const [];

  @override
  String? fotoUrl(String universiteId, String? foto) => null;

  @override
  String? yemekFotoUrl(String? img) => null;
}

Future<void> _ac(WidgetTester t, _Depo depo) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final ayar = TemaAyari();
  await t.pumpWidget(MaterialApp(
      theme: ayar.tema(Brightness.light),
      home: AnaSayfa(
          temaAyari: ayar,
          depo: depo,
          geriBildirim: YerelDepo(),
          simdi: () => DateTime.utc(2026, 11, 2, 10, 0))));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('yuklemeHatasiMetni', () {
    test('boş okul listesi için ayrı mesaj verir', () {
      expect(yuklemeHatasiMetni(const BosOkulListesi()), _bos);
    });

    test('diğer her hata için bağlantı mesajı verir', () {
      for (final hata in <Object>[
        Exception('ağ yok'),
        TimeoutException('süre doldu'),
        const FormatException('bozuk veri'),
        StateError('beklenmedik'),
      ]) {
        expect(yuklemeHatasiMetni(hata), _baglanti, reason: '$hata');
      }
    });
  });

  group('ana sayfa', () {
    testWidgets(
        'okul listesi boş gelirse boş liste mesajı ve "Tekrar dene" çıkar; liste gelince menü yüklenir',
        (t) async {
      final depo = _Depo(const []);
      await _ac(t, depo);
      expect(find.text(_bos), findsOneWidget);
      expect(find.text(_baglanti), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);

      depo.liste = [
        Universite(
            id: 'a',
            ad: 'Ankara Üniversitesi',
            kisa: 'a',
            sehir: 'X',
            kaynak: '',
            ogunler: const ['lunch'],
            fiyatlar: const [])
      ];
      await t.tap(find.text('Tekrar dene'));
      await t.pumpAndSettle();
      expect(find.text('Yemek A'), findsOneWidget);
      expect(find.text(_bos), findsNothing);
    });

    testWidgets('okul listesi okunamazsa bağlantı mesajı çıkar', (t) async {
      await _ac(t, _Depo(const [], hata: Exception('ağ yok')));
      expect(find.text(_baglanti), findsOneWidget);
      expect(find.text(_bos), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });
  });
}
