import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemekhane/favoriler.dart';
import 'package:yemekhane/geri_bildirim.dart';
import 'package:yemekhane/kalori_hedefi.dart';
import 'package:yemekhane/models.dart';
import 'package:yemekhane/paylasim.dart';
import 'package:yemekhane/repository.dart';
import 'package:yemekhane/screens/ayarlar.dart';
import 'package:yemekhane/screens/favoriler.dart';
import 'package:yemekhane/screens/geri_bildirim.dart';
import 'package:yemekhane/screens/hafta.dart';
import 'package:yemekhane/screens/home.dart';
import 'package:yemekhane/screens/tema_secici.dart';
import 'package:yemekhane/screens/university_picker.dart';
import 'package:yemekhane/screens/yemek_ara.dart';
import 'package:yemekhane/screens/yemek_detay.dart';
import 'package:yemekhane/tema.dart';
import 'package:yemekhane/widgets/durum_ekranlari.dart';
import 'package:yemekhane/widgets/gun_secici.dart';
import 'package:yemekhane/widgets/ogun_bilgi.dart';
import 'package:yemekhane/widgets/paylasim_sayfasi.dart';

import 'sahte_resim.dart';

// Erişilebilirlik testleri.
//  - Her ekran 320 dp genişlikte, açık / koyu / siyah temada Flutter'ın üç kılavuzuna uymalı:
//    androidTapTargetGuideline (dokunma hedefi >= 48 dp), labeledTapTargetGuideline (dokunulan her öğede etiket),
//    textContrastGuideline (WCAG AA metin kontrastı).
//  - Yazı ölçeği 2.0'da (320x640) hiçbir ekranda taşma olmamalı.
//  - Kılavuzlar uzun ekranlarda sayfanın tamamı görünecek biçimde (pencere yüksekliği içeriğe uzatılarak)
//    çalıştırılır: kaydırılırken kenarda kesilen satırların yüksekliğini küçük sayıp yanlış alarm verdikleri için.
//  - Okul seçici ve tema seçici de bu kılavuzlardan geçer (arama kutusunun tek, etiketli, >= 48 dp anlam düğümü
//    ve tema modu segmentlerinin 48 dp hedefi ayrıca sınanır).
//  - Kılavuzun görmediği renk çiftleri (tüm paletler), kalp düğmelerinin etiketleri, gün çubuğu ve öğün seçici
//    boyutları ayrıca sınanır.

// --- ortak veri ---------------------------------------------------------------------------------------------------

const _bugun = '2026-11-02'; // Pazartesi
const _uzunAd =
    'Çok Uzun Adlı Kremalı Mantarlı Közlenmiş Patlıcanlı Tavuk Sote Spesiyal Yemeği';

DateTime _simdi() => DateTime.utc(2026, 11, 2, 10, 0);

YemekOgesi _y(String ad, int? kcal, [String? anahtar]) =>
    YemekOgesi(ad, kcal, null, anahtar);

Ogun _notlu(String not) => Ogun(const [], null, null, false, not);

Universite _ankara() => Universite(
        id: 'ankara',
        ad: 'Ankara Üniversitesi',
        kisa: 'AÜ',
        sehir: 'Ankara',
        kaynak: 'https://sks.ankara.edu.tr/yemek-hizmetleri-2/',
        ogunler: const [
          'lunch',
          'dinner'
        ],
        fiyatlar: [
          Fiyat('Öğrenci (Öğle Yemeği)', 50)
        ],
        saatler: const {
          'lunch': ServisSaati('11:30–14:00', false),
          'dinner': ServisSaati('17:00–19:30', true),
        });

Universite _gazi() => Universite(
    id: 'gazi',
    ad: 'Gazi Üniversitesi',
    kisa: 'GÜ',
    sehir: 'Ankara',
    kaynak: '',
    ogunler: const ['lunch'],
    fiyatlar: const []);

/// Bugün öğlede uzun adlı, anahtarlı ve anahtarsız yemekler; 4 Kasım tatil; 5 Kasım Mantı (favori); menü 11 Kasım'a kadar.
Menu _ankaraMenusu() => Menu('ankara', DateTime(2026, 11, 2, 8, 5), {
      '2026-10-30': {
        'lunch': Ogun([_y('Pirinç Pilavı', 300, 'pilav')], 300)
      },
      '2026-11-02': {
        'lunch': Ogun([
          _y('Mercimek Çorbası', 120, 'mercimek'),
          _y(_uzunAd, 650, 'uzun'),
          _y('Pirinç Pilavı', 300, 'pilav'),
          _y('Ayran', 60),
        ], 1130),
        'dinner': Ogun([_y('Fırın Makarna', 500, 'makarna')], 500),
      },
      '2026-11-03': {
        'lunch': Ogun([
          _y('Ezogelin Çorbası', 110, 'ezogelin'),
          _y('Pirinç Pilavı', 300, 'pilav'),
        ], 410)
      },
      '2026-11-04': {'lunch': _notlu('Tatil'), 'dinner': _notlu('Tatil')},
      '2026-11-05': {
        'lunch':
            Ogun([_y('Mantı', 450, 'manti'), _y('Cacık', 80, 'cacik')], 530),
        'dinner': Ogun([_y('Mantı', 450, 'manti')], 450),
      },
      '2026-11-06': {
        'lunch': Ogun([_y('Kuru Fasulye', 350, 'fasulye')], 350)
      },
      // ikinci hafta: gün çubuğunda 7 hücre görünsün (hafta sonu 7 - 8 Kasım menüsüz)
      '2026-11-09': {
        'lunch': Ogun([_y('Domates Çorbası', 90, 'domates')], 90)
      },
      '2026-11-10': {
        'lunch': Ogun([_y('Mantı', 450, 'manti')], 450)
      },
      '2026-11-11': {
        'lunch': Ogun([_y('Yayla Çorbası', 100, 'yayla')], 100)
      },
    });

