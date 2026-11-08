// P5 madde 2: yorum bölümünün takma ad sorma akışı (_adSor) cihaz depolaması (SharedPreferences) hata verirse
// çökmemeli: kayıtlı ad okunamıyorsa ad yine sorulur, ad yazılamıyorsa yorum yine gönderilir (yalnızca ad
// hatırlanmaz). Eskiden her iki hata da yakalanmadan sızıyor, yorum hiç gönderilmiyordu.
//
// SharedPreferences'ın gerçek (yöntem kanallı) deposu sahte kanalla değiştirilir (desen: universite_sec_prefs_test.dart);
// bu yüzden bu dosyada SharedPreferences.setMockInitialValues kullanılmaz. Yorum / puan tarafı depolamaya hiç
// dokunmayan bellek içi bir depoyla sahtelenir.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';

const _kanal = MethodChannel('plugins.flutter.io/shared_preferences');

/// Kanala gelen çağrılar: 'getAll' ([baslangic] verisini döndürür) ve yazmalar (set*).
class _SahteDepolama {
  /// getAll'ın döndüreceği veri ('flutter.' önekli anahtarlar).
  final Map<String, Object> baslangic;

  /// true ise okuma ('getAll'), yani SharedPreferences.getInstance(), hata verir.
  bool okumaHatasi = false;

  /// true ise her yazma (set*) PlatformException fırlatır.
  bool yazmaHatasi = false;

  /// Yapılan yazma denemesi sayısı (başarısız olanlar dahil).
  int yazmaDenemesi = 0;

  _SahteDepolama([this.baslangic = const {}]);

  Future<Object?> isle(MethodCall c) async {
    if (c.method == 'getAll') {
      if (okumaHatasi) throw PlatformException(code: 'okuma');
      return <String, Object>{...baslangic};
    }
    yazmaDenemesi++;
    if (yazmaHatasi) throw PlatformException(code: 'yazma');
    return true;
  }
}

_SahteDepolama _depolamayiTaklitEt([Map<String, Object> baslangic = const {}]) {
  SharedPreferences
      .resetStatic(); // önceki testin önbelleğe aldığı örnek kalmasın
  final depolama = _SahteDepolama(baslangic);
  final iletisim =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  iletisim.setMockMethodCallHandler(_kanal, depolama.isle);
  addTearDown(() {
    iletisim.setMockMethodCallHandler(_kanal, null);
    SharedPreferences.resetStatic();
  });
  return depolama;
}

/// Hiçbir şey saklamayan, yalnızca eklenen yorumları bellekte tutan depo (depolamaya dokunmaz).
class _BellekDepo implements GeriBildirimDeposu {
  final List<({String slot, String ad, String metin})> eklenen = [];

  @override
  bool get cevrimici => true;

  @override
  Future<String> kullaniciId() async => 'u1';

  @override
  Future<PuanOzeti> puanOzeti(String slot) async => const PuanOzeti(null, 0);

  @override
  Future<int?> benimPuanim(String slot) async => null;

  @override
  Future<YemekPuanlari> puanlar(List<String> slotlar) async =>
      const YemekPuanlari({}, {});

  @override
  Future<void> puanVer(String slot, int yildiz) async {}

  @override
  Future<List<Yorum>> yorumlar(String slot) async => [
        for (var i = 0; i < eklenen.length; i++)
          Yorum('y$i', 'u1', eklenen[i].ad, eklenen[i].metin, DateTime.now())
      ];

  @override
  Future<void> yorumEkle(String slot, String ad, String metin) async =>
      eklenen.add((slot: slot, ad: ad, metin: metin));

  @override
  Future<void> yorumSil(Yorum y) async {}

  @override
  Future<void> yorumBildir(Yorum y, YorumBildirimNedeni neden) async {}

  @override
  Future<void> verilerimiSil() async {}
}

Widget _sayfa(GeriBildirimDeposu depo) => MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child: GeriBildirimBolumu(
                depo: depo, slot: 's1', puanGoster: false))));

