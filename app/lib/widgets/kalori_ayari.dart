import 'package:flutter/material.dart';

import '../kalori_hedefi.dart';

/// Ayarlar'daki günlük kalori hedefi bölümü: anahtar; açıkken hedef seçici (kaydırıcı ile "−" / "+" düğmeleri,
/// [KaloriHedefi.enAz]-[KaloriHedefi.enCok] arası [KaloriHedefi.adim] adımlarla) ve genel bilgi uyarısı.
/// Değişiklikler hemen [kaloriHedefi]ye işlenir ve cihaza kaydedilir.
class KaloriHedefiAyari extends StatelessWidget {
  final KaloriHedefi kaloriHedefi;
  const KaloriHedefiAyari({super.key, required this.kaloriHedefi});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: kaloriHedefi,
        builder: (context, _) => Column(children: [
          SwitchListTile(
            secondary: const Icon(Icons.local_fire_department_outlined),
            title: const Text('Günlük kalori hedefi'),
            subtitle: const Text('Öğünün hedefe oranını göster'),
            value: kaloriHedefi.acik,
            onChanged: kaloriHedefi.acikSec,
          ),
          if (kaloriHedefi.acik) _HedefSecici(kaloriHedefi),
        ]),
      );
}

class _HedefSecici extends StatelessWidget {
  final KaloriHedefi k;
  const _HedefSecici(this.k);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Günlük hedef: ${k.hedef} kkal',
            style: tema.textTheme.titleMedium),
        Row(children: [
          IconButton(
            tooltip: 'Hedefi azalt',
            icon: const Icon(Icons.remove),
            onPressed: k.hedef > KaloriHedefi.enAz
                ? () => k.hedefSec(k.hedef - KaloriHedefi.adim)
                : null,
          ),
          Expanded(
            // kaydırıcı kendi anlam düğümünü açar; ad ve değer tek düğümde okunsun diye birleştirilir
            child: MergeSemantics(
              child: Semantics(
                label: 'Günlük kalori hedefi',
                child: Slider(
                  value: k.hedef.toDouble(),
                  min: KaloriHedefi.enAz.toDouble(),
                  max: KaloriHedefi.enCok.toDouble(),
                  divisions: KaloriHedefi.adimSayisi,
                  // varsayılan pasif iz yüzeyle neredeyse aynı renkte kalıyor; çerçeve renginden türetilir
                  inactiveColor:
                      tema.colorScheme.outline.withValues(alpha: 0.6),
                  semanticFormatterCallback: (v) => '${v.round()} kkal',
                  onChanged: (v) => k.hedefSec(v.round()),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hedefi artır',
            icon: const Icon(Icons.add),
            onPressed: k.hedef < KaloriHedefi.enCok
                ? () => k.hedefSec(k.hedef + KaloriHedefi.adim)
                : null,
          ),
        ]),
        Text('Genel bilgidir, tıbbi tavsiye değildir.',
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
