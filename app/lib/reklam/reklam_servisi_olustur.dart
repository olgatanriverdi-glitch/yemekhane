// Web'de (dart:io yok) Google Mobile Ads hiç derlenmez; mobilde gerçek servis kullanılır.
export 'gercek_reklam_yok.dart'
    if (dart.library.io) 'gercek_reklam_servisi.dart';
