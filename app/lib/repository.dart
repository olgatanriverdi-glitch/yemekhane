import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

/// Veriyi sırayla dener: internet -> önbellek -> uygulamayla gelen kopya. Böylece çevrimdışıyken de menü görünür.
class Depo {
  /// [istemci] verilirse ağ istekleri onunla yapılır (testlerde sahte istemci); boşsa `http.get`.
  /// [agZamanAsimi]: tek bir veri isteğinin en çok bekleyeceği süre; dolunca önbellek / uygulamayla gelen
  /// kopyaya düşülür (ağ takılırsa ekran uzun süre iskelette kalmasın).
  Depo(
      {http.Client? istemci,
      Duration agZamanAsimi = const Duration(seconds: 8)})
      : _istemci = istemci,
        _agZamanAsimi = agZamanAsimi;

  final http.Client? _istemci;
  final Duration _agZamanAsimi;

  /// Ağdan alınan okul listesi / menü kopyalarının SharedPreferences anahtar öneki.
  static const _onbellekOneki = 'onbellek/';

  /// Yemek fotoğraflarının Commons bilgisi (yazar, lisans, dosya adı); `veriTabanUrl` altında, uygulamayla gelmez.
  static const _yemekIndeksiYolu = 'dishes/index.json';

  /// Toplu okumaların ([menuler]) çalıştığı zone'u işaretler: bu zone'da [_oku] ortak [cevrimdisi] bayrağına
  /// dokunmaz. Zone, o çağrının bütün zaman uyumsuz adımlarına otomatik geçer; eşzamanlı başka okumaları etkilemez.
  static final Object _topluOkuma = Object();

  /// Seçili okulun son okunan verisi ağdan alınamadıysa true. Sunucu 404 verirse (dosya henüz depoda yok) bağlantı
  /// vardır, bayrak false olur. Toplu okumalar ([menuler]) ve isteğe bağlı dosyalar (fotoğraf bilgisi) bayrağı
  /// değiştirmez.
  bool cevrimdisi = false;

