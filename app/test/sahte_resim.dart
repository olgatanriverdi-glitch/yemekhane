import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

// Testlerde ağsız sahte fotoğraf sağlayıcıları (flutter test bu dosyayı kendi başına çalıştırmaz).

/// Hazır bir [ui.Image]'i eşzamanlı veren sahte fotoğraf: önbellekten hemen gelen görüntüyü taklit eder.
class HazirResim extends ImageProvider<HazirResim> {
  final ui.Image resim;
  HazirResim(this.resim);

  @override
  Future<HazirResim> obtainKey(ImageConfiguration c) =>
      SynchronousFuture<HazirResim>(this);

  @override
  ImageStreamCompleter loadImage(HazirResim key, ImageDecoderCallback d) =>
      OneFrameImageStreamCompleter(
          SynchronousFuture<ImageInfo>(ImageInfo(image: resim.clone())));
}

/// Yüklenemeyen fotoğraf.
class BozukResim extends ImageProvider<BozukResim> {
  @override
  Future<BozukResim> obtainKey(ImageConfiguration c) =>
      SynchronousFuture<BozukResim>(this);

  @override
  ImageStreamCompleter loadImage(BozukResim key, ImageDecoderCallback d) =>
      OneFrameImageStreamCompleter(
          Future<ImageInfo>.error(StateError('fotoğraf yüklenemedi')));
}

/// Elle tamamlanan fotoğraf: [tamamla] ya da [hata] çağrılana kadar yükleniyor görünür (ağdan gelen yüksek
/// çözünürlüklü fotoğrafı taklit eder).
class GecikmeliResim extends ImageProvider<GecikmeliResim> {
  final Completer<ImageInfo> _tamamlayici = Completer<ImageInfo>();

  /// Fotoğrafın yüklenmesini bitirir.
  void tamamla(ui.Image resim) =>
      _tamamlayici.complete(ImageInfo(image: resim.clone()));

  /// Yüklemeyi hatayla bitirir.
  void hata() => _tamamlayici.completeError(StateError('fotoğraf yüklenemedi'));

  @override
  Future<GecikmeliResim> obtainKey(ImageConfiguration c) =>
      SynchronousFuture<GecikmeliResim>(this);

  @override
  ImageStreamCompleter loadImage(GecikmeliResim key, ImageDecoderCallback d) =>
      OneFrameImageStreamCompleter(_tamamlayici.future);
}
