import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'reklam_ayari.dart';
import 'reklam_servisi.dart';
import 'uzak_ayar.dart';

class _Kayit {
  _Kayit(this.nesne, this.zaman);
  final ReklamNesnesi nesne;
  DateTime zaman;
}

/// Reklamların yaşam döngüsü: ne zaman istek atılır, kaç reklam bellekte tutulur, hangi widget hangisini gösterir.
///
/// - Yeni kullanıcıya nezaket: [gosterilebilir] ilk açılıştan sonraki [UzakReklamAyari.lutufGun] (2) gün false döner
///   ([reklamsizSureBitti]).
/// - Uzaktan ayar ([ayarGetir], `ayarlar.json`): reklam kapatılabilir (SDK hiç başlatılmaz), yerleşimler tek tek
///   kapatılabilir; okunamazsa güvenli varsayılan ([UzakReklamAyari.varsayilan]).
/// - Reklamsız gün: ödüllü reklam izlenince 24 saat hiçbir reklam gösterilmez ([reklamsizMi]).
/// - Oturum sınırı: en çok [oturumSiniri] yükleme (varsayılan 20); sonrası yalnızca bellektekiler yeniden kullanılır.
/// - Küçük LRU: en çok [onbellekSiniri] reklam; fazlası (kimse göstermiyorsa) serbest bırakılır. Yüklenemeyen
///   anahtar [reklamHataBeklemesi] boyunca yeniden denenmez; aynı anahtara eşzamanlı istekler tek yüklemeyi paylaşır.
/// - Sahiplik: AdWidget aynı reklamla ağaçta iki kez durursa istisna atar. Gün geçişinde (AnimatedSwitcher) eski
///   ve yeni çocuk bir süre birlikte durur; bu yüzden bir reklamı aynı anda yalnızca bir widget gösterir
///   ([sahiplen] / [birak]); ikincisi boş döner ve sahip bırakınca haberdar edilir ([addListener]).
/// - Rıza: ilk istekten önce [ReklamServisi.hazirla] (rıza + SDK) bir kez çalışır; false ise istek atılmaz.
///
/// Servis [ReklamServisi.kullanilabilir] değilse ([acik] false) hiçbir şey yapılmaz.
class ReklamYoneticisi extends ChangeNotifier {
  ReklamYoneticisi(
      {required this.servis,
      DateTime Function()? simdi,
      this.bekleme = reklamBeklemesi,
      int? oturumSiniri,
      this.onbellekSiniri = reklamOnbellekSiniri,
      this.ayarGetir})
      : _oturumZorla = oturumSiniri,
        _simdi = simdi ?? turkiyeSimdi;

  final ReklamServisi servis;
  final DateTime Function() _simdi;

  /// Aynı gün + öğünde istek atmadan önce beklenen süre.
  final Duration bekleme;
  final int? _oturumZorla;
  final int onbellekSiniri;

  /// Uzaktan ayarı getirir (`Depo.reklamAyari`); boşsa ya da hata verirse [UzakReklamAyari.varsayilan].
  final Future<UzakReklamAyari> Function()? ayarGetir;
  UzakReklamAyari _ayar = UzakReklamAyari.varsayilan;
  Future<void>? _baslangic;
  bool _lutufBitti = false;
  bool _ilkGunGecti = false;
  Future<void>? _ayarOkuma;
  DateTime? _reklamsizBitisi;
  Timer? _reklamsizZamani;

  /// Oturumda en çok yükleme: yapıcıda verilmişse o (testler), yoksa uzaktan ayar (varsayılan 20).
  int get oturumSiniri => _oturumZorla ?? _ayar.oturumSiniri;

  /// Yöneticinin saati (Türkiye duvar saati).
  DateTime simdi() => _simdi();

  /// Etkin uzaktan ayar (yüklenene dek varsayılan).
  UzakReklamAyari get ayar => _ayar;

  /// Yeni kullanıcı nezaket süresi bitti mi ([baslat] / [gosterilebilir] günceller)?
  bool get lutufBitti => _lutufBitti;

  /// Ödüllü "Reklamsız gün" şu an etkin mi?
  bool get reklamsizMi {
    final b = _reklamsizBitisi;
    return b != null && _simdi().isBefore(b);
  }

