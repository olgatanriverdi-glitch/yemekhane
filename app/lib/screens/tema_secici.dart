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

class TemaSecici extends StatelessWidget {
  final TemaAyari ayar;
  const TemaSecici({super.key, required this.ayar});

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
                Text('Görünüm',
                    style: tema.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('Sistem')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Açık')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Koyu')),
                    ],
                    selected: {ayar.mod},
                    onSelectionChanged: (s) => ayar.modSec(s.first),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Renk', style: tema.textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final r in temaRenkleri)
                      _RenkDugmesi(
                        renk: r,
                        secili: r.kimlik == ayar.renk.kimlik,
                        onTap: () => ayar.renkSec(r),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RenkDugmesi extends StatelessWidget {
  final TemaRengi renk;
  final bool secili;
  final VoidCallback onTap;
  const _RenkDugmesi(
      {required this.renk, required this.secili, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final kontrast = ThemeData.estimateBrightnessForColor(renk.renk) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
    final cerceve = secili
        ? BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 3)
        : BorderSide.none;
    return Tooltip(
      message: renk.ad,
      child: Semantics(
        button: true,
        selected: secili,
        label: renk.ad,
        child: Material(
          color: renk.renk,
          shape: CircleBorder(side: cerceve),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: secili ? Icon(Icons.check, color: kontrast) : null,
            ),
          ),
        ),
      ),
    );
  }
}