Menu _gaziMenusu() => Menu('gazi', null, {
      '2026-11-02': {
        'lunch': Ogun([_y('Mercimek Çorbası', 120, 'mercimek')], 120)
      },
    });

/// Ağa ve diske gitmeyen sahte veri deposu. [secili] boşsa kayıtlı okul yoktur (ilk açılış).
class _SahteDepo extends Depo {
  final List<Universite> liste;
  final Map<String, Menu> menuVeri;
  String? secili;
  bool hataAt = false;
  _SahteDepo(this.liste, this.menuVeri, {this.secili});

  @override
  Future<List<Universite>> universiteler() async => liste;
  @override
  Future<Menu> menu(String universiteId) async {
    if (hataAt) throw Exception('ağ yok');
    return menuVeri[universiteId]!;
  }

  @override
  Future<String?> seciliUniversite() async => secili;
  @override
  Future<void> universiteSec(String id) async => secili = id;
  @override
  Future<List<String>> sonSecilenler() async => const [];
  @override
  Future<int> onbellekTemizle() async => 0;
  @override
  String? fotoUrl(String universiteId, String? foto) => null;
  @override
  String? yemekFotoUrl(String? img) => null;
}

_SahteDepo _depo({bool kayitli = true, bool hata = false}) => _SahteDepo(
    [_ankara(), _gazi()], {'ankara': _ankaraMenusu(), 'gazi': _gaziMenusu()},
    secili: kayitli ? 'ankara' : null)
  ..hataAt = hata;

/// Başka kullanıcıların yorumlarını döndüren yerel depo (yorum seçenekleri menüsü görünsün).
class _BaskaYorumluDepo extends YerelDepo {
  @override
  Future<String> kullaniciId() async => 'ben';
  @override
  Future<List<Yorum>> yorumlar(String slot) async => [
        Yorum('c1', 'u2', 'Ayşe', 'Çorba sıcaktı', DateTime(2026, 11, 2, 12),
            slot: slot),
        Yorum('c2', 'u3', 'Mehmet', 'Pilav lezzetliydi',
            DateTime(2026, 11, 2, 11),
            slot: slot),
      ];
}

class _SahtePaylasim implements PaylasimServisi {
  @override
  Future<void> paylas(String metin, {String? konu}) async {}
}

// --- kurulum ------------------------------------------------------------------------------------------------------

enum _Mod {
  acik('açık'),
  koyu('koyu'),
  siyah('siyah');

  final String ad;
  const _Mod(this.ad);
}

class _Kurulum {
  final _Mod mod;
  final double olcek;
  late final TemaAyari ayar = TemaAyari(
      mod: mod == _Mod.acik ? ThemeMode.light : ThemeMode.dark,
      siyah: mod == _Mod.siyah);
  _Kurulum(this.mod, {this.olcek = 1.0});

  Brightness get parlaklik =>
      mod == _Mod.acik ? Brightness.light : Brightness.dark;
}

Widget _uygulama(Widget home, _Kurulum k) => MaterialApp(
      theme: k.ayar.tema(k.parlaklik),
      builder: (c, w) => MediaQuery(
          data:
              MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(k.olcek)),
          child: w!),
      home: home,
    );

/// Ekran 320x640, anlam ağacı açık bir ekran testi; anlam ağacı testin sonunda (doğrulamalardan önce) kapatılır.
void _ekranTesti(String ad, Future<void> Function(WidgetTester t) govde) =>
    testWidgets(ad, (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final anlam = t.ensureSemantics();
      try {
        await govde(t);
      } finally {
        anlam.dispose();
      }
    });

Future<FavoriDeposu> _favoriler() async {
  final f = FavoriDeposu();
  await f.ekle('pilav', 'Pirinç Pilavı');
  await f.ekle('manti', 'Mantı');
  return f;
}

// --- ekranlar -----------------------------------------------------------------------------------------------------

