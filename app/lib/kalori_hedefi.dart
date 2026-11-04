import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Günlük kalori hedefi ayarı (Ayarlar'dan açılır, varsayılan kapalı). Açıkken öğün kartında öğünün hedefe
/// oranı gösterilir. Cihazda iki anahtarla saklanır: [acikAnahtari] (bool) ve [hedefAnahtari] (kkal, int).
/// Değişince dinleyenler yenilenir. Saklama okunamazsa ya da değerler bozuksa varsayılanla (kapalı, [varsayilan])
/// devam edilir; kaydedilemese de değişiklik o oturumda geçerli kalır.
class KaloriHedefi extends ChangeNotifier {
  static const acikAnahtari = 'kalori_hedefi_acik';
  static const hedefAnahtari = 'kalori_hedefi';

  /// Seçilebilen en küçük / en büyük hedef (kkal) ve ayar adımı.
  static const enAz = 1200;
  static const enCok = 4000;
  static const adim = 50;

  /// [enAz] ile [enCok] arasındaki adım sayısı (kaydırıcının bölme sayısı).
  static const adimSayisi = (enCok - enAz) ~/ adim;

  /// Hedef ilk kez açılırken önerilen değer; saklanan değer yoksa ya da bozuksa bu kullanılır.
  static const varsayilan = 2000;

  bool _acik;
  int _hedef;
  Future<void>? _yukleme;
  bool _yuklendi = false;
  bool _kapandi = false;

  /// [acik] ve [hedef] testlerde ya da saklama beklenmeden başlangıç değeri vermek içindir; [yukle] yalnızca
  /// saklanmış (geçerli) değerlerin üstüne yazar.
  KaloriHedefi({bool acik = false, int hedef = varsayilan})
      : _acik = acik,
        _hedef = hedefiDuzelt(hedef);

  bool get acik => _acik;

  /// Günlük hedef (kkal); kapalıyken de seçili değeri tutar.
  int get hedef => _hedef;
  bool get yuklendi => _yuklendi;

  /// [deger]i [enAz]-[enCok] aralığına çeker ve [adim] katına yuvarlar (1234 -> 1250, 99999 -> 4000).
  static int hedefiDuzelt(int deger) {
    final k = deger.clamp(enAz, enCok);
    return enAz + ((k - enAz) / adim).round() * adim;
  }

  /// Kayıtlı değerleri okur (bir kez; sonraki çağrılar aynı işlemi döndürür). Sayı olmayan ya da sonsuz /
  /// NaN bir hedef ile bool olmayan bir "açık" değeri yok sayılır.
  Future<void> yukle() => _yukleme ??= _oku();

  Future<void> _oku() async {
    try {
      final p = await SharedPreferences.getInstance();
      final a = p.get(acikAnahtari);
      if (a is bool) _acik = a;
      final h = p.get(hedefAnahtari);
      if (h is num && h.isFinite) {
        _hedef = hedefiDuzelt(h.clamp(enAz, enCok).round());
      }
    } catch (_) {
      // saklama kullanılamıyor: varsayılan değerlerle devam
    }
    _yuklendi = true;
    _haber();
  }

  /// Hedefi açar / kapatır. Hemen uygulanır; kaydetme arkadan gelir.
  Future<void> acikSec(bool deger) async {
    if (!_yuklendi) await yukle();
    if (deger == _acik) return;
    _acik = deger;
    _haber();
    await _kaydet(acikAnahtari, deger);
  }

  /// Hedefi seçer: [enAz]-[enCok] aralığına çekilir, [adim] katına yuvarlanır. Hemen uygulanır.
  Future<void> hedefSec(int kkal) async {
    if (!_yuklendi) await yukle();
    final yeni = hedefiDuzelt(kkal);
    if (yeni == _hedef) return;
    _hedef = yeni;
    _haber();
    await _kaydet(hedefAnahtari, yeni);
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

/// Yüzde gösteriminin üst sınırı (anlamsız büyük değerler "%999" olarak kalır).
const kaloriYuzdeSiniri = 999;

/// [kcal]'nin [hedef]e oranı, yüzde olarak (en yakın tam sayı). [kcal] ya da [hedef] pozitif değilse 0.
int kaloriYuzdesi(int kcal, int hedef) {
  if (kcal <= 0 || hedef <= 0) return 0;
  return (kcal * 100 / hedef).round();
}

// "%37'si" ekleri: son okunan sözcüğün (yedi, otuz, yüz...) son ünlüsüne ve son harfine göre -(s)I iyelik eki.
const _birlerEki = {
  1: 'i', // bir
  2: 'si', // iki
  3: 'ü', // üç
  4: 'ü', // dört
  5: 'i', // beş
  6: 'sı', // altı
  7: 'si', // yedi
  8: 'i', // sekiz
  9: 'u', // dokuz
};
const _onlarEki = {
  1: 'u', // on
  2: 'si', // yirmi
  3: 'u', // otuz
  4: 'ı', // kırk
  5: 'si', // elli
  6: 'ı', // altmış
  7: 'i', // yetmiş
  8: 'i', // seksen
  9: 'ı', // doksan
};

/// Yüzde sayısına gelen iyelik eki: 37 -> 'si' (otuz yedi-si), 40 -> 'ı' (kırk-ı), 100 -> 'ü' (yüz-ü).
/// Sayının okunuşundaki son sözcüğe bakılır; 0-[kaloriYuzdeSiniri] için doğrudur (binler yok sayılır).
String yuzdeIyelikEki(int n) {
  final a = n.abs();
  if (a == 0) return 'ı'; // sıfır
  if (a % 10 != 0) return _birlerEki[a % 10]!;
  if (a % 100 != 0) return _onlarEki[a ~/ 10 % 10]!;
  return 'ü'; // yüz
}

/// "Bu öğün günlük hedefinin %37'si": [kcal]'lik öğünün [hedef]e oranı.
String kaloriYuzdeMetni(int kcal, int hedef) {
  final y = kaloriYuzdesi(kcal, hedef).clamp(0, kaloriYuzdeSiniri);
  return "Bu öğün günlük hedefinin %$y'${yuzdeIyelikEki(y)}";
}

/// Günün öğle + akşam toplam kalorisi. İki öğünün de dolu ve kalorili olması gerekir; biri yoksa, boşsa ya da
/// kalorisizse null (eksik toplam yanıltıcı olur).
int? ogleAksamKalorisi(Map<String, Ogun> gun) {
  final ogle = gun['lunch'], aksam = gun['dinner'];
  if (ogle == null || aksam == null || ogle.bos || aksam.bos) return null;
  final o = ogle.kcal, a = aksam.kcal;
  if (o == null || a == null || o <= 0 || a <= 0) return null;
  return o + a;
}
