import 'package:flutter/material.dart';

/// Ana sayfa üst çubuğunun başlığı: seçili okulun adı ve açılır ok. Dokununca okul seçici açılır
/// ([sec] boşsa pasif: okul listesi henüz yüklenmedi). Uzun ad tek satırda kısaltılır.
class OkulBasligi extends StatelessWidget {
  final String ad;
  final VoidCallback? sec;
  const OkulBasligi({super.key, required this.ad, required this.sec});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: sec,
        borderRadius: BorderRadius.circular(12),
        // dokunma hedefi en az 48 dp yüksekliğinde; yazı dikeyde ortalı kalır
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(ad, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ]),
        ),
      );
}
