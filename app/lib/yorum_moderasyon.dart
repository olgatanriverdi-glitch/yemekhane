import 'package:shared_preferences/shared_preferences.dart';

/// Bu cihazda saklanan moderasyon tercihleri: engellenen kişiler (kullanıcı kimlikleri) ve bildirilen / gizlenen
/// yorumlar. Hiçbiri sunucuya gitmez; yalnızca yorumlar listelenirken süzgeç olarak kullanılır.
/// Depolama okunamaz ya da yazılamazsa hata yutulur (bkz. lib/tema.dart): liste boş sayılır.
class YorumModerasyonu {
  static const engellenenAnahtari = 'engellenen_kisiler';
  static const gizlenenAnahtari = 'gizlenen_yorumlar';

  /// Saklanan en fazla kayıt; dolunca en eskiler düşer.
  static const enCok = 500;

  const YorumModerasyonu();

  Future<List<String>> _oku(String anahtar) async {
    try {
      final p = await SharedPreferences.getInstance();
      return List<String>.of(p.getStringList(anahtar) ?? const []);
    } catch (_) {
      return [];
    }
  }

  Future<void> _yaz(String anahtar, List<String> liste) async {
    try {
      final p = await SharedPreferences.getInstance();
      final kesik =
          liste.length > enCok ? liste.sublist(liste.length - enCok) : liste;
      await p.setStringList(anahtar, kesik);
    } catch (_) {}
  }

  Future<Set<String>> engellenenler() async =>
      (await _oku(engellenenAnahtari)).toSet();

  Future<Set<String>> gizlenenYorumlar() async =>
      (await _oku(gizlenenAnahtari)).toSet();

  /// [uid] kişisini engeller (boş kimlik yok sayılır).
  Future<void> engelle(String uid) async {
    if (uid.isEmpty) return;
    final l = await _oku(engellenenAnahtari);
    if (l.contains(uid)) return;
    l.add(uid);
    await _yaz(engellenenAnahtari, l);
  }

  /// Bütün engelleri kaldırır.
  Future<void> engelleriTemizle() => _yaz(engellenenAnahtari, []);

  /// Bildirilen yorumu bu cihazda gizler.
  Future<void> yorumuGizle(String yorumId) async {
    if (yorumId.isEmpty) return;
    final l = await _oku(gizlenenAnahtari);
    if (l.contains(yorumId)) return;
    l.add(yorumId);
    await _yaz(gizlenenAnahtari, l);
  }
}