class _Ekran {
  final String ad;
  final Future<void> Function(WidgetTester t, _Kurulum k) ac;
  const _Ekran(this.ad, this.ac);
}

Future<void> _anaSayfaAc(WidgetTester t, _Kurulum k,
    {bool kayitli = true, DateTime? simdi, bool hata = false}) async {
  final favoriler = await _favoriler();
  final gb = YerelDepo();
  // öğle öğününde bir yorum: silme düğmesi de ekranda olsun
  await gb.yorumEkle(slotKimligi('ankara', _bugun, 'lunch'), 'Aç Öğrenci',
      'Çorba sıcaktı, pilav güzeldi.');
  await t.pumpWidget(_uygulama(
      AnaSayfa(
          temaAyari: k.ayar,
          depo: _depo(kayitli: kayitli, hata: hata),
          geriBildirim: gb,
          simdi: simdi == null ? _simdi : () => simdi,
          favoriler: favoriler,
          paylasim: _SahtePaylasim(),
          kaloriHedefi: KaloriHedefi(acik: true)),
      k));
  await t.pumpAndSettle();
}

final _ekranlar = <_Ekran>[
  _Ekran('Ana sayfa', (t, k) => _anaSayfaAc(t, k)),
  _Ekran('İlk açılış', (t, k) => _anaSayfaAc(t, k, kayitli: false)),
  _Ekran('Favoriler', (t, k) async {
    final favoriler = await _favoriler();
    await favoriler.ekle(
        'yok', 'Menüde Olmayan Çok Uzun Adlı Bir Favori Yemek');
    await t.pumpWidget(_uygulama(
        FavorilerSayfasi(
            favoriler: favoriler,
            uni: _ankara(),
            menu: _ankaraMenusu(),
            bugun: _bugun),
        k));
    await t.pumpAndSettle();
  }),
  _Ekran('Yemek ara', (t, k) async {
    await t.pumpWidget(_uygulama(
        YemekAraSayfasi(
            depo: _depo(),
            uniler: [_ankara(), _gazi()],
            uni: _ankara(),
            menu: _ankaraMenusu(),
            bugun: _bugun),
        k));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'corba');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
  }),
  _Ekran('Haftalık menü', (t, k) async {
    await t.pumpWidget(_uygulama(
        HaftaSayfasi(
            uni: _ankara(),
            menu: _ankaraMenusu(),
            bugun: _bugun,
            tarih: _bugun,
            ogun: 'lunch',
            paylasim: _SahtePaylasim(),
            favoriler: await _favoriler()),
        k));
    await t.pumpAndSettle();
  }),
  _Ekran('Yemek ayrıntısı', (t, k) async {
    await t.pumpWidget(_uygulama(
        YemekDetaySayfasi(
            yemek: _y('Mantı', 450, 'manti'),
            uni: _ankara(),
            menu: _ankaraMenusu(),
            bugun: _bugun,
            geriBildirim: YerelDepo(),
            favoriler: await _favoriler()),
        k));
    await t.pumpAndSettle();
  }),
  _Ekran('Ayarlar', (t, k) async {
    await t.pumpWidget(_uygulama(
        AyarlarSayfasi(
            temaAyari: k.ayar,
            depo: _depo(),
            uniler: [_ankara(), _gazi()],
            uni: _ankara(),
            menuyuYenile: () async {},
            kaloriHedefi: KaloriHedefi(acik: true)),
        k));
    await t.pumpAndSettle();
  }),
  _Ekran('Paylaşım alt sayfası', (t, k) async {
    await t.pumpWidget(_uygulama(
        Scaffold(
            body: Builder(
                builder: (c) => TextButton(
                    onPressed: () => paylasimSayfasiGoster(c,
                        servis: _SahtePaylasim(),
                        uni: _ankara(),
                        tarih: _bugun,
                        gun: _ankaraMenusu().gunler[_bugun]!,
                        ogun: 'lunch'),
                    child: const Text('Paylaşımı aç')))),
        k));
    await t.tap(find.text('Paylaşımı aç'));
    await t.pumpAndSettle();
  }),
  _Ekran('Okul seçici', (t, k) async {
    await t.pumpWidget(_uygulama(
        UniversitePicker(
            uniler: [_ankara(), _gazi()],
            secili: 'ankara',
            sonSecilenler: const ['gazi', 'ankara']),
        k));
    await t.pumpAndSettle();
  }),
  _Ekran('Tema seçici', (t, k) async {
    await _temaSeciciAc(t, k);
  }),
];

/// Tema seçici alt sayfasını açar.
Future<void> _temaSeciciAc(WidgetTester t, _Kurulum k) async {
  await t.pumpWidget(_uygulama(
      Scaffold(
          body: Builder(
              builder: (c) => TextButton(
                  onPressed: () => temaSeciciGoster(c, k.ayar),
                  child: const Text('Temayı aç')))),
      k));
  await t.tap(find.text('Temayı aç'));
  await t.pumpAndSettle();
}