  /// Reklamsız sürenin bitişi (Türkiye duvar saati); etkin değilse null.
  DateTime? get reklamsizBitis => reklamsizMi ? _reklamsizBitisi : null;

  /// "Reklamsız gün kazan" önerilebilir mi: reklam mümkün, ödüllü birim var, uzaktan açık, nezaket süresi bitmiş
  /// ve zaten reklamsız değil.
  bool get odulluAcik =>
      acik &&
      servis.odulluKullanilabilir &&
      _ayar.odullu &&
      _lutufBitti &&
      !reklamsizMi;

  /// [yer] yerleşiminde şu an reklam çizilebilir mi (reklam açık, uzaktan açık, reklamsız gün değil)?
  bool yerlesimIzinli(String yer) =>
      acik && !reklamsizMi && _ayar.yerlesimAcik(yer);

  // ekleme sırası = kullanım sırası (en eski başta)
  final Map<String, _Kayit> _onbellek = {};
  final Map<String, Future<ReklamNesnesi?>> _devam = {};
  final Map<String, DateTime> _hatalar = {};
  final Map<String, Object> _sahipler = {};

  /// Rıza bilgisi her güncellendiğinde (istek hazırlığı bitince) bir artar; Ayarlar "Reklam tercihleri" satırını
  /// bununla yeniden değerlendirir (UMP yanıtı Ayarlar açıkken gelebilir).
  final ValueNotifier<int> rizaSurumu = ValueNotifier<int>(0);
  Future<bool>? _hazir;
  DateTime? _hazirHatasi;

  /// Rıza tercihi her değiştiğinde artar; eski nesilde başlayan yüklemelerin sonucu atılır.
  int _nesil = 0;
  int _yuklemeSayisi = 0;
  bool _kapandi = false;

  /// Reklam bu derlemede ve platformda mümkün mü?
  bool get acik => !_kapandi && servis.kullanilabilir && _ayar.aktif;

  /// Bu oturumda servise gönderilen yükleme sayısı.
  int get yuklemeSayisi => _yuklemeSayisi;

  /// Bellekteki reklam sayısı.
  int get onbellekAdedi => _onbellek.length;

  /// Önbellek anahtarı: gün + öğün ([taban]) ve görünüm imzası (tema değişince yeni reklam gerekir).
  String anahtarOlustur(String taban, ReklamStili stil) =>
      '$taban|${stil.imza}';

  // ---- yeni kullanıcı nezaketi ---------------------------------------------------------------------------------

  /// İlk açılış gününü (yoksa ya da bozuksa bugünü) saklar ve süre dolduysa true döner. Saklama okunamazsa false.
  Future<bool> _ilkAcilisKontrol() async {
    try {
      final p = await SharedPreferences.getInstance();
      final simdi = _simdi();
      final kayit = p.get(ilkAcilisAnahtari);
      if (!ilkAcilisKaydiGecerli(kayit, simdi)) {
        await p.setString(ilkAcilisAnahtari, isoTarih(simdi));
        _ilkGunGecti = false;
        return _lutufBitti = false;
      }
      _ilkGunGecti = reklamsizSureBitti(kayit, simdi, gun: 0);
      return _lutufBitti =
          reklamsizSureBitti(kayit, simdi, gun: _ayar.lutufGun);
    } catch (_) {
      _ilkGunGecti = false;
      return _lutufBitti = false;
    }
  }

  /// İlk açılış gününü saklar (reklam kapalı olsa da; sonradan açılırsa nezaket süresi doğru işlesin) ve reklamsız
  /// gün kaydını okur. Bir kez çalışır; sonraki çağrılar aynı işi bekler. Ağa çıkmaz.
  Future<void> ilkAcilisiKaydet() => baslat();

  /// [ilkAcilisiKaydet] ile aynı.
  Future<void> baslat() => _baslangic ??= _baslat();

  Future<void> _baslat() async {
    await _ilkAcilisKontrol();
    await _reklamsizOku();
    if (!_kapandi) notifyListeners();
  }

