import 'package:flutter/material.dart';

/// İlk açılış karşılaması: kayıtlı okul yokken menü yerine gösterilir.
/// Okul seçilene kadar ekranda kalır; Ankara gibi bir okula kendiliğinden düşülmez.
class IlkAcilis extends StatelessWidget {
  /// "Okulunu seç" düğmesi: okul seçiciyi açar.
  final VoidCallback okulSec;
  const IlkAcilis({super.key, required this.okulSec});

  static const _maddeler = [
    (Icons.restaurant_menu_outlined, 'Okulunun günlük yemek menüsü'),
    (Icons.schedule_outlined, 'Kalori, servis saati ve fiyat bilgisi'),
    (Icons.star_outline, 'Yemeklere puan ver, yorum yaz'),
  ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    return LayoutBuilder(
      builder: (context, kisit) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          // kısa içerik dikeyde ortalansın, uzun içerik (büyük yazı) kaydırılsın
          constraints: BoxConstraints(minHeight: kisit.maxHeight - 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ExcludeSemantics(
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: renk.primaryContainer),
                        child: Icon(Icons.restaurant_menu,
                            size: 48, color: renk.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text('Üni Yemek',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 24),
                  for (final (ikon, metin) in _maddeler)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        ExcludeSemantics(
                            child: Icon(ikon, color: renk.primary, size: 24)),
                        const SizedBox(width: 16),
                        Expanded(
                            child:
                                Text(metin, style: tema.textTheme.bodyLarge)),
                      ]),
                    ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: okulSec,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Okulunu seç'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: tema.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
