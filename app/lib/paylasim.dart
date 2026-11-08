import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

/// Metni sistemin paylaşım sayfasıyla paylaşan servis. Uygulama yalnızca bu arayüzü bilir; gerçek
/// uygulama [SharePlusServisi]ni kullanır, testlerde sahtesi verilir. Paylaşım açılamıyorsa
/// (desteksiz platform, eklenti hatası) istisna fırlatılır; çağıran ([metniPaylas]) metni panoya kopyalar.
abstract class PaylasimServisi {
  /// [metin]i paylaşır. [konu], paylaşılan uygulama e-postaysa konu satırı olarak kullanılır.
  Future<void> paylas(String metin, {String? konu});
}

/// `share_plus` ile gerçek paylaşım sayfasını açar (Android: ACTION_SEND, iOS: UIActivityViewController).
class SharePlusServisi implements PaylasimServisi {
  const SharePlusServisi();

  @override
  Future<void> paylas(String metin, {String? konu}) async {
    // sonuç (paylaşıldı / vazgeçildi) bilgi içindir: vazgeçmek hata sayılmaz
    await SharePlus.instance.share(ShareParams(text: metin, subject: konu));
  }
}

/// [metin]i panoya kopyalar ve kısa bir bildirim gösterir: başarıda [basari], pano da çalışmazsa
/// "Panoya kopyalanamadı". [bildirim] async boşluktan sonra güvenle kullanılabilsin diye
/// `ScaffoldMessenger.of(context)` ile önceden alınır.
Future<void> metniKopyala(ScaffoldMessengerState bildirim, String metin,
    {String basari = 'Menü panoya kopyalandı'}) async {
  String mesaj;
  try {
    await Clipboard.setData(ClipboardData(text: metin));
    mesaj = basari;
  } catch (_) {
    mesaj = 'Panoya kopyalanamadı';
  }
  if (!bildirim.mounted) return;
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mesaj)));
}

/// [metin]i [servis] ile paylaşır. Paylaşım açılamazsa (hata ya da desteksiz platform) metin panoya
/// kopyalanır ve bildirim gösterilir; böylece kullanıcı yine de menüyü yapıştırabilir.
Future<void> metniPaylas(
    ScaffoldMessengerState bildirim, PaylasimServisi servis, String metin,
    {String? konu}) async {
  try {
    await servis.paylas(metin, konu: konu);
  } catch (_) {
    await metniKopyala(bildirim, metin,
        basari: 'Paylaşım açılamadı, menü panoya kopyalandı');
  }
}
