import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bildirim_plani.dart';
import 'bildirim_servisi.dart';
import 'models.dart';

/// Günlük menü bildirimi: ayar (açık / saat), izin isteme ve planlamanın yeniden kurulması.
///
/// Varsayılan KAPALIDIR. Ayar cihazda iki anahtarla saklanır: [acikAnahtari] (bool) ve [saatAnahtari] (gün
/// başından itibaren dakika, int; varsayılan [varsayilanBildirimSaatDk] = 10:30). Saklama okunamazsa ya da
/// değerler bozuksa varsayılanla devam edilir. Değişince dinleyenler yenilenir.
///
/// Ayar kapalıyken [servis]e hiçbir çağrı yapılmaz (uygulama açılışında eklenti koduna dokunulmaz). Açıkken ana
/// sayfa menüyü her başarıyla yüklediğinde, favoriler değiştiğinde ve saat değişince [durumuBildir] / [saatSec]
/// önce eski bildirimleri iptal eder, sonra [bildirimPlani] ile yenisini kurar. Bildirim "en iyi çaba"dır:
/// servis hataları yutulur, uygulamayı düşürmez.
class BildirimAyari extends ChangeNotifier {
  static const acikAnahtari = 'bildirim_acik';
  static const saatAnahtari = 'bildirim_saat';

  /// [servis] verilmezse gerçek servis ([FlutterBildirimServisi]) kullanılır; eklenti ilk kullanımda başlar.
  /// [acik] ve [saatDk] testlerde saklama beklenmeden başlangıç değeri vermek içindir; [yukle] yalnızca
  /// saklanmış (geçerli) değerlerin üstüne yazar.
  BildirimAyari(
      {BildirimServisi? servis,
      bool acik = false,
      int saatDk = varsayilanBildirimSaatDk})
      : servis = servis ?? FlutterBildirimServisi(),
        _acik = acik,
        _saatDk = _saatiDuzelt(saatDk);

  final BildirimServisi servis;

  bool _acik;
  int _saatDk;
  Future<void>? _yukleme;
  bool _yuklendi = false;
  bool _kapandi = false;

  // Ana sayfanın bildirdiği son durum: planlama bunlardan kurulur (ayar sonradan açılsa da).
  ({
    Universite uni,
    Menu menu,
    Set<String> favoriler,
    DateTime Function() simdi
  })? _son;
  // Planlama istekleri sırayla çalışır (eski iptali yeni planın üstüne binmesin); arkasından daha yeni bir
  // istek gelmiş olan istek atlanır.
  Future<void> _sira = Future.value();
  int _istekNo = 0;

  bool get acik => _acik;

  /// Bildirim saati (gün başından itibaren dakika).
  int get saatDk => _saatDk;
  bool get yuklendi => _yuklendi;

  static int _saatiDuzelt(int dk) =>
      dk < 0 || dk >= 24 * 60 ? varsayilanBildirimSaatDk : dk;

  /// Kayıtlı ayarı okur (bir kez; sonraki çağrılar aynı işlemi döndürür). Bool olmayan "açık" ile sayı olmayan,
  /// tam sayı olmayan ya da gün dışı bir saat yok sayılır. Servise dokunmaz.
  Future<void> yukle() => _yukleme ??= _oku();

  Future<void> _oku() async {
    try {
      final p = await SharedPreferences.getInstance();
      final a = p.get(acikAnahtari);
      if (a is bool) _acik = a;
      final s = p.get(saatAnahtari);
      if (s is int && s >= 0 && s < 24 * 60) _saatDk = s;
    } catch (_) {
      // saklama kullanılamıyor: varsayılan değerlerle devam
    }
    _yuklendi = true;
    _haber();
  }

  /// Bildirimi açar: önce izin istenir (Android 13+ sistem penceresi). İzin verilirse ayar açılır, kaydedilir ve
  /// bilinen menüyle plan kurulur; true döner. İzin verilmezse (ya da istek hata verirse) ayar kapalı kalır
  /// ve false döner. Zaten açıksa hiçbir şey yapmaz, true döner.
  Future<bool> ac() async {
    if (!_yuklendi) await yukle();
    if (_acik) return true;
    bool izin;
    try {
      izin = await servis.izinIste();
    } catch (_) {
      izin = false;
    }
    if (!izin) return false;
    _acik = true;
    _haber();
    await _kaydet(acikAnahtari, true);
    await _planla();
    return true;
  }

