import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';

/// Seçim anında uygulanır ve cihazda saklanır; uzun içerik büyük yazıda da kaydırılır.
Future<void> temaSeciciGoster(BuildContext context, TemaAyari ayar) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    builder: (_) => TemaSecici(ayar: ayar),
  );
}

enum _Gorunum {
  sistem('Sistem', Icons.brightness_auto_outlined,
      'Cihazının açık veya koyu görünümünü izler.'),
  acik('Açık', Icons.light_mode_outlined, 'Aydınlık zeminler, net renkler.'),
  koyu('Koyu', Icons.dark_mode_outlined, 'Koyu yüzeyler, yumuşak vurgular.'),
  siyah('Siyah', Icons.contrast_rounded, 'Saf siyah zemin, belirgin kartlar.');

  final String ad;
  final IconData ikon;
  final String aciklama;
  const _Gorunum(this.ad, this.ikon, this.aciklama);
}

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
      top: false,
      child: ListenableBuilder(
        listenable: ayar,
        builder: (context, _) {
          final tema = Theme.of(context);
          final r = tema.colorScheme;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child:
                          Text('Görünüm', style: tema.textTheme.headlineSmall)),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
                Text('Menünü kendi renklerinle gör.',
                    style: tema.textTheme.bodyMedium
                        ?.copyWith(color: r.onSurfaceVariant)),
                const SizedBox(height: 24),
                Text('Ekran modu', style: tema.textTheme.titleSmall),
                const SizedBox(height: 10),
                _GorunumSecimi(secili: _gorunum, sec: _gorunumSec),
                const SizedBox(height: 10),
                Text(_gorunum.aciklama,
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: r.onSurfaceVariant)),
                const SizedBox(height: 28),
                Text('Renk paleti', style: tema.textTheme.titleSmall),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, kisit) {
                  const bosluk = 12.0;
                  // Etiketler kesilmez. Büyük yazıda / dar ekranda tek sütuna geçer.
                  final enAz = math.max(142.0,
                      _etiketEni(context, temaRenkleri.map((p) => p.ad)) + 52);
                  final sutun = kisit.maxWidth >= enAz * 2 + bosluk ? 2 : 1;
                  final genislik =
                      (kisit.maxWidth - bosluk * (sutun - 1)) / sutun;
                  return Wrap(
                    spacing: bosluk,
                    runSpacing: bosluk,
                    children: [
                      for (final p in temaRenkleri)
                        SizedBox(
                          width: genislik,
                          child: _PaletKarti(
                            palet: p,
                            parlaklik: tema.brightness,
                            siyah: ayar.siyah,
                            secili: p.kimlik == ayar.renk.kimlik,
                            onTap: () => ayar.renkSec(p),
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

double _etiketEni(BuildContext context, Iterable<String> etiketler) {
  final olcer = TextPainter(
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  );
  var en = 0.0;
  for (final etiket in etiketler) {
    olcer.text =
        TextSpan(text: etiket, style: Theme.of(context).textTheme.labelLarge);
    olcer.layout();
    en = math.max(en, olcer.width);
  }
  olcer.dispose();
  return en;
}

class _GorunumSecimi extends StatelessWidget {
  final _Gorunum secili;
  final ValueChanged<_Gorunum> sec;
  const _GorunumSecimi({required this.secili, required this.sec});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final r = tema.colorScheme;
    return LayoutBuilder(builder: (context, kisit) {
      const bosluk = 8.0;
      final enAz = math.max(
          64.0, _etiketEni(context, _Gorunum.values.map((g) => g.ad)) + 20);
      final sutun = kisit.maxWidth >= 4 * enAz + 3 * bosluk
          ? 4
          : kisit.maxWidth >= 2 * enAz + bosluk
              ? 2
              : 1;
      final en = (kisit.maxWidth - (sutun - 1) * bosluk) / sutun;
      return Wrap(spacing: bosluk, runSpacing: bosluk, children: [
        for (final g in _Gorunum.values)
          SizedBox(
            width: en,
            child: _SecimAlani(
              etiket: g.ad,
              secili: g == secili,
              tonal: true,
              onTap: () => sec(g),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 80),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(g.ikon,
                        size: 22,
                        color: g == secili
                            ? r.onPrimaryContainer
                            : r.onSurfaceVariant),
                    const SizedBox(height: 6),
                    Text(g.ad,
                        textAlign: TextAlign.center,
                        style: tema.textTheme.labelLarge?.copyWith(
                            color: g == secili
                                ? r.onPrimaryContainer
                                : r.onSurfaceVariant)),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// Renk dışındaki seçili bilgisi (çerçeve, onay, anlam ağacı) her zaman korunur.
class _SecimAlani extends StatelessWidget {
  final String etiket;
  final bool secili;
  final bool tonal;
  final VoidCallback onTap;
  final Widget child;
  const _SecimAlani(
      {required this.etiket,
      required this.secili,
      this.tonal = false,
      required this.onTap,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: secili,
      inMutuallyExclusiveGroup: true,
      label: etiket,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        color: secili && tonal ? r.primaryContainer : r.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: secili ? r.primary : r.outlineVariant,
              width: secili ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, excludeFromSemantics: true, child: child),
      ),
    );
  }
}

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
    final tema = Theme.of(context);
    final r = renkSemasiUret(palet, parlaklik, amoled: siyah);
    return _SecimAlani(
      etiket: palet.ad,
      secili: secili,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Küçük maket dekoratiftir; asıl palet adı aşağıda tam ölçeklenir.
          ExcludeSemantics(
              child: MediaQuery.withNoTextScaling(
                  child: _PaletOnizlemesi(renk: r))),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(palet.ad, style: tema.textTheme.labelLarge)),
              const SizedBox(width: 6),
              SizedBox(
                  width: 20,
                  height: 20,
                  child: secili
                      ? Icon(Icons.check_circle,
                          size: 20, color: tema.colorScheme.primary)
                      : null),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Seçilen ekran modunda gerçek zemin, kart ve vurgu ilişkisini gösterir.
class _PaletOnizlemesi extends StatelessWidget {
  final ColorScheme renk;
  const _PaletOnizlemesi({required this.renk});

  Widget _cizgi(double pay, Color renk) => FractionallySizedBox(
        widthFactor: pay,
        alignment: Alignment.centerLeft,
        child: Container(
            height: 4,
            decoration: BoxDecoration(
                color: renk, borderRadius: BorderRadius.circular(2))),
      );

  @override
  Widget build(BuildContext context) {
    final r = renk;
    final stil = Theme.of(context).textTheme.labelSmall;
    return Container(
      height: 108,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: r.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: r.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Bugün',
                  style: stil?.copyWith(
                      color: r.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w800))),
          Icon(Icons.restaurant_rounded, size: 14, color: r.primary),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 4; i++) ...[
            Container(
                width: 19,
                height: 12,
                decoration: BoxDecoration(
                    color: i == 0 ? r.primary : r.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4))),
            if (i < 3) const SizedBox(width: 4),
          ],
        ]),
        const SizedBox(height: 8),
        Expanded(
            child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: r.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                    color: r.primaryContainer,
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.soup_kitchen_outlined,
                    size: 16, color: r.onPrimaryContainer)),
            const SizedBox(width: 6),
            Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cizgi(0.95, r.onSurface),
                  const SizedBox(height: 5),
                  _cizgi(0.6, r.onSurfaceVariant),
                ])),
          ]),
        )),
      ]),
    );
  }
}
