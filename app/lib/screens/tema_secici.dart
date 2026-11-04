import 'package:flutter/material.dart';

import '../tema.dart';

/// Görünüm seçimi: açık/koyu/sistem modu ve vurgu rengi. Seçim anında uygulanır ve cihazda saklanır.
Future<void> temaSeciciGoster(BuildContext context, TemaAyari ayar) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => TemaSecici(ayar: ayar),
  );
}

enum _Gorunum { sistem, acik, koyu, siyah }

class TemaSecici extends StatelessWidget {
  final TemaAyari ayar;
  const TemaSecici({super.key, required this.ayar});

  _Gorunum get _gorunum => switch (ayar.mod) {
        ThemeMode.system => _Gorunum.sistem,
        ThemeMode.light => _Gorunum.acik,
        ThemeMode.dark => ayar.siyah ? _Gorunum.siyah : _Gorunum.koyu,
      };

  void _gorunumSec(_Gorunum g) => switch (g) {
        _Gorunum.sistem => ayar.modSec(ThemeMode.system),
        _Gorunum.acik => ayar.modSec(ThemeMode.light),
        _Gorunum.koyu => ayar.modSec(ThemeMode.dark),
        _Gorunum.siyah => ayar.modSec(ThemeMode.dark, siyah: true),
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: ayar,
        builder: (context, _) {
          final tema = Theme.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Görünüm', style: tema.textTheme.titleLarge),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_Gorunum>(
                    showSelectedIcon: false,
                    // standart yoğunluk + dolgulu hedef: segmentler görsel olarak 40 dp, dokunma hedefi 48 dp olur
                    // (compact yoğunluk hem görseli hem hedefi 40 dp bırakırdı)
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.standard,
                        tapTargetSize: MaterialTapTargetSize.padded,
                        padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 4))),
                    segments: const [
                      ButtonSegment(
                          value: _Gorunum.sistem, label: Text('Sistem')),
                      ButtonSegment(value: _Gorunum.acik, label: Text('Açık')),
                      ButtonSegment(value: _Gorunum.koyu, label: Text('Koyu')),
                      ButtonSegment(
                          value: _Gorunum.siyah, label: Text('Siyah')),
                    ],
                    selected: {_gorunum},
                    onSelectionChanged: (s) => _gorunumSec(s.first),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Renk', style: tema.textTheme.titleMedium),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, kisit) {
                  const bosluk = 12.0;
                  final genislik = (kisit.maxWidth - bosluk) / 2;
                  return Wrap(
                    spacing: bosluk,
                    runSpacing: bosluk,
                    children: [
                      for (final r in temaRenkleri)
                        SizedBox(
                          width: genislik,
                          child: _PaletKarti(
                            palet: r,
                            parlaklik: tema.brightness,
                            siyah: ayar.siyah,
                            secili: r.kimlik == ayar.renk.kimlik,
                            onTap: () => ayar.renkSec(r),
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Paletin küçük bir uygulama önizlemesi: başlık çubuğu, gün çipleri, öğün özeti kutusu.
class _PaletKarti extends StatelessWidget {
  final TemaRengi palet;
  final Brightness parlaklik;
  final bool siyah;
  final bool secili;
  final VoidCallback onTap;
  const _PaletKarti(
      {required this.palet,
      required this.parlaklik,
      required this.siyah,
      required this.secili,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = renkSemasiUret(palet, parlaklik, amoled: siyah);
    final anaTema = Theme.of(context).colorScheme;
    Widget cubuk(double w, Color c, [double h = 6]) => Container(
        width: w,
        height: h,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(h)));
    return Semantics(
      button: true,
      selected: secili,
      label: palet.ad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: secili ? anaTema.primary : anaTema.outlineVariant,
              width: 2),
        ),
        child: Material(
          color: anaTema.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      height: 92,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: r.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: r.outlineVariant.withValues(alpha: 0.7))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            cubuk(34, r.onSurface, 5),
                            const Spacer(),
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: r.primary, shape: BoxShape.circle)),
                          ]),
                          const SizedBox(height: 7),
                          Row(children: [
                            Container(
                                width: 22,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: r.primary,
                                    borderRadius: BorderRadius.circular(5))),
                            const SizedBox(width: 4),
                            for (var i = 0; i < 2; i++) ...[
                              Container(
                                  width: 16,
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: r.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(5))),
                              const SizedBox(width: 4),
                            ],
                          ]),
                          const SizedBox(height: 7),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: r.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: r.outlineVariant
                                          .withValues(alpha: 0.7))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                            color: r.tertiary,
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    cubuk(30, r.onSurface, 4),
                                  ]),
                                  const SizedBox(height: 5),
                                  cubuk(54, r.onSurfaceVariant, 4),
                                  const SizedBox(height: 3),
                                  cubuk(40, r.secondaryContainer, 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(palet.ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge),
                    ),
                    if (secili)
                      Icon(Icons.check_circle,
                          size: 20, color: anaTema.primary),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
