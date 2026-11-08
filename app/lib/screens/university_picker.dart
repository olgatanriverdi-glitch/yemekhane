import 'package:flutter/material.dart';

import '../models.dart';

/// Üniversite seçimi. Yeni üniversite eklendikçe liste otomatik uzar (veri index.json'dan gelir).
class UniversitePicker extends StatefulWidget {
  final List<Universite> uniler;
  final String? secili;

  /// Son seçilen okul kimlikleri (en yeni başta); arama yokken en üstte gösterilir.
  final List<String> sonSecilenler;
  const UniversitePicker(
      {super.key,
      required this.uniler,
      this.secili,
      this.sonSecilenler = const []});
  @override
  State<UniversitePicker> createState() => _UniversitePickerState();
}

class _UniversitePickerState extends State<UniversitePicker> {
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    final q = kucukTr(_ara.trim());
    final liste = widget.uniler
        .where((u) =>
            q.isEmpty ||
            kucukTr(u.ad).contains(q) ||
            kucukTr(u.sehir).contains(q) ||
            kucukTr(u.kisa).contains(q))
        .toList()
      ..sort((a, b) {
        // seçili okul en üstte, gerisi Türkçe alfabetik
        if (a.id == widget.secili) return -1;
        if (b.id == widget.secili) return 1;
        return trKarsilastir(a.ad, b.ad);
      });
    final sonuNot = liste.isEmpty
        ? 'Sonuç bulunamadı'
        : (q.isEmpty
            ? 'Okulun listede yok mu? Yakında daha fazla üniversite eklenecek.'
            : null);
    final tema = Theme.of(context);

    // arama yokken: "Son seçilenler" + şehir başlıkları; aramada düz liste
    final satirlar = <Widget>[];
    if (q.isEmpty) {
      final son = <Universite>[
        for (final id in widget.sonSecilenler)
          if (id != widget.secili)
            ...widget.uniler.where((u) => u.id == id).take(1)
      ].take(3).toList();
      if (son.isNotEmpty) {
        satirlar.add(_baslik(tema, 'Son seçilenler', Icons.history));
        for (final u in son) {
          satirlar.add(_satir(u));
        }
      }
      // şehir grupları: seçili okulun şehri başta, diğer şehirler Türkçe alfabetik ("Diğer" en sonda);
      // grup içinde okullar düz listedeki sırayla (seçili okul başta, gerisi alfabetik)
      final gruplar = <String, List<Universite>>{};
      for (final u in liste) {
        gruplar
            .putIfAbsent(u.sehir.isEmpty ? 'Diğer' : u.sehir, () => [])
            .add(u);
      }
      final seciliSehir = liste.isNotEmpty && liste.first.id == widget.secili
          ? gruplar.keys.first
          : null;
      final sehirler = gruplar.keys.toList()
        ..sort((a, b) {
          if (a == seciliSehir) return -1;
          if (b == seciliSehir) return 1;
          if (a == 'Diğer') return 1;
          if (b == 'Diğer') return -1;
          return trKarsilastir(a, b);
        });
      for (final sehir in sehirler) {
        final okullar = gruplar[sehir]!;
        satirlar.add(_baslik(
            tema, '$sehir (${okullar.length})', Icons.location_city_outlined));
        for (final u in okullar) {
          satirlar.add(_satir(u));
        }
      }
    } else {
      for (final u in liste) {
        satirlar.add(_satir(u));
      }
    }
    if (sonuNot != null) {
      satirlar.add(Padding(
        padding: const EdgeInsets.all(24),
        child: Text(sonuNot, textAlign: TextAlign.center),
      ));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Üniversite seç')),
      // Android 15+ kenardan kenara: liste gezinme çubuğunun altına girmesin (üstü AppBar karşılar)
      body: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            // SearchBar iki ayrı anlam düğümü üretir: etiketsiz dış kutu (56 dp) ve 23 dp'lik iç yazı alanı.
            // Tek düğümde birleştirilince tüm kutu (>= 48 dp) dokunma hedefi olur ve ipucu metni etiket olur.
            child: MergeSemantics(
              child: SearchBar(
                  hintText: 'Üniversite veya şehir ara',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                      tema.colorScheme.surfaceContainerHigh),
                  onChanged: (v) => setState(() => _ara = v)),
            ),
          ),
          Expanded(
            child: ListView(
                padding: const EdgeInsets.only(bottom: 16), children: satirlar),
          ),
        ]),
      ),
    );
  }

  Widget _baslik(ThemeData tema, String metin, IconData ikon) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(children: [
          Icon(ikon, size: 16, color: tema.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(metin,
                style: tema.textTheme.labelLarge?.copyWith(
                    color: tema.colorScheme.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _satir(Universite u) {
    final secili = u.id == widget.secili;
    return Semantics(
      label: '${u.ad}, ${u.sehir}${secili ? ', seçili' : ''}',
      excludeSemantics: true,
      button: true,
      onTap: () => Navigator.of(context).pop(u.id),
      child: ListTile(
        leading: ExcludeSemantics(
          child: CircleAvatar(
              child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FittedBox(
                      child: Text(u.kisa.isEmpty ? u.ad[0] : u.kisa)))),
        ),
        title: Text(u.ad),
        subtitle: Text(u.sehir),
        trailing: secili ? const Icon(Icons.check_circle) : null,
        onTap: () => Navigator.of(context).pop(u.id),
      ),
    );
  }
}
