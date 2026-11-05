import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'reklam_ayari.dart';
import 'reklam_servisi.dart';

class _Kayit {
  _Kayit(this.nesne, this.zaman);
  final ReklamNesnesi nesne;
  final DateTime zaman;
}

/// Reklamların yaşam döngüsü: ne zaman istek atılır, kaç reklam bellekte tutulur, hangi widget hangisini gösterir.
///
/// - Yeni kullanıcıya nezaket: [gosterilebilir] ilk açılıştan sonraki 3 gün false döner ([reklamsizSureBitti]).
/// - Oturum sınırı: en çok [oturumSiniri] yükleme; sonrası yalnızca bellektekiler yeniden kullanılır.
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
      this.oturumSiniri = oturumYuklemeSiniri,
      this.onbellekSiniri = reklamOnbellekSiniri})
      : _simdi = simdi ?? turkiyeSimdi;

  final ReklamServisi servis;
  final DateTime Function() _simdi;

  /// Aynı gün + öğünde istek atmadan önce beklenen süre.
  final Duration bekleme;
  final int oturumSiniri;
  final int onbellekSiniri;

  // ekleme sırası = kullanım sırası (en eski başta)
  final Map<String, _Kayit> _onbellek = {};
  final Map<String, Future<ReklamNesnesi?>> _devam = {};
  final Map<String, DateTime> _hatalar = {};
  final Map<String, Object> _sahipler = {};
  Future<bool>? _hazir;
  DateTime? _hazirHatasi;
  int _yuklemeSayisi = 0;
  bool _kapandi = false;

  /// Reklam bu derlemede ve platformda mümkün mü?
  bool get acik => !_kapandi && servis.kullanilabilir;

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
        return false;
      }
      return reklamsizSureBitti(kayit, simdi);
    } catch (_) {
      return false;
    }
  }

  /// İlk açılış gününü saklar (reklam kapalı olsa da; sonradan açılırsa nezaket süresi doğru işlesin).
  Future<void> ilkAcilisiKaydet() => _ilkAcilisKontrol();

  /// Reklam şu an gösterilebilir mi: servis mümkün ve yeni kullanıcı nezaket süresi bitti.
  Future<bool> gosterilebilir() async {
    if (!acik) return false;
    return _ilkAcilisKontrol();
  }

  // ---- yükleme -------------------------------------------------------------------------------------------------

  /// [anahtar] ([anahtarOlustur]) için bir reklam döndürür: bellekte varsa o, yoksa yükler. Yüklenemezse, rıza yoksa,
  /// oturum sınırı dolduysa ya da reklam kapalıysa null. Hata fırlatmaz.
  Future<ReklamNesnesi?> iste(String anahtar, ReklamStili stil) {
    if (!acik) return Future.value(null);
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
      return await servis.hazirla();
    } catch (_) {
      return false;
    }
  }

  Future<ReklamNesnesi?> _yukle(String anahtar, ReklamStili stil) async {
    try {
      final hata = _hazirHatasi;
      if (hata != null && _simdi().difference(hata) < reklamHataBeklemesi) {
        return null;
      }
      final hazir = await (_hazir ??= _hazirla());
      if (!hazir) {
        // rıza yok / SDK açılamadı: bir süre sonra yeniden denenebilir, o zamana dek hiç istek atılmaz
        _hazir = null;
        _hazirHatasi = _simdi();
        return null;
      }
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

  void _at(String anahtar) {
    final kayit = _onbellek.remove(anahtar);
    kayit?.nesne.dispose();
  }

  // Sınırı aşan en eski reklamı (kimse göstermiyorsa) serbest bırakır.
  void _fazlayiAt() {
    while (_onbellek.length > onbellekSiniri) {
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

  Future<void> tercihleriAc() async {
    try {
      await servis.tercihleriAc();
    } catch (_) {}
  }

  /// Tüm reklamları serbest bırakır (uygulama / ana sayfa kapanırken).
  @override
  void dispose() {
    if (_kapandi) return;
    _kapandi = true;
    for (final k in _onbellek.values) {
      k.nesne.dispose();
    }
    _onbellek.clear();
    _sahipler.clear();
    _devam.clear();
    super.dispose();
  }
}
