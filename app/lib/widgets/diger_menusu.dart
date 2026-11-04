import 'package:flutter/material.dart';

/// Ana sayfa üst çubuğundaki "Diğer" taşma menüsü: Haftalık menü, Paylaş, Tema, Yenile, Ayarlar.
/// Dar ekranda (320 dp) okul adı başlığına yer kalsın diye ayrı simgeler yerine burada toplanır.
class DigerMenusu extends StatelessWidget {
  /// Haftalık menü sayfasını açar. Boşsa pasif görünür (menü henüz yüklenmedi).
  final VoidCallback? haftaAc;

  /// Seçili günün / öğünün paylaşım alt sayfasını açar. Boşsa pasif görünür (menü henüz yüklenmedi).
  final VoidCallback? paylasAc;
  final VoidCallback temaAc;

  /// Ayarlar sayfasını açar.
  final VoidCallback ayarlarAc;

  /// Boşsa "Yenile" pasif görünür (örn. menü yüklenirken).
  final VoidCallback? yenile;
  const DigerMenusu(
      {super.key,
      required this.haftaAc,
      required this.paylasAc,
      required this.temaAc,
      required this.ayarlarAc,
      required this.yenile});

  @override
  Widget build(BuildContext context) {
    final pasif = Theme.of(context).disabledColor;
    PopupMenuItem<VoidCallback> oge(
            IconData ikon, String ad, VoidCallback? eylem) =>
        PopupMenuItem(
            value: eylem,
            enabled: eylem != null,
            child: Row(children: [
              Icon(ikon, color: eylem == null ? pasif : null),
              const SizedBox(width: 12),
              Flexible(child: Text(ad)),
            ]));
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Diğer',
      onSelected: (eylem) => eylem(),
      itemBuilder: (_) => [
        oge(Icons.calendar_view_week_outlined, 'Haftalık menü', haftaAc),
        oge(Icons.share_outlined, 'Paylaş', paylasAc),
        const PopupMenuDivider(),
        oge(Icons.palette_outlined, 'Tema', temaAc),
        oge(Icons.refresh, 'Yenile', yenile),
        oge(Icons.settings_outlined, 'Ayarlar', ayarlarAc),
      ],
    );
  }
}
