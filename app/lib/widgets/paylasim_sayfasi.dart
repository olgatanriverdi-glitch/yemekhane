import 'package:flutter/material.dart';

import '../hafta.dart';
import '../models.dart';
import '../paylas.dart';
import '../paylasim.dart';
import 'ogun_bilgi.dart';

/// Üst çubuktaki "Paylaş" eyleminin alt sayfasını açar: seçili günün / öğünün menüsünü paylaş ya da kopyala.
/// [gun] seçili günün öğünleri (menüde yoksa boş), [ogun] seçili öğün türüdür.
Future<void> paylasimSayfasiGoster(BuildContext context,
    {required PaylasimServisi servis,
    required Universite uni,
    required String tarih,
    required Map<String, Ogun> gun,
    required String ogun}) {
  // sayfa kapandıktan sonra da bildirim gösterilebilsin diye önceden alınır
  final bildirim = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PaylasimSayfasi(
        bildirim: bildirim,
        servis: servis,
        uni: uni,
        tarih: tarih,
        gun: gun,
        ogun: ogun),
  );
}

/// "Bu öğünü paylaş", "Günün menüsünü paylaş" ve "Panoya kopyala" satırları. Paylaşılacak bir şey yoksa
/// (menü yayınlanmamış gün / öğün) ilgili satır pasiftir. "Panoya kopyala" öğünün metnini, öğün
/// paylaşılamıyorsa günün metnini kopyalar.
class PaylasimSayfasi extends StatelessWidget {
  final ScaffoldMessengerState bildirim;
  final PaylasimServisi servis;
  final Universite uni;
  final String tarih, ogun;
  final Map<String, Ogun> gun;
  const PaylasimSayfasi(
      {super.key,
      required this.bildirim,
      required this.servis,
      required this.uni,
      required this.tarih,
      required this.gun,
      required this.ogun});

  /// Alt sayfayı kapatır, sonra [eylem]i çalıştırır (sistem paylaşım sayfası temiz bir ekranda açılsın).
  void _calistir(BuildContext context, Future<void> Function() eylem) {
    Navigator.of(context).pop();
    eylem();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ogunAd = ogunAdlari[ogun] ?? ogun;
    final etiket = gunTarihEtiketi(tarih);
    final ogunMetni = paylasilabilir(gun, ogun: ogun)
        ? gunMetni(uni, tarih, gun, ogun: ogun)
        : null;
    final gunMetniDegeri =
        paylasilabilir(gun) ? gunMetni(uni, tarih, gun) : null;
    final kopya = ogunMetni ?? gunMetniDegeri;
    final konu = '${uni.ad} menüsü';
    // useSafeArea yalnızca üstü korur; Android 15+ kenardan kenara düzende altı (gezinme çubuğu) burada
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Semantics(
                    header: true,
                    child: Text('Paylaş',
                        style: tema.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Bu öğünü paylaş'),
                  subtitle: Text(ogunMetni == null
                      ? 'Bu öğün için paylaşılacak menü yok'
                      : '$ogunAd · $etiket'),
                  enabled: ogunMetni != null,
                  onTap: ogunMetni == null
                      ? null
                      : () => _calistir(
                          context,
                          () => metniPaylas(bildirim, servis, ogunMetni,
                              konu: konu)),
                ),
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: const Text('Günün menüsünü paylaş'),
                  subtitle: Text(gunMetniDegeri == null
                      ? 'Bu gün için paylaşılacak menü yok'
                      : 'Tüm öğünler · $etiket'),
                  enabled: gunMetniDegeri != null,
                  onTap: gunMetniDegeri == null
                      ? null
                      : () => _calistir(
                          context,
                          () => metniPaylas(bildirim, servis, gunMetniDegeri,
                              konu: konu)),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Panoya kopyala'),
                  subtitle: Text(kopya == null
                      ? 'Kopyalanacak menü yok'
                      : (ogunMetni != null
                          ? '$ogunAd menüsünün metnini kopyalar'
                          : 'Günün menüsünün metnini kopyalar')),
                  enabled: kopya != null,
                  onTap: kopya == null
                      ? null
                      : () => _calistir(
                          context, () => metniKopyala(bildirim, kopya)),
                ),
              ]),
        ),
      ),
    );
  }
}