  static DateTime? _updated(String govde) {
    try {
      final j = jsonDecode(govde);
      return j is Map ? DateTime.tryParse('${j['updated'] ?? ''}') : null;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _al(Uri adres) =>
      _istemci?.get(adres) ?? http.get(adres);

  /// [yol]daki veriyi sırayla internetten, önbellekten, uygulamayla gelen kopyadan okur. [durumuBildir] false ise
  /// [cevrimdisi] değişmez: menü gibi asıl veriden bağımsız, isteğe bağlı dosyaların (fotoğraf bilgisi) eksikliği
  /// "çevrimdışı" uyarısı çıkarmasın. Toplu okuma zone'unda ([_topluOkuma]) da değişmez: arama sırasında başka
  /// okulların başarısızlığı ya da başarısı, seçili okulun durumunu değiştirmesin.
  /// Sunucu 404 verirse (okul depoya henüz eklenmemiş) bağlantı vardır: [cevrimdisi] false olur, yine de
  /// önbelleğe / uygulamayla gelen kopyaya düşülür. Başka her başarısızlık (200 dışı yanıt, istisna, zaman aşımı) true yapar.
  /// Cihaz depolaması (SharedPreferences) açılamaz ya da yazılamazsa hata yutulur: önbellek yok sayılır, ağdan
  /// indirilen veri yine döner ve depolama hatası ağ hatası sayılmaz ([cevrimdisi] değişmez).
  Future<String> _oku(String yol, {bool durumuBildir = true}) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final bildir = durumuBildir && Zone.current[_topluOkuma] != true;
    if (veriTabanUrl.isNotEmpty) {
      var sunucuYanitladi = false;
      String? govde;
      try {
        final r =
            await _al(Uri.parse('$veriTabanUrl/$yol')).timeout(_agZamanAsimi);
        if (r.statusCode == 200) {
          final metin = utf8.decode(r.bodyBytes);
          jsonDecode(metin); // bozuk veriyi önbelleğe yazma
          govde = metin;
        } else {
          sunucuYanitladi = r.statusCode == 404;
        }
      } catch (_) {}
      if (govde != null) {
        try {
          await prefs?.setString('$_onbellekOneki$yol', govde);
        } catch (_) {}
        if (bildir) cevrimdisi = false;
        return govde;
      }
      if (bildir) cevrimdisi = !sunucuYanitladi;
    }
    String? onbellek;
    try {
      onbellek = prefs?.getString('$_onbellekOneki$yol');
    } catch (_) {}
    String? paket;
    try {
      paket = await rootBundle.loadString('assets/data/$yol');
    } catch (_) {}
    if (onbellek == null) {
      return paket ?? await rootBundle.loadString('assets/data/$yol');
    }
    if (paket == null) return onbellek;
    // uygulamayla gelen kopya önbellekten daha yeniyse (uygulama güncellendi) onu kullan
    final uo = _updated(onbellek), up = _updated(paket);
    return (uo != null && up != null && up.isAfter(uo)) ? paket : onbellek;
  }

  /// index.json içeriğinden okulları ayıklar. Kayıtlar tek tek ayrıştırılır: bozuk kayıt atlanır, kalanlar
  /// kullanılır. İçerik beklenmedik biçimdeyse (harita değil, 'universities' liste değil) boş liste döner.
  static List<Universite> _okullariAyikla(Object? j) {
    final ham = j is Map ? j['universities'] : null;
    if (ham is! List) return [];
    final liste = <Universite>[];
    for (final e in ham) {
      try {
        if (e is Map<String, dynamic>) liste.add(Universite.fromJson(e));
      } catch (_) {
        // bozuk okul kaydı bütün listeyi düşürmesin
      }
    }
    return liste;
  }

  /// Okul listesi: internetten / önbellekten okunan liste, ardından uygulamayla gelen listede olup bunda olmayan
  /// okullar (ör. eski önbellek ya da henüz yayınlanmamış yeni okullar) eklenir. Okunan liste bozuksa ya da hiç
  /// geçerli okul içermiyorsa uygulamayla gelen liste kullanılır. Boş liste yalnızca iki kaynak da boşsa döner;
  /// ikisi de okunamıyorsa ilk hata fırlatılır.
  Future<List<Universite>> universiteler() async {
    Object? hata;
    StackTrace? hataIzi;
    var liste = <Universite>[];
    try {
      liste = _okullariAyikla(jsonDecode(await _oku('index.json')));
    } catch (e, iz) {
      hata = e;
      hataIzi = iz;
    }
    try {
      final paket = _okullariAyikla(
          jsonDecode(await rootBundle.loadString('assets/data/index.json')));
      final idler = liste.map((u) => u.id).toSet();
      for (final u in paket) {
        if (idler.add(u.id)) liste.add(u);
      }
    } catch (e, iz) {
      hata ??= e;
      hataIzi ??= iz;
    }
    if (liste.isEmpty && hata != null) {
      Error.throwWithStackTrace(hata, hataIzi ?? StackTrace.current);
    }
    return liste;
  }

  Future<Menu> menu(String universiteId) async {
    final j = jsonDecode(await _oku('$universiteId/menu.json'))
        as Map<String, dynamic>;
    return Menu.fromJson(j);
  }

  /// Birden çok okulun menüsünü paralel yükler (şehirde / tüm okullarda arama için). Tek bir okulun
  /// hatası diğerlerini düşürmez: o okul sonuçta null olur. [biten] her okul bitince (başarılı ya da
  /// değil) çağrılır; böylece "12/38 okul yüklendi" gibi ilerleme ve kısmi sonuçlar gösterilebilir.
  /// Sonuç, [idler] sırasında ve tekilleştirilmiş döner. Her okul [menu] ile okunur ama ortak [cevrimdisi]
  /// bayrağı değişmez (bkz. [_topluOkuma]): ana ekrandaki "Çevrimdışı" notu yalnızca seçili okulu anlatır.
  Future<Map<String, Menu?>> menuler(List<String> idler,
      {void Function(String id, Menu? menu)? biten}) async {
    final tekil = idler.toSet().toList();
    final sonuc = <String, Menu?>{};
    await Future.wait([
      for (final id in tekil)
        () async {
          Menu? m;
          try {
            m = await runZoned(() => menu(id), zoneValues: {_topluOkuma: true});
          } catch (_) {
            m = null;
          }
          sonuc[id] = m;
          try {
            biten?.call(id, m);
          } catch (_) {
            // dinleyicinin hatası diğer okulların yüklenmesini bozmasın
          }
        }()
    ]);
    return {for (final id in tekil) id: sonuc[id]};
  }

  /// Cihazda saklanan menü / okul listesi kopyalarını ('onbellek/...') siler; seçili okul, son
  /// seçilenler, tema, puan ve yorumlara dokunmaz. Silinen kayıt sayısını döndürür (hata olursa 0).
  Future<int> onbellekTemizle() async {
    try {
      final p = await SharedPreferences.getInstance();
      var silinen = 0;
      for (final k in p.getKeys().toList()) {
        if (k.startsWith(_onbellekOneki) && await p.remove(k)) silinen++;
      }
      return silinen;
    } catch (_) {
      return 0;
    }
  }

  /// Günün fotoğrafının adresi (yalnızca internet adresi tanımlıysa).
  String? fotoUrl(String universiteId, String? foto) =>
      (foto == null || veriTabanUrl.isEmpty)
          ? null
          : '$veriTabanUrl/$universiteId/$foto';

  /// Yemeğin küçük örnek fotoğrafı ('dishes/..jpg'): üniversiteden bağımsız ortak klasörde.
  String? yemekFotoUrl(String? img) =>
      (img == null || veriTabanUrl.isEmpty) ? null : '$veriTabanUrl/$img';

  // Fotoğraf bilgisi tablosu (anahtar -> kayıt); ilk istekte bir kez okunur ve bellekte tutulur. Başarısız okuma
  // tutulmaz: sonraki istek yeniden dener. Aynı anda gelen istekler tek okumayı paylaşır.
  Future<Map<String, dynamic>?>? _yemekTablosu;

  Future<Map<String, dynamic>?> _yemekTablosunuAl() {
    final mevcut = _yemekTablosu;
    if (mevcut != null) return mevcut;
    final istek = _yemekTablosunuOku();
    _yemekTablosu = istek;
    istek.then((tablo) {
      if (tablo == null && identical(_yemekTablosu, istek)) {
        _yemekTablosu = null;
      }
    });
    return istek;
  }

  Future<Map<String, dynamic>?> _yemekTablosunuOku() async {
    try {
      final j = jsonDecode(await _oku(_yemekIndeksiYolu, durumuBildir: false));
      final tablo = j is Map ? j['dishes'] : null;
      return tablo is Map<String, dynamic> ? tablo : null;
    } catch (_) {
      return null;
    }
  }

  /// [anahtar]lı yemeğin fotoğraf bilgisi (Commons dosya adı, yazar, lisans, sayfa adresi). Bilgi dosyası
  /// (`dishes/index.json`) ilk çağrıda internetten indirilir, 'onbellek/dishes/index.json' olarak saklanır ve
  /// bellekte tutulur; dosya alınamazsa, bozuksa ya da yemek yoksa null döner (uygulama bilgisiz de çalışır,
  /// hata fırlatmaz) ve [cevrimdisi] değişmez.
  Future<YemekBilgisi?> yemekBilgisi(String anahtar) async {
    if (anahtar.isEmpty) return null;
    final tablo = await _yemekTablosunuAl();
    return YemekBilgisi.fromJson(tablo?[anahtar]);
  }

  /// Cihazda kayıtlı okulun kimliği; kayıt yoksa ya da depolama okunamazsa null (okul seçilmemiş sayılır).
  Future<String?> seciliUniversite() async {
    try {
      return (await SharedPreferences.getInstance()).getString('universite');
    } catch (_) {
      return null;
    }
  }

  /// Seçilen okulu cihaza kaydeder (bir sonraki açılışta aynı okul açılır). Kayıt hatası yutulur: menü zaten
  /// yüklenmiş ve gösteriliyor olabilir, bu yüzden hiçbir şey fırlatmaz; yalnızca seçim hatırlanmayabilir.
  Future<void> universiteSec(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('universite', id);
      await _sonSecileniEkle(p, id);
    } catch (_) {}
  }

  static const _sonAnahtar = 'son_secilenler';

  Future<void> _sonSecileniEkle(SharedPreferences p, String id) async {
    try {
      final liste = [id, ...(p.getStringList(_sonAnahtar) ?? const <String>[])];
      final tekil = <String>[];
      for (final x in liste) {
        if (!tekil.contains(x)) tekil.add(x);
      }
      await p.setStringList(
          _sonAnahtar,
          tekil
              .take(4)
              .toList()); // seçili okul dahil; ekranda en çok 3 gösterilir
    } catch (_) {}
  }

  /// Son seçilen okul kimlikleri (en yeni başta). Okunamazsa boş döner.
  Future<List<String>> sonSecilenler() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_sonAnahtar) ?? const <String>[]).toList();
    } catch (_) {
      return const [];
    }
  }
}
