import 'package:flutter/material.dart';

import '../config.dart';

/// Ana sayfanın altındaki küçük not: "Son güncelleme: 31 Ekim 08:05". [cevrimdisi] ise "Çevrimdışı: son bilinen
/// veri", [eskimis] ise (okul menüyü uzun süredir yayınlamamış) "Menü güncel değil" eklenir.
class SonGuncelleme extends StatelessWidget {
  final DateTime zaman;
  final bool cevrimdisi, eskimis;
  const SonGuncelleme(
      {super.key,
      required this.zaman,
      required this.cevrimdisi,
      required this.eskimis});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
            'Son güncelleme: ${zaman.day} ${ayAdlari[zaman.month - 1]} ${zaman.hour.toString().padLeft(2, '0')}:${zaman.minute.toString().padLeft(2, '0')}'
            '${cevrimdisi ? ' · Çevrimdışı: son bilinen veri' : ''}'
            '${eskimis ? ' · Menü güncel değil' : ''}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      );
}