  /// Uzaktan ayarı bir kez okur ([ayarGetir]). Yalnızca reklam mümkünse ve ilk açılış günü geçmişse ağa çıkılır:
  /// ilk açılış gününde hiçbir nezaket ayarı reklamı açamaz (lütuf en az 0 gün), o yüzden ayar da gerekmez.
  /// Hata fırlatmaz; ayar okunamazsa güvenli varsayılan kalır.
  Future<void> ayarYukle() async {
    await baslat();
    if (_kapandi || !servis.kullanilabilir || ayarGetir == null) return;
    if (!_ilkGunGecti) return;
    return _ayarOkuma ??= _ayarOku();
  }

  Future<void> _ayarOku() async {
    try {
      _ayar = await ayarGetir!().timeout(const Duration(seconds: 12));
    } catch (_) {
      _ayar = UzakReklamAyari.varsayilan;
    }
    await _ilkAcilisKontrol(); // lütuf süresi uzaktan değişmiş olabilir
    if (!_kapandi) notifyListeners();
  }

  /// Reklam şu an gösterilebilir mi: servis mümkün, uzaktan açık, reklamsız gün değil, [yerlesim] (verilirse)
  /// uzaktan açık ve yeni kullanıcı nezaket süresi bitti.
  Future<bool> gosterilebilir({String? yerlesim}) async {
    if (!servis.kullanilabilir || _kapandi) return false;
    await baslat();
    if (!acik || reklamsizMi) return false;
    // ilk açılış gününde ayar bile okunmaz
    await _ilkAcilisKontrol();
    if (!_ilkGunGecti) return false;
    await ayarYukle();
    if (!acik || reklamsizMi) return false;
    if (yerlesim != null && !_ayar.yerlesimAcik(yerlesim)) return false;
    return _ilkAcilisKontrol();
  }

  // ---- reklamsız gün (ödüllü) ----------------------------------------------------------------------------------

  Future<void> _reklamsizOku() async {
    try {
      final p = await SharedPreferences.getInstance();
      final kayit = p.get(reklamsizBitisAnahtari);
      final b = kayit is String ? DateTime.tryParse(kayit) : null;
      final simdi = _simdi();
      // geçmiş, çözülemeyen ya da (saat oynamasına karşı) 24 saatten uzak gelecekteki kayıt geçersizdir
      if (b == null ||
          !b.isAfter(simdi) ||
          b.isAfter(
              simdi.add(reklamsizGunSuresi + const Duration(minutes: 5)))) {
        return;
      }
      _reklamsizBitisi = b;
      _reklamsizZamaniKur();
    } catch (_) {}
  }

  void _reklamsizZamaniKur() {
    _reklamsizZamani?.cancel();
    final b = _reklamsizBitisi;
    if (b == null || _kapandi) return;
    final kalan = b.difference(_simdi());
    if (kalan <= Duration.zero) {
      _reklamsizBitisi = null;
      return;
    }
    // süre dolunca kartlar geri gelir (dinleyiciler yeniden değerlendirir)
    _reklamsizZamani = Timer(kalan, () {
      _reklamsizBitisi = null;
      if (!_kapandi) notifyListeners();
    });
  }

