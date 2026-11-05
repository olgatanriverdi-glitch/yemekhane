import 'dart:async';

import 'reklam_servisi.dart';

/// Tek bir reklam yüklemesinin sonucunu ve zaman aşımını yönetir (platformdan bağımsız, testlenebilir).
///
/// Zaman aşımında reklam nesnesi serbest BIRAKILMAZ: google_mobile_ads, dispose edilen reklamın sonradan gelen
/// onAdLoaded olayını Dart tarafında düşürür ve Android'de geç yüklenen yerel reklam kimsenin sahip olmadığı bir
/// nesne olarak kalır (9.2.0 kaynağında bu yolu temizleyen kod yok). Bu yüzden nesne canlı tutulur; geç gelen
/// başarı [yuklendi] içinde, geç gelen hata dinleyicide dispose edilir.
class GecYuklemeKorumasi {
  final Completer<ReklamNesnesi?> _sonuc = Completer<ReklamNesnesi?>();
  bool _zamanAsimi = false;

  /// Zaman aşımı bu yükleme için doldu mu?
  bool get zamanAsimiOldu => _zamanAsimi;

  /// Yükleme başarıyla bitti. Beklenen süre geçmişse (ya da sonuç zaten verilmişse) reklam hemen serbest bırakılır.
  void yuklendi(ReklamNesnesi nesne) {
    if (_zamanAsimi || _sonuc.isCompleted) {
      nesne.dispose();
      return;
    }
    _sonuc.complete(nesne);
  }

  /// Yükleme başarısız ya da hiç başlayamadı.
  void basarisiz() {
    if (!_sonuc.isCompleted) _sonuc.complete(null);
  }

  /// En çok [sure] bekler; dolarsa null döner ve sonradan gelen başarılı reklam [yuklendi] içinde serbest kalır.
  Future<ReklamNesnesi?> bekle(Duration sure) =>
      _sonuc.future.timeout(sure, onTimeout: () {
        _zamanAsimi = true;
        return null;
      });
}