/// Ana sayfanın öteki durumları ve açılır pencereler / seçiciler: her durumun kendi renk eşleşmeleri var.
final _durumEkranlari = <_Ekran>[
  _Ekran('Ana sayfa (servis sürüyor)',
      (t, k) => _anaSayfaAc(t, k, simdi: DateTime.utc(2026, 11, 2, 12, 15))),
  _Ekran('Ana sayfa (akşam servisi bitti)',
      (t, k) => _anaSayfaAc(t, k, simdi: DateTime.utc(2026, 11, 2, 21, 0))),
  _Ekran('Ana sayfa (menü yakında bitiyor)',
      (t, k) => _anaSayfaAc(t, k, simdi: DateTime.utc(2026, 11, 9, 10, 0))),
  _Ekran('Ana sayfa (menü bitti bandı)',
      (t, k) => _anaSayfaAc(t, k, simdi: DateTime.utc(2026, 11, 13, 10, 0))),
  _Ekran('Ana sayfa (tatil günü)',
      (t, k) => _anaSayfaAc(t, k, simdi: DateTime.utc(2026, 11, 4, 10, 0))),
  _Ekran('Ana sayfa (hafta sonu, menü yok)',
      (t, k) => _anaSayfaAc(t, k, simdi: DateTime.utc(2026, 11, 7, 10, 0))),
  _Ekran(
      'Ana sayfa (menü yüklenemedi)', (t, k) => _anaSayfaAc(t, k, hata: true)),
  _Ekran('Vejetaryen menü önerisi', (t, k) async {
    // okul o gün ayrı vejetaryen menü yayınlamadıysa öğle / akşamdaki etsiz görünen yemekler önerilir
    await t.pumpWidget(_uygulama(
        Scaffold(body: EtsizOneri(gun: _ankaraMenusu().gunler[_bugun]!)), k));
    await t.pumpAndSettle();
  }),
  _Ekran('Yemek ayrıntısı (fotoğraflı, atıf satırlı)', (t, k) async {
    final resim = (await t.runAsync(createTestImage))!;
    await t.pumpWidget(_uygulama(
        YemekDetaySayfasi(
            yemek: _y('Mantı', 450, 'manti'),
            uni: _ankara(),
            menu: _ankaraMenusu(),
            bugun: _bugun,
            geriBildirim: YerelDepo(),
            favoriler: await _favoriler(),
            foto: HazirResim(resim),
            fotoBilgisi: () async => const YemekBilgisi(
                baslik: 'Manti Utah.jpg',
                yazar: 'Ali Veli',
                lisans: 'CC BY-SA 3.0',
                sayfa:
                    'https://commons.wikimedia.org/wiki/File:Manti_Utah.jpg'),
            buyukFotoOlustur: (_) => HazirResim(resim)),
        k));
    await t.pumpAndSettle();
    expect(find.textContaining('Fotoğraf: Ali Veli'), findsOneWidget);
  }),
  _Ekran('Ayarlar (silme ve gizlilik satırları)', (t, k) async {
    SharedPreferences.setMockInitialValues({
      'engellenen_kisiler': ['u2'],
    });
    await t.pumpWidget(_uygulama(
        AyarlarSayfasi(
            temaAyari: k.ayar,
            depo: _depo(),
            uniler: [_ankara(), _gazi()],
            uni: _ankara(),
            geriBildirim: YerelDepo(),
            menuyuYenile: () async {}),
        k));
    await t.pumpAndSettle();
  }),
  _Ekran('Yorum seçenekleri menüsü', (t, k) async {
    await t.pumpWidget(_uygulama(
        Scaffold(
            body: SingleChildScrollView(
                child: GeriBildirimBolumu(
                    depo: _BaskaYorumluDepo(), slot: 's1', puanGoster: false))),
        k));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Yorum seçenekleri').first);
    await t.pumpAndSettle();
    expect(find.text('Bildir'), findsOneWidget);
    expect(find.text('Bu kişiyi engelle'), findsOneWidget);
  }),
  _Ekran('Yorum bildirme nedeni penceresi', (t, k) async {
    await t.pumpWidget(_uygulama(
        Scaffold(
            body: SingleChildScrollView(
                child: GeriBildirimBolumu(
                    depo: _BaskaYorumluDepo(), slot: 's1', puanGoster: false))),
        k));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Yorum seçenekleri').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Bildir'));
    await t.pumpAndSettle();
    expect(find.text('Hakaret / küfür'), findsOneWidget);
  }),
  _Ekran('Ayarlar (önbellek onay penceresi)', (t, k) async {
    await t.pumpWidget(_uygulama(
        AyarlarSayfasi(
            temaAyari: k.ayar,
            depo: _depo(),
            uniler: [_ankara(), _gazi()],
            uni: _ankara(),
            menuyuYenile: () async {}),
        k));
    await t.pumpAndSettle();
    await t.tap(find.text('Önbelleği temizle'));
    await t.pumpAndSettle();
  }),
];

