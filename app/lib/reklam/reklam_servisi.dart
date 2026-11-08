import 'package:flutter/widgets.dart';

import 'reklam_ayari.dart';

/// Yüklenmiş tek bir reklam. Aynı nesne ağaçta aynı anda en çok bir yerde durabilir (bkz. ReklamYoneticisi).
abstract class ReklamNesnesi {
  /// Reklamı çizen widget (yerel reklam şablonu).
  Widget olustur(BuildContext context);

  /// Platform kaynaklarını serbest bırakır; sonra [olustur] çağrılmamalıdır.
  void dispose();
}

/// Ödüllü reklam ("Reklamsız gün") denemesinin sonucu.
enum OdulluSonuc {
  /// İzleme tamamlandı, ödül kazanıldı.
  odul,

  /// Reklam yüklenemedi ya da gösterilemedi (ödül yok).
  yuklenemedi,

  /// Kullanıcı ödül gelmeden kapattı (ödül yok).
  kapatildi,
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

  /// Ödüllü reklam (Reklamsız gün) bu derlemede mümkün mü? false ise özellik gizlenir (kimliksiz release, web).
  bool get odulluKullanilabilir;

  /// Ödüllü bir reklam yükler ve gösterir. Ödül yalnızca izleme tamamlanınca ([OdulluSonuc.odul]) verilir.
  /// Hata fırlatmaz. Rıza ve SDK hazırlığı çağıran tarafından ([hazirla]) yapılmış olmalıdır.
  Future<OdulluSonuc> odulluIzle();

  /// Ayarlar > Hakkında'da "Reklam tercihleri" gösterilmeli mi (AB / Birleşik Krallık gibi yerlerde zorunlu)?
  Future<bool> tercihGerekli();

  /// Rıza tercihleri formunu açar.
  Future<void> tercihleriAc();
}

/// İstenen reklamların içerik derecesi uzaktan ayarlanabilen servisler bunu uygular (bkz. `UzakReklamAyari.maxIcerik`).
/// Yönetici [hazirla]dan önce değeri verir; geçersiz değer 'G' sayılır.
abstract interface class IcerikDerecesiAyarlanabilir {
  set maxIcerik(String derece);
}

/// Reklamın kapalı olduğu yerlerde (web, kimliksiz release) kullanılan servis: hiçbir şey yapmaz.
class KapaliReklamServisi implements ReklamServisi {
  const KapaliReklamServisi();
  @override
  bool get kullanilabilir => false;
  @override
  bool get odulluKullanilabilir => false;
  @override
  Future<OdulluSonuc> odulluIzle() async => OdulluSonuc.yuklenemedi;
  @override
  Future<bool> hazirla() async => false;
  @override
  Future<ReklamNesnesi?> yukle(ReklamStili stil) async => null;
  @override
  Future<bool> tercihGerekli() async => false;
  @override
  Future<void> tercihleriAc() async {}
}
