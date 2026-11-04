import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Favori bir yemek: okuldan bağımsız kimliği ([anahtar], YemekOgesi.anahtar) ve adı.
class Favori {
  final String anahtar, ad;
  const Favori(this.anahtar, this.ad);
}

/// Favori yemekler. Cihazda 'favori_yemekler' anahtarında {anahtar: ad} JSON'u olarak saklanır;
/// okuldan bağımsızdır (aynı yemek hangi okulda çıkarsa çıksın eşleşir). Değişince dinleyenler yenilenir.
class FavoriDeposu extends ChangeNotifier {
  static const prefsAnahtari = 'favori_yemekler';

  /// Saklanabilecek en çok favori sayısı.
  static const enCok = 200;

  // ekleme sırasıyla (Dart Map sıralıdır): en yeni sonda
  final Map<String, String> _yemekler = {};
  Future<void>? _yukleme;
  bool _yuklendi = false;
  bool _kapandi = false;

  bool get yuklendi => _yuklendi;
  int get sayi => _yemekler.length;
  bool varMi(String anahtar) => _yemekler.containsKey(anahtar);

  /// Favori anahtarları (menü eşleştirmesi için).
  Set<String> get anahtarlar => _yemekler.keys.toSet();

  /// Favoriler, en son eklenen başta.
  List<Favori> get liste => [
        for (final e in _yemekler.entries.toList().reversed)
          Favori(e.key, e.value)
      ];

  /// Kayıtlı favorileri okur (bir kez; sonraki çağrılar aynı işlemi döndürür). Kayıt bozuksa ya da
  /// okunamazsa liste boş başlar; bozuk tek bir öğe diğerlerini düşürmez.
  Future<void> yukle() => _yukleme ??= _oku();

  Future<void> _oku() async {
    final okunan = <String, String>{};
    try {
      final p = await SharedPreferences.getInstance();
      final ham = p.getString(prefsAnahtari);
      final j = ham == null ? null : jsonDecode(ham);
      if (j is Map) {
        j.forEach((k, v) {
          if (k is String && k.isNotEmpty && v is String && v.isNotEmpty) {
            okunan[k] = v;
          }
        });
      }
    } catch (_) {
      // bozuk JSON ya da saklama kullanılamıyor: boş liste
    }
    final fazla = okunan.length - enCok;
    _yemekler
      ..clear()
      ..addEntries(okunan.entries.skip(fazla > 0 ? fazla : 0));
    _yuklendi = true;
    _haber();
  }

  /// Favorilere ekler. Zaten ekliyse true döner. [enCok] doluysa eklemez ve false döner.
  Future<bool> ekle(String anahtar, String ad) async {
    if (!_yuklendi) await yukle();
    if (_yemekler.containsKey(anahtar)) return true;
    if (_yemekler.length >= enCok) return false;
    _yemekler[anahtar] = ad;
    _haber();
    await _kaydet();
    return true;
  }

  Future<void> cikar(String anahtar) async {
    if (!_yuklendi) await yukle();
    if (_yemekler.remove(anahtar) == null) return;
    _haber();
    await _kaydet();
  }

  /// Kalp düğmesi: varsa çıkarır, yoksa ekler. Yalnızca limit yüzünden eklenemediyse false döner.
  Future<bool> degistir(String anahtar, String ad) async {
    if (!_yuklendi) await yukle();
    if (varMi(anahtar)) {
      await cikar(anahtar);
      return true;
    }
    return ekle(anahtar, ad);
  }

  Future<void> _kaydet() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(prefsAnahtari, jsonEncode(_yemekler));
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

/// "Bugün", "Yarın" ya da gün adı ("Cuma"); [tamTarih] ise gün adına tarih de eklenir ("Cuma 6 Kasım").
String favoriGunEtiketi(String tarih, String bugun, {bool tamTarih = false}) {
  final d = DateTime.tryParse(tarih), b = DateTime.tryParse(bugun);
  if (d == null || b == null) return tarih;
  final fark = DateTime.utc(d.year, d.month, d.day)
      .difference(DateTime.utc(b.year, b.month, b.day))
      .inDays;
  if (fark == 0) return 'Bugün';
  if (fark == 1) return 'Yarın';
  final gun = gunAdlari[d.weekday - 1];
  return tamTarih ? '$gun ${d.day} ${ayAdlari[d.month - 1]}' : gun;
}

/// Kalp (favori) düğmesinin ekran okuyucu etiketi: hangi yemekten söz edildiği de duyulsun diye yemek adını
/// içerir ("Mantı: favorilere ekle"). [favori] true ise yemek zaten favoridir ve düğme çıkarır.
/// Görsel ipucu (tooltip) metni değişmez: "Favorilere ekle" / "Favorilerden çıkar".
String favoriDugmeEtiketi(String yemekAdi, {required bool favori}) =>
    '${yemekAdi.trim()}: ${favori ? 'favorilerden çıkar' : 'favorilere ekle'}';
