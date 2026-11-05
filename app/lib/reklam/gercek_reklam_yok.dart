import 'reklam_servisi.dart';

/// Web derlemesi: Google Mobile Ads içeri alınmaz, reklam tamamen kapalıdır.
ReklamServisi gercekReklamServisiOlustur() => const KapaliReklamServisi();