  /// Ödül kazanıldı: bugünden itibaren [reklamsizGunSuresi] boyunca reklam gösterilmez. Saklama yazılamazsa
  /// bile bu oturumda geçerlidir.
  Future<void> reklamsizBaslat() async {
    final b = _simdi().add(reklamsizGunSuresi);
    _reklamsizBitisi = b;
    _reklamsizZamaniKur();
    // gösterilen kartlar hemen bırakılır, kimsenin göstermediği bellekteki reklamlar serbest kalır
    notifyListeners();
    _fazlayiAt();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(reklamsizBitisAnahtari, b.toIso8601String());
    } catch (_) {}
  }

  /// "Reklamsız gün": rıza/SDK hazırlığından sonra ödüllü reklamı yükleyip gösterir. Ödül yalnızca izleme
  /// tamamlanınca gelir; o zaman reklamsız süre başlar. Ödül gelmezse hiçbir şey değişmez.
  Future<OdulluSonuc> odulluIzle() async {
    if (!odulluAcik) return OdulluSonuc.yuklenemedi;
    try {
      final hazir = await (_hazir ??= _hazirla());
      if (!_kapandi) rizaSurumu.value++;
      if (!hazir) {
        _hazir = null;
        return OdulluSonuc.yuklenemedi;
      }
      final sonuc = await servis.odulluIzle();
      if (sonuc == OdulluSonuc.odul && !_kapandi) await reklamsizBaslat();
      return sonuc;
    } catch (_) {
      return OdulluSonuc.yuklenemedi;
    }
  }

  // ---- yükleme -------------------------------------------------------------------------------------------------

  /// [anahtar] ([anahtarOlustur]) için bir reklam döndürür: bellekte varsa o, yoksa yükler. Yüklenemezse, rıza yoksa,
  /// oturum sınırı dolduysa ya da reklam kapalıysa null. Hata fırlatmaz.
  Future<ReklamNesnesi?> iste(String anahtar, ReklamStili stil) {
    if (!acik || reklamsizMi) return Future.value(null);
    final var_ = _bak(anahtar);
    if (var_ != null) return Future.value(var_);
    final hata = _hatalar[anahtar];
    if (hata != null && _simdi().difference(hata) < reklamHataBeklemesi) {
      return Future.value(null);
    }
    return _devam[anahtar] ??= _yukle(anahtar, stil).whenComplete(() {
      // (blok gövde: remove'un döndürdüğü Future whenComplete'in kendisi olurdu ve sonsuza dek beklerdi)
      _devam.remove(anahtar);
    });
  }

  Future<bool> _hazirla() async {
    try {
      final s = servis;
      if (s is IcerikDerecesiAyarlanabilir) {
        (s as IcerikDerecesiAyarlanabilir).maxIcerik = _ayar.maxIcerik;
      }
      return await servis.hazirla();
    } catch (_) {
      return false;
    }
  }

  Future<ReklamNesnesi?> _yukle(String anahtar, ReklamStili stil) async {
    final nesil = _nesil;
    try {
      final hata = _hazirHatasi;
      if (hata != null && _simdi().difference(hata) < reklamHataBeklemesi) {
        return null;
      }
      final hazir = await (_hazir ??= _hazirla());
      if (!_kapandi) rizaSurumu.value++;
      if (!hazir) {
        // rıza yok / SDK açılamadı: bir süre sonra yeniden denenebilir, o zamana dek hiç istek atılmaz
        _hazir = null;
        _hazirHatasi = _simdi();
        return null;
      }
      if (nesil != _nesil) return null; // hazırlık beklenirken tercih değişti
      if (_kapandi || _yuklemeSayisi >= oturumSiniri) return null;
      _yuklemeSayisi++;
      final nesne = await servis.yukle(stil);
      if (nesne == null) {
        _hatalar[anahtar] = _simdi();
        return null;
      }
      if (_kapandi) {
        nesne.dispose();
        return null;
      }
      if (nesil != _nesil) {
        // yükleme sürerken rıza tercihi değişti: eski rızayla istenen reklam kullanılmaz
        nesne.dispose();
        return null;
      }
      _onbellek[anahtar] = _Kayit(nesne, _simdi());
      _fazlayiAt();
      return nesne;
    } catch (_) {
      _hatalar[anahtar] = _simdi();
      return null;
    }
  }

  ReklamNesnesi? _bak(String anahtar) {
    final kayit = _onbellek[anahtar];
    if (kayit == null) return null;
    final bayat = _simdi().difference(kayit.zaman) >= reklamOmru;
    if (bayat && !_sahipler.containsKey(anahtar)) {
      _at(anahtar);
      return null;
    }
    // en son kullanılan sona
    _onbellek.remove(anahtar);
    _onbellek[anahtar] = kayit;
    return kayit.nesne;
  }

  /// [anahtar]ın reklamı bellekte varsa ve gösterim için hâlâ geçerliyse (55 dk dolmamış ya da şu an biri
  /// gösteriyor) döndürür; süresi dolmuş, kimsenin göstermediği reklamı serbest bırakıp null döner. Yeni
  /// gösterim / sahiplenme yolları [nesne] yerine bunu kullanmalı.
  ReklamNesnesi? taze(String anahtar) => _bak(anahtar);

  void _at(String anahtar) {
    final kayit = _onbellek.remove(anahtar);
    kayit?.nesne.dispose();
  }

  // Sınırı aşan en eski reklamı (kimse göstermiyorsa) serbest bırakır.
  void _fazlayiAt() {
    // reklamsız günde kimsenin göstermediği hiçbir reklam bellekte tutulmaz
    final sinir = reklamsizMi ? 0 : onbellekSiniri;
    while (_onbellek.length > sinir) {
      String? aday;
      for (final k in _onbellek.keys) {
        if (!_sahipler.containsKey(k)) {
          aday = k;
          break;
        }
      }
      if (aday == null) return;
      _at(aday);
    }
  }

  // ---- sahiplik ------------------------------------------------------------------------------------------------

  /// [anahtar]ın reklamını [sahip] göstermek istiyor. Başkası gösteriyorsa ya da reklam bellekte yoksa false.
  bool sahiplen(String anahtar, Object sahip) {
    if (!_onbellek.containsKey(anahtar)) return false;
    final mevcut = _sahipler[anahtar];
    if (mevcut != null && !identical(mevcut, sahip)) return false;
    // süresi dolmuş (55 dk+) ve kimsenin göstermediği reklam yeni gösterime verilmez
    if (mevcut == null && _bak(anahtar) == null) return false;
    _sahipler[anahtar] = sahip;
    return true;
  }

  /// [sahip] reklamı artık göstermiyor. Bekleyen widget'lar haberdar edilir; bellek sınırı yeniden uygulanır.
  void birak(String anahtar, Object sahip) {
    if (!identical(_sahipler[anahtar], sahip)) return;
    _sahipler.remove(anahtar);
    _fazlayiAt();
    // widget ağacı kapanırken çağrılabilir: dinleyiciler (setState) bir sonraki mikro görevde uyarılır
    scheduleMicrotask(() {
      if (!_kapandi) notifyListeners();
    });
  }

  /// Bellekteki reklam (sahiplenmiş olan çizer); yoksa null.
  ReklamNesnesi? nesne(String anahtar) => _onbellek[anahtar]?.nesne;

  // ---- ayarlar -------------------------------------------------------------------------------------------------

  /// Ayarlar > Hakkında'da "Reklam tercihleri" gösterilmeli mi?
  Future<bool> tercihGerekli() async {
    if (!acik) return false;
    try {
      return await servis.tercihGerekli();
    } catch (_) {
      return false;
    }
  }

  /// Rıza tercihleri formunu açar. Form kapanınca rıza değişmiş olabilir: [tercihDegisti] ile hazırlık sonucu
  /// sıfırlanır, bellekteki ve bekleyen reklamlar geçersiz kılınır, bir sonraki istekten önce rıza (canRequestAds)
  /// yeniden kontrol edilir.
  Future<void> tercihleriAc() async {
    try {
      await servis.tercihleriAc();
    } catch (_) {}
    tercihDegisti();
  }

  /// Rıza tercihi değişti (form kapandı ya da rıza bilgisi güncellendi). Hazırlık sonucu ve hata beklemeleri
  /// sıfırlanır; sonraki reklam isteği `hazirla` ile rızayı yeniden denetler (rıza geri alındıysa istek atılmaz).
  /// Bellekteki reklamlar eski rızayla istenmiş olabilir: kimsenin göstermediği reklamlar hemen serbest bırakılır,
  /// gösterilenler bırakılır bırakılmaz (süresi doldu sayılır) ve bekleyen yüklemelerin sonucu atılır.
  void tercihDegisti() {
    if (_kapandi) return;
    _nesil++;
    _hazir = null;
    _hazirHatasi = null;
    _hatalar.clear();
    _devam.clear();
    final eski = DateTime.fromMillisecondsSinceEpoch(0);
    for (final k in _onbellek.keys.toList()) {
      if (_sahipler.containsKey(k)) {
        _onbellek[k]!.zaman = eski; // gösterilen: bırakılınca atılır
      } else {
        _at(k);
      }
    }
    rizaSurumu.value++;
    notifyListeners();
  }

  /// Tüm reklamları serbest bırakır (uygulama / ana sayfa kapanırken).
  @override
  void dispose() {
    if (_kapandi) return;
    _kapandi = true;
    _reklamsizZamani?.cancel();
    rizaSurumu.dispose();
    for (final k in _onbellek.values) {
      k.nesne.dispose();
    }
    _onbellek.clear();
    _sahipler.clear();
    _devam.clear();
    super.dispose();
  }
}