// --- kılavuzlar ---------------------------------------------------------------------------------------------------

/// Üç kılavuzu o anki ekranda çalıştırır; ihlallerin açıklamalarını döndürür (boşsa uyar).
Future<List<String>> _ihlaller(WidgetTester t) async {
  final ihlaller = <String>[];
  for (final k in [
    androidTapTargetGuideline,
    labeledTapTargetGuideline,
    textContrastGuideline
  ]) {
    final sonuc = await k.evaluate(t);
    if (!sonuc.passed) ihlaller.add('${k.description}\n${sonuc.reason}');
  }
  return ihlaller;
}

/// Çerçevenin yakaladığı hata (taşma gibi) varsa tek satırlık açıklaması.
List<String> _hatalar(WidgetTester t) {
  final e = t.takeException();
  return e == null
      ? const []
      : ['Hata / taşma: ${e.toString().split('\n').first}'];
}

/// Ekrandaki dikey kaydırılabilir alanların toplam kaydırma payı (piksel).
double _kaydirmaPayi(WidgetTester t) => t
    .stateList<ScrollableState>(find.byType(Scrollable))
    .where((s) => s.axisDirection == AxisDirection.down)
    .fold(
        0.0,
        (en, s) =>
            en > s.position.maxScrollExtent ? en : s.position.maxScrollExtent);

/// Pencereyi sayfanın bütün içeriği görünene kadar uzatır (genişlik 320 kalır). Flutter'ın dokunma hedefi
/// kılavuzu kaydırılırken viewport kenarında kesilen öğelerin yüksekliğini küçük sayıp yanlış alarm verir;
/// içerik hiç kesilmesin diye uzun sayfalar parça parça gezilmek yerine tam boyuyla denetlenir.
Future<void> _tamBoyaAc(WidgetTester t) async {
  var yukseklik = 640.0;
  for (var i = 0; i < 5; i++) {
    final pay = _kaydirmaPayi(t);
    if (pay <= 0) return;
    yukseklik += pay + 32;
    t.view.physicalSize = Size(320, yukseklik);
    await t.pumpAndSettle();
  }
}

