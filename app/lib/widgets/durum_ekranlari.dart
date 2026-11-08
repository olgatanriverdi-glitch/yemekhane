import 'package:flutter/material.dart';

import '../models.dart';
import '../tema.dart' show TemaImzasi;
import 'ogun_bilgi.dart';

/// Yemek verilmeyen gün / öğün için sade bilgi ekranı.
class YemekYok extends StatelessWidget {
  final String baslik, alt;
  final IconData ikon;
  const YemekYok(
      {super.key, required this.baslik, required this.alt, required this.ikon});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final imza = TemaImzasi.of(context);
    return ListView(
      // kısa içerikte de aşağı çekip yenilenebilsin
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: imza.degrade == null ? imza.zemin : null,
                gradient: imza.degrade),
            child: Icon(ikon, size: 52, color: imza.zeminUstu),
          ),
        ),
        const SizedBox(height: 24),
        Text(baslik,
            textAlign: TextAlign.center,
            style: tema.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(alt,
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium
                ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Menü yüklenemediğinde: bulut simgesi, mesaj ve eylemler.
class HataEkrani extends StatelessWidget {
  final String mesaj;
  final VoidCallback tekrar;
  final VoidCallback? okulSec;
  const HataEkrani(
      {super.key, required this.mesaj, required this.tekrar, this.okulSec});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: tema.colorScheme.errorContainer),
            child: Icon(Icons.cloud_off,
                size: 44, color: tema.colorScheme.onErrorContainer),
          ),
          const SizedBox(height: 20),
          Text(mesaj,
              textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton(onPressed: tekrar, child: const Text('Tekrar dene')),
          if (okulSec != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: okulSec, child: const Text('Okul seç'))
          ]
        ]),
      ),
    );
  }
}

/// Yüklenirken gün şeridi, öğün seçici ve kart şeklinde nabız atan bloklar.
class IskeletGovde extends StatefulWidget {
  const IskeletGovde({super.key});
  @override
  State<IskeletGovde> createState() => _IskeletGovdeState();
}

class _IskeletGovdeState extends State<IskeletGovde>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // hareket kapalıysa (erişilebilirlik / testler) sürekli animasyon çalıştırma
    if (MediaQuery.disableAnimationsOf(context)) {
      _kontrol.stop();
      _kontrol.value = 1;
    } else if (!_kontrol.isAnimating) {
      _kontrol.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  Widget _blok(Color renk, double h, {double? w, double r = 12}) => Container(
      width: w,
      height: h,
      decoration:
          BoxDecoration(color: renk, borderRadius: BorderRadius.circular(r)));

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Menü yükleniyor',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(_kontrol),
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: _blok(renk, 28, w: 140)),
              const SizedBox(height: 6),
              Center(child: _blok(renk, 14, w: 200)),
              const SizedBox(height: 16),
              Row(children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: _blok(renk, 54, r: 14),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              _blok(renk, 40, r: 20),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  _blok(renk, 64, r: 18),
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(children: [
                        _blok(renk, 48, w: 48, r: 14),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              _blok(renk, 14),
                              const SizedBox(height: 8),
                              _blok(renk, 10, w: 90),
                            ])),
                        const SizedBox(width: 10),
                        _blok(renk, 22, w: 52, r: 11),
                      ]),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Okul o gün vejetaryen menü yayınlamadıysa: öğle ve akşam menüsündeki etsiz görünen yemekleri öneri olarak gösterir.
class EtsizOneri extends StatelessWidget {
  final Map<String, Ogun> gun;
  const EtsizOneri({super.key, required this.gun});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final buyukYazi = MediaQuery.textScalerOf(context).scale(16) > 22;
    final bolumler = <Widget>[];
    for (final tur in ['lunch', 'dinner']) {
      final o = gun[tur];
      if (o == null || o.bos) continue;
      final etsiz = o.ogeler.where((e) => etsizMi(e.ad)).toList();
      if (etsiz.isEmpty) continue;
      bolumler.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text('${ogunAdlari[tur]} menüsünden etsiz görünenler',
            style: tema.textTheme.titleSmall
                ?.copyWith(color: tema.colorScheme.primary)),
      ));
      for (final e in etsiz) {
        final kcal = e.kcal == null
            ? null
            : Text('${e.kcal} kkal',
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant));
        bolumler.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(Icons.eco_outlined, size: 18, color: tema.colorScheme.primary),
            const SizedBox(width: 10),
            // büyük yazıda kalori adın yanında değil altında durur (taşma olmasın); ana ekrandaki yemek satırıyla aynı eşik
            Expanded(
              child: buyukYazi && kcal != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(e.ad, style: tema.textTheme.titleMedium),
                          kcal,
                        ])
                  : Text(e.ad, style: tema.textTheme.titleMedium),
            ),
            if (!buyukYazi && kcal != null) kcal,
          ]),
        ));
      }
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: tema.colorScheme.surfaceContainerLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Okul bu gün için ayrı bir vejetaryen menü yayınlamadı.',
                  style: tema.textTheme.titleMedium),
              if (bolumler.isNotEmpty)
                ...bolumler
              else
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                        'Bu günün menüsünde etsiz görünen yemek bulunamadı.')),
              const Divider(height: 28),
              Text(
                  'Bu liste otomatik tahmindir (yemek adlarına göre). Çorba ve yemeklerin içeriği değişebilir; kesin bilgi için yemekhane görevlisine sor.',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ],
    );
  }
}