/// Yorum kutusuna [metin] yazıp "Gönder"e basar; açılan takma ad kutusunun görünmesini bekler.
Future<void> _gonderAdKutusunaKadar(WidgetTester t, String metin) async {
  await t.enterText(find.byType(TextField), metin);
  await t.tap(find.byTooltip('Gönder'));
  await t.pumpAndSettle();
  // depolama okunamadığında topluluk kuralları her seferinde yeniden sorulur: kabul edilir
  if (find.text('Kabul ediyorum').evaluate().isNotEmpty) {
    await t.tap(find.text('Kabul ediyorum'));
    await t.pumpAndSettle();
  }
}

final _adKutusu = find.descendant(
    of: find.byType(AlertDialog), matching: find.byType(TextField));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'kayıtlı ad okunamazsa (depolama açılamıyor) ad yine sorulur ve yorum gönderilir',
      (t) async {
    final depolama = _depolamayiTaklitEt()..okumaHatasi = true;
    final depo = _BellekDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();

    await _gonderAdKutusunaKadar(t, 'Çok güzeldi');
    expect(find.text('Takma adın'), findsOneWidget,
        reason: 'kayıtlı ad okunamadı: ad sorulmalı');
    expect(t.takeException(), isNull);

    await t.enterText(_adKutusu, 'Ayşe');
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(depolama.okumaHatasi, isTrue);
    expect(depo.eklenen, hasLength(1));
    expect(depo.eklenen.single.ad, 'Ayşe');
    expect(depo.eklenen.single.metin, 'Çok güzeldi');
    expect(find.text('Çok güzeldi'), findsOneWidget,
        reason: 'gönderilen yorum listede görünür');
    expect(find.textContaining('gönderilemedi'), findsNothing);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '',
        reason: 'yorum gönderildi: metin alanı boşalır');
  });

  testWidgets(
      'ad yazılamazsa (depolama yazma hatası) yorum yine gönderilir, hata sızmaz',
      (t) async {
    final depolama = _depolamayiTaklitEt()..yazmaHatasi = true;
    final depo = _BellekDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();

    await _gonderAdKutusunaKadar(t, 'Tuzsuzdu');
    await t.enterText(_adKutusu, 'Mehmet');
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    expect(depolama.yazmaDenemesi, greaterThan(0),
        reason: 'ad yazılmaya çalışıldı ve reddedildi');
    expect(t.takeException(), isNull);
    expect(depo.eklenen, hasLength(1));
    expect(depo.eklenen.single.ad, 'Mehmet');
    expect(find.text('Tuzsuzdu'), findsOneWidget);
    expect(find.textContaining('gönderilemedi'), findsNothing);
  });

  testWidgets(
      'depolama hiç çalışmazken takma ad kutusundan vazgeçilirse hiçbir şey gönderilmez, hata sızmaz',
      (t) async {
    _depolamayiTaklitEt().okumaHatasi = true;
    final depo = _BellekDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();

    await _gonderAdKutusunaKadar(t, 'Merhaba');
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(depo.eklenen, isEmpty);
    expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text, 'Merhaba',
        reason: 'vazgeçildi: yazılan yorum kutuda kalır');
    final gonder = t.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send_rounded));
    expect(gonder.onPressed, isNotNull, reason: 'yeniden gönderilebilir');
  });

  testWidgets('kayıtlı ad varsa ad sorulmaz (koruyucu)', (t) async {
    _depolamayiTaklitEt({'flutter.yorum_adi': 'Ali'});
    final depo = _BellekDepo();
    await t.pumpWidget(_sayfa(depo));
    await t.pumpAndSettle();

    await _gonderAdKutusunaKadar(t, 'Lezzetliydi');
    expect(find.text('Takma adın'), findsNothing);
    expect(depo.eklenen.single.ad, 'Ali');
    expect(find.text('Lezzetliydi'), findsOneWidget);
  });
}