/// En üstteki dikey kaydırılabilir alanı baştan sona parça parça gezer; her durakta [denetle] çalışır.
/// Bulunan hatalar (tekrarsız) en sonda tek hata olarak bildirilir.
Future<void> _gez(
    WidgetTester t, Future<List<String>> Function() denetle) async {
  final bulunan = <String>{...await denetle()};
  final adaylar = t
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((s) =>
          s.axisDirection == AxisDirection.down &&
          s.position.maxScrollExtent > 0)
      .toList();
  if (adaylar.isNotEmpty) {
    final konum = adaylar.first.position;
    final adim = konum.viewportDimension * 0.8;
    for (var i = 0; i < 40 && konum.pixels < konum.maxScrollExtent - 1; i++) {
      konum.jumpTo((konum.pixels + adim).clamp(0.0, konum.maxScrollExtent));
      await t.pumpAndSettle();
      bulunan.addAll(await denetle());
    }
  }
  expect(bulunan, isEmpty, reason: bulunan.join('\n---\n'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Kılavuz yalnızca etiketi tek bir Text ile birebir eşleşen düğümlerin kontrastına bakar (birleşik etiketli
  // satırlar, kutular ve diyalog metinleri atlanır). Bu yüzden arayüzde gerçekten kullanılan öteki metin /
  // zemin eşleşmeleri her palet ve modda ayrıca sınanır (tema_test.dart'taki temel çiftlere ek olarak).
  test(
      'arayüzde kullanılan öteki metin ve zemin çiftleri tüm paletlerde AA (>= 4.5) kontrasta sahip',
      () {
    final ihlaller = <String>[];
    for (final p in temaRenkleri) {
      for (final (parlaklik, siyah) in [
        (Brightness.light, false),
        (Brightness.dark, false),
        (Brightness.dark, true),
      ]) {
        final r = renkSemasiUret(p, parlaklik, amoled: siyah);
        final ad = '${p.kimlik}/${parlaklik.name}${siyah ? '/siyah' : ''}';
        void kontrol(String ne, Color on, Color zemin, [double enAz = 4.5]) {
          final oran = kontrastOrani(on, zemin);
          if (oran < enAz) {
            ihlaller.add('$ad $ne: ${oran.toStringAsFixed(2)} (en az $enAz)');
          }
        }

        // kartlar, alt sayfalar, diyaloglar, taşma menüsü, hap / şerit zeminleri
        kontrol('onSurface/surfaceContainerHigh', r.onSurface,
            r.surfaceContainerHigh);
        kontrol('onSurface/surfaceContainer', r.onSurface, r.surfaceContainer);
        kontrol('onSurfaceVariant/surfaceContainerLow', r.onSurfaceVariant,
            r.surfaceContainerLow);
        kontrol('onSurfaceVariant/surfaceContainer', r.onSurfaceVariant,
            r.surfaceContainer);
        kontrol('onSurfaceVariant/surfaceContainerHigh', r.onSurfaceVariant,
            r.surfaceContainerHigh);
        kontrol(
            'primary/surfaceContainerLow', r.primary, r.surfaceContainerLow);
        kontrol('primary/surfaceContainer', r.primary, r.surfaceContainer);
        kontrol(
            'primary/surfaceContainerHigh', r.primary, r.surfaceContainerHigh);
        kontrol('onPrimary/primary', r.onPrimary, r.primary);
        // bildirim çubuğu: yazı ve eylem düğmesi
        kontrol('onInverseSurface/inverseSurface', r.onInverseSurface,
            r.inverseSurface);
        kontrol('inversePrimary/inverseSurface', r.inversePrimary,
            r.inverseSurface);
        // metin olmayan arayüz öğeleri (kutu çerçevesi, anahtar, ayraç) için WCAG 1.4.11: >= 3
        kontrol('outline/surface', r.outline, r.surface, 3.0);
        kontrol('outline/surfaceContainerLow', r.outline, r.surfaceContainerLow,
            3.0);
      }
    }
    expect(ihlaller, isEmpty, reason: ihlaller.join('\n'));
  });

  group('öğün seçici: simge yalnızca etiketle birlikte sığıyorsa görünür', () {
    // testlerde yazı tipi "Ahem" (her harf yazı boyu kadar geniş) olduğundan sığma eşikleri gerçekten daha geniştir
    Future<void> ac(WidgetTester t, List<String> turler, double genislik,
        {double olcek = 1.0}) async {
      t.view.physicalSize = Size(genislik, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          builder: (c, w) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(olcek)),
              child: w!),
          home: Scaffold(
              body: OgunSecici(
                  turler: turler, aktif: turler.first, degisti: (_) {}))));
      await t.pumpAndSettle();
    }

    const uc = ['lunch', 'dinner', 'vegetarian'];

    testWidgets('3 segment, yeterince geniş ekran: simgeler görünür',
        (t) async {
      await ac(t, uc, 800);
      for (final tur in uc) {
        expect(find.byIcon(ogunIkon[tur]!), findsOneWidget, reason: tur);
      }
      expect(t.takeException(), isNull);
    });

    testWidgets(
        '3 segment, dar ekran: simge atılır (etiketler simgeyle daralmasın)',
        (t) async {
      await ac(t, uc, 320);
      for (final tur in uc) {
        expect(find.byIcon(ogunIkon[tur]!), findsNothing, reason: tur);
      }
      // simgesiz düğme içeriğe göre daralmaz: ekranın tamamını (320 - 2 x 16 dp kenar) eşit paylaşır
      expect(t.getSize(find.byType(SegmentedButton<String>)).width, 288);
      expect(t.takeException(), isNull);
    });

    testWidgets('yazı ölçeği büyüyünce geniş ekranda bile simge atılır',
        (t) async {
      await ac(t, uc, 800, olcek: 2.0);
      expect(find.byIcon(ogunIkon['vegetarian']!), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('2 segment dar ekranda da simgeli kalır', (t) async {
      await ac(t, const ['lunch', 'dinner'], 320);
      expect(find.byIcon(ogunIkon['lunch']!), findsOneWidget);
      expect(find.byIcon(ogunIkon['dinner']!), findsOneWidget);
    });

    testWidgets('4 segmentte hiç simge yok', (t) async {
      await ac(t, ogunSirasi, 1200);
      for (final tur in ogunSirasi) {
        expect(find.byIcon(ogunIkon[tur]!), findsNothing, reason: tur);
      }
    });
  });

  group('gün çubuğu: her hücre en az 48 dp genişliğinde (dokunma hedefi)', () {
    List<String> gunler(int n) =>
        [for (var i = 0; i < n; i++) isoTarih(DateTime.utc(2026, 11, 2 + i))];

    test('haftaSeridiHucreSayisi: genişliğe göre en çok 7, en az 1', () {
      expect(
          haftaSeridiHucreSayisi(304), 6); // 320 dp ekran, 8 dp kenar boşluğu
      expect(haftaSeridiHucreSayisi(344), 7); // 360 dp
      expect(haftaSeridiHucreSayisi(374), 7); // 390 dp
      expect(haftaSeridiHucreSayisi(1000), 7);
      expect(haftaSeridiHucreSayisi(100), 2);
      expect(haftaSeridiHucreSayisi(10), 1);
    });

    Future<List<String>> ac(
        WidgetTester t, double genislik, List<String> gun, String secili,
        {void Function(String)? degisti}) async {
      t.view.physicalSize = Size(genislik, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: HaftaSeridi(
                  tarihler: gun,
                  secili: secili,
                  bugun: gun.isEmpty ? secili : gun.first,
                  degisti: degisti ?? (_) {}))));
      return [
        for (final h in t.widgetList<GunHucresi>(find.byType(GunHucresi)))
          h.tarih
      ];
    }

    for (final (genislik, beklenen) in [
      (280.0, 5),
      (320.0, 6),
      (360.0, 7),
      (390.0, 7),
      (600.0, 7),
    ]) {
      testWidgets(
          '${genislik.toInt()} dp ekran: $beklenen hücre, her biri >= 48 dp, seçili gün ortada',
          (t) async {
        final gun = gunler(20);
        final gorunen = await ac(t, genislik, gun, gun[10]);
        expect(gorunen, hasLength(beklenen));
        for (var i = 0; i < beklenen; i++) {
          expect(t.getSize(find.byType(GunHucresi).at(i)).width,
              greaterThanOrEqualTo(48));
        }
        // seçili gün görünür ve (listenin ortasında) pencerenin ortasındadır; günler ardışıktır
        expect(gorunen, contains(gun[10]));
        expect(gorunen.indexOf(gun[10]), beklenen ~/ 2);
        expect(
            gorunen, gun.sublist(10 - beklenen ~/ 2).take(beklenen).toList());
      });
    }

    testWidgets('liste başında ve sonunda pencere listenin dışına taşmaz',
        (t) async {
      final gun = gunler(20);
      expect(await ac(t, 320, gun, gun.first), gun.take(6).toList());
      expect(await ac(t, 320, gun, gun.last), gun.sublist(14));
    });

    testWidgets('gün sayısı hücre sayısından azsa hepsi gösterilir', (t) async {
      final gun = gunler(3);
      expect(await ac(t, 390, gun, gun[1]), gun);
      expect(t.getSize(find.byType(GunHucresi).first).width,
          greaterThanOrEqualTo(48));
    });

    testWidgets('boş gün listesi hata vermez', (t) async {
      expect(await ac(t, 320, const [], '2026-11-02'), isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'anlam düğümü hücrenin tamamıdır ve hücrelerin arasındaki 2.5 dp boşluğa dokunmak da gün seçer',
        (t) async {
      final anlam = t.ensureSemantics();
      try {
        final gun = gunler(10);
        final secilenler = <String>[];
        await ac(t, 320, gun, gun.first, degisti: secilenler.add);
        final hucre = find.byType(GunHucresi).at(1);
        final kutu = t.getRect(hucre);
        // ilk hücreyle arasındaki sınıra yakın kenar boşluğuna dokunulur
        await t.tapAt(Offset(kutu.left + 1, kutu.center.dy));
        expect(secilenler, [gun[1]]);
        // anlam düğümü de en az 48 dp genişliğinde (kılavuz bunu ölçer)
        final dugum = t.getSemantics(hucre);
        expect(dugum.rect.width, greaterThanOrEqualTo(48));
        expect(dugum.label, contains('3 Kasım'));
      } finally {
        anlam.dispose();
      }
    });
  });

  group('kalp düğmesinin ekran okuyucu etiketi yemek adını içerir', () {
    test('favoriDugmeEtiketi: ad ve eylem; tooltip metinleri değişmez', () {
      expect(
          favoriDugmeEtiketi('Mantı', favori: false), 'Mantı: favorilere ekle');
      expect(favoriDugmeEtiketi('  Mantı ', favori: true),
          'Mantı: favorilerden çıkar');
    });

    _ekranTesti('ana sayfa: her yemeğin kalbi kendi adını söyler', (t) async {
      await _anaSayfaAc(t, _Kurulum(_Mod.acik));
      await _tamBoyaAc(t);
      // bugünün öğlesinde yalnızca Pirinç Pilavı favori; anahtarsız Ayran'ın kalbi yok
      final dolu = t.getSemantics(find.byTooltip('Favorilerden çıkar'));
      expect(dolu.label, 'Pirinç Pilavı: favorilerden çıkar');
      expect(dolu.tooltip, 'Favorilerden çıkar');
      final bos = find.byTooltip('Favorilere ekle');
      expect(bos, findsNWidgets(2));
      final etiketler = [
        for (var i = 0; i < 2; i++) t.getSemantics(bos.at(i)).label
      ];
      expect(etiketler, [
        'Mercimek Çorbası: favorilere ekle',
        '$_uzunAd: favorilere ekle',
      ]);
      expect(t.getSemantics(bos.at(0)).tooltip, 'Favorilere ekle');
      // dokununca etiket de değişir
      await t.tap(bos.at(0));
      await t.pumpAndSettle();
      expect(find.byTooltip('Favorilerden çıkar'), findsNWidgets(2));
      expect(t.getSemantics(find.byTooltip('Favorilerden çıkar').at(0)).label,
          'Mercimek Çorbası: favorilerden çıkar');
    });

    _ekranTesti('yemek ayrıntısı: üst çubuktaki kalp yemeğin adını söyler',
        (t) async {
      await t.pumpWidget(_uygulama(
          YemekDetaySayfasi(
              yemek: _y('Mantı', 450, 'manti'),
              uni: _ankara(),
              menu: _ankaraMenusu(),
              bugun: _bugun,
              geriBildirim: YerelDepo(),
              favoriler: await _favoriler()),
          _Kurulum(_Mod.acik)));
      await t.pumpAndSettle();
      final kalp = t.getSemantics(find.byTooltip('Favorilerden çıkar'));
      expect(kalp.label, 'Mantı: favorilerden çıkar');
      expect(kalp.tooltip, 'Favorilerden çıkar');
    });

    _ekranTesti('favoriler: her satırın kaldır düğmesi yemeğin adını söyler',
        (t) async {
      await t.pumpWidget(_uygulama(
          FavorilerSayfasi(
              favoriler: await _favoriler(),
              uni: _ankara(),
              menu: _ankaraMenusu(),
              bugun: _bugun),
          _Kurulum(_Mod.acik)));
      await t.pumpAndSettle();
      final kaldir = find.byTooltip('Favorilerden çıkar');
      expect(kaldir, findsNWidgets(2));
      // en son eklenen başta: Mantı, sonra Pirinç Pilavı
      expect(t.getSemantics(kaldir.at(0)).label, 'Mantı: favorilerden çıkar');
      expect(t.getSemantics(kaldir.at(1)).label,
          'Pirinç Pilavı: favorilerden çıkar');
      expect(t.getSemantics(kaldir.at(0)).tooltip, 'Favorilerden çıkar');
    });
  });

  group('okul seçici ve tema seçici: kalan erişilebilirlik', () {
    _ekranTesti(
        'okul seçici: arama kutusu tek düğüm, "Üniversite veya şehir ara" etiketli, >= 48 dp',
        (t) async {
      await t.pumpWidget(_uygulama(
          UniversitePicker(uniler: [_ankara(), _gazi()], secili: 'ankara'),
          _Kurulum(_Mod.acik)));
      await t.pumpAndSettle();
      expect(find.byType(SearchBar), findsOneWidget);
      final dugum = t.getSemantics(find.byType(SearchBar));
      final veri = dugum.getSemanticsData();
      expect(veri.label, 'Üniversite veya şehir ara');
      expect(veri.flagsCollection.isTextField, isTrue);
      expect(veri.hasAction(SemanticsAction.tap), isTrue);
      expect(dugum.rect.height, greaterThanOrEqualTo(48));
      expect(dugum.rect.width, greaterThanOrEqualTo(48));
      // ayrı bir 23 dp'lik iç yazı alanı düğümü kalmadı
      expect(
          t.semantics
              .find(find.descendant(
                  of: find.byType(SearchBar), matching: find.byType(TextField)))
              .rect
              .height,
          greaterThanOrEqualTo(48));
      // arama hâlâ çalışır
      await t.enterText(find.byType(SearchBar), 'gazi');
      await t.pump();
      expect(find.text('Gazi Üniversitesi'), findsWidgets);
      expect(find.text('Ankara Üniversitesi'), findsNothing);
    });

    for (final mod in _Mod.values) {
      _ekranTesti(
          'tema seçici (${mod.ad} tema): görünüm segmentleri >= 48 dp, etiketli ve tek tek seçilebilir',
          (t) async {
        final k = _Kurulum(mod);
        await _temaSeciciAc(t, k);
        for (final ad in ['Sistem', 'Açık', 'Koyu', 'Siyah']) {
          final dugum = t.getSemantics(find.text(ad));
          final veri =
              dugum.getSemanticsData(); // birleşmiş çocukların etiketi dahil
          expect(dugum.rect.height, greaterThanOrEqualTo(48), reason: ad);
          expect(dugum.rect.width, greaterThanOrEqualTo(48), reason: ad);
          expect(veri.label, ad);
          expect(veri.hasAction(SemanticsAction.tap), isTrue, reason: ad);
        }
        // dokununca seçilir
        await t.tap(find.text('Koyu'));
        await t.pumpAndSettle();
        expect(k.ayar.mod, ThemeMode.dark);
        expect(k.ayar.siyah, isFalse);
      });
    }
  });

  for (final ekran in [..._ekranlar, ..._durumEkranlari]) {
    for (final mod in _Mod.values) {
      _ekranTesti(
          '${ekran.ad} (${mod.ad} tema): dokunma hedefi, etiket ve metin kontrastı kılavuzlara uyar',
          (t) async {
        await ekran.ac(t, _Kurulum(mod));
        await _tamBoyaAc(t);
        final ihlaller = await _ihlaller(t);
        expect(ihlaller, isEmpty, reason: ihlaller.join('\n---\n'));
      });
    }
  }

  for (final ekran in [..._ekranlar, ..._durumEkranlari]) {
    _ekranTesti('${ekran.ad}: yazı ölçeği 2.0, 320x640: taşma olmaz',
        (t) async {
      await ekran.ac(t, _Kurulum(_Mod.acik, olcek: 2.0));
      await _gez(t, () async => _hatalar(t));
    });
  }
}
