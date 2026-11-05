import 'package:flutter/widgets.dart';

import 'reklam_ayari.dart';

/// Yüklenmiş tek bir reklam. Aynı nesne ağaçta aynı anda en çok bir yerde durabilir (bkz. ReklamYoneticisi).
abstract class ReklamNesnesi {
  /// Reklamı çizen widget (yerel reklam şablonu).
  Widget olustur(BuildContext context);

  /// Platform kaynaklarını serbest bırakır; sonra [olustur] çağrılmamalıdır.
  void dispose();
}

/// Reklam SDK'sının arkasındaki soyutlama. Gerçek uygulama Google Mobile Ads'i, testler sahte servisi kullanır;
/// testte platform kanalına hiç dokunulmaz.
abstract class ReklamServisi {
  /// Bu derlemede ve platformda reklam mümkün mü? false ise (web, kimliksiz release...) hiçbir çağrı yapılmaz,
  /// SDK başlatılmaz.
  bool get kullanilabilir;

  /// Rıza bilgisini günceller (gerekirse Google'ın rıza formu gösterilir) ve SDK'yı başlatır. Reklam isteği
  /// atılabilirse true. Hatalar yutulur: false döner.
  Future<bool> hazirla();

  /// Verilen görünümle bir yerel reklam yükler; yüklenemezse null (hata fırlatmaz).
  Future<ReklamNesnesi?> yukle(ReklamStili stil);

  /// Ayarlar > Hakkında'da "Reklam tercihleri" gösterilmeli mi (AB / Birleşik Krallık gibi yerlerde zorunlu)?
  Future<bool> tercihGerekli();

  /// Rıza tercihleri formunu açar.
  Future<void> tercihleriAc();
}

/// Reklamın kapalı olduğu yerlerde (web, kimliksiz release) kullanılan servis: hiçbir şey yapmaz.
class KapaliReklamServisi implements ReklamServisi {
  const KapaliReklamServisi();
  @override
  bool get kullanilabilir => false;
  @override
  Future<bool> hazirla() async => false;
  @override
  Future<ReklamNesnesi?> yukle(ReklamStili stil) async => null;
  @override
  Future<bool> tercihGerekli() async => false;
  @override
  Future<void> tercihleriAc() async {}
}
