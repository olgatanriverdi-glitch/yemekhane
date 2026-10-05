import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seçilebilir vurgu rengi (Material 3 tohum rengi); tüm renk şeması bundan türetilir.
class TemaRengi {
  final String kimlik;
  final String ad;
  final Color renk;
  const TemaRengi(this.kimlik, this.ad, this.renk);
}

/// İlk renk varsayılandır (uygulamanın ilk günden beri kullandığı turuncu).
const List<TemaRengi> temaRenkleri = [
  TemaRengi('turuncu', 'Turuncu', Color(0xFFE8892B)),
  TemaRengi('kirmizi', 'Kırmızı', Color(0xFFD64545)),
  TemaRengi('pembe', 'Pembe', Color(0xFFD9548F)),
  TemaRengi('mor', 'Mor', Color(0xFF7A5BD0)),
  TemaRengi('mavi', 'Mavi', Color(0xFF3B82D6)),
  TemaRengi('turkuaz', 'Turkuaz', Color(0xFF1FA39B)),
  TemaRengi('yesil', 'Yeşil', Color(0xFF4C9A4F)),
];

const Map<String, ThemeMode> _modlar = {
  'sistem': ThemeMode.system,
  'acik': ThemeMode.light,
  'koyu': ThemeMode.dark,
};

/// Kullanıcının görünüm seçimi: açık/koyu/sistem modu ve vurgu rengi. Cihazda saklanır; değişince dinleyenler (MaterialApp) yenilenir.
class TemaAyari extends ChangeNotifier {
  static const modAnahtari = 'tema_mod';
  static const renkAnahtari = 'tema_renk';

  ThemeMode _mod;
  TemaRengi _renk;

  TemaAyari({ThemeMode mod = ThemeMode.system, TemaRengi? renk})
      : _mod = mod,
        _renk = renk ?? temaRenkleri.first;

  ThemeMode get mod => _mod;
  TemaRengi get renk => _renk;

  /// Kayıtlı seçimi okur; hiç kayıt yoksa ya da değer tanınmıyorsa varsayılan (sistem modu, turuncu) kalır.
  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      _mod = _modlar[p.getString(modAnahtari)] ?? ThemeMode.system;
      final kimlik = p.getString(renkAnahtari);
      _renk = temaRenkleri.firstWhere((r) => r.kimlik == kimlik,
          orElse: () => temaRenkleri.first);
    } catch (_) {
      // saklama kullanılamıyorsa varsayılanla devam
    }
    notifyListeners();
  }

  /// Seçim hemen uygulanır; kaydetme arkadan gelir (kaydedilemese de görünüm değişir).
  Future<void> modSec(ThemeMode mod) async {
    if (mod == _mod) return;
    _mod = mod;
    notifyListeners();
    await _kaydet(
        modAnahtari, _modlar.entries.firstWhere((e) => e.value == mod).key);
  }

  Future<void> renkSec(TemaRengi renk) async {
    if (renk.kimlik == _renk.kimlik) return;
    _renk = renk;
    notifyListeners();
    await _kaydet(renkAnahtari, renk.kimlik);
  }

  Future<void> _kaydet(String anahtar, String deger) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(anahtar, deger);
    } catch (_) {}
  }

  ThemeData tema(Brightness parlaklik) => ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(seedColor: _renk.renk, brightness: parlaklik),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );
}