  /// Bildirimi kapatır ve kurulmuş bütün bildirimleri iptal eder.
  Future<void> kapat() async {
    if (!_yuklendi) await yukle();
    if (!_acik) return;
    _acik = false;
    _haber();
    await _kaydet(acikAnahtari, false);
    // kuyruktaki planlar atlansın; iptal sıradaki işlerden sonra çalışsın
    _istekNo++;
    await (_sira = _sira.then((_) async {
      try {
        await servis.hepsiniIptal();
      } catch (_) {
        // iptal edilemese de ayar kapalı kalır
      }
    }));
  }

  /// Bildirim saatini seçer (gün başından itibaren dakika; gün dışı değer yok sayılır). Kaydedilir; ayar
  /// açıksa bildirimler yeni saatle yeniden kurulur.
  Future<void> saatSec(int dk) async {
    if (!_yuklendi) await yukle();
    if (dk < 0 || dk >= 24 * 60 || dk == _saatDk) return;
    _saatDk = dk;
    _haber();
    await _kaydet(saatAnahtari, dk);
    if (_acik) await _planla();
  }

  /// Ana sayfanın son durumu: ekrandaki okul ve menü, favori yemek anahtarları ve saat kaynağı ([simdi],
  /// [turkiyeSimdi] ya da testlerde sabit saat). Menü başarıyla yüklenince ve favoriler değişince çağrılır.
  /// Ayar kapalıysa yalnızca durum saklanır, servise dokunulmaz; açıksa bildirimler yeniden kurulur.
  Future<void> durumuBildir(Universite uni, Menu menu, Set<String> favoriler,
      DateTime Function() simdi) async {
    _son = (uni: uni, menu: menu, favoriler: {...favoriler}, simdi: simdi);
    if (!_yuklendi) await yukle();
    if (_acik) await _planla();
  }

  /// Favori yemekler değişti ([FavoriDeposu.anahtarlar]). Ana sayfa henüz bir menü bildirmediyse ya da
  /// favoriler [durumuBildir]deki gibiyse (örn. başlangıçta boş listenin yüklenmesi) hiçbir şey yapmaz;
  /// değiştiyse ve ayar açıksa bildirimler yeni favorilerle yeniden kurulur.
  Future<void> favorileriBildir(Set<String> favoriler) async {
    final son = _son;
    if (son == null || setEquals(son.favoriler, favoriler)) return;
    _son = (
      uni: son.uni,
      menu: son.menu,
      favoriler: {...favoriler},
      simdi: son.simdi
    );
    if (!_yuklendi) await yukle();
    if (_acik) await _planla();
  }

  /// Planı yeniden kurar: önce eskiler iptal edilir, sonra yenisi planlanır. Sıraya girer; arkasından daha yeni
  /// bir istek gelirse bu atlanır (son durum zaten yenisindedir). Hata fırlatmaz.
  Future<void> _planla() {
    final no = ++_istekNo;
    return _sira = _sira.then((_) => _planlaIc(no));
  }

  Future<void> _planlaIc(int no) async {
    final son = _son;
    if (no != _istekNo || !_acik || son == null) return;
    List<PlanliBildirim> plan;
    try {
      plan = bildirimPlani(
          menu: son.menu,
          uni: son.uni,
          saatDk: _saatDk,
          simdi: son.simdi(),
          favoriler: son.favoriler);
    } catch (_) {
      return;
    }
    // iptal başarısız olsa da yeni plan denenir (kimlikler tarihten türediği için eskinin yerine geçer)
    try {
      await servis.hepsiniIptal();
    } catch (_) {}
    try {
      await servis.planla(plan);
    } catch (_) {
      // bildirim kurulamadıysa sonraki yüklemede yeniden denenir
    }
  }

  Future<void> _kaydet(String anahtar, Object deger) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (deger is bool) {
        await p.setBool(anahtar, deger);
      } else if (deger is int) {
        await p.setInt(anahtar, deger);
      }
    } catch (_) {
      // kaydedilemese de bu oturumda geçerli kalır
    }
  }

  void _haber() {
    if (!_kapandi) notifyListeners();
  }

  @override
  void dispose() {
    _kapandi = true;
    super.dispose();
  }
}
