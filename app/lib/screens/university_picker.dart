import 'package:flutter/material.dart';

import '../models.dart';

/// Üniversite seçimi. Yeni üniversite eklendikçe liste otomatik uzar (veri index.json'dan gelir).
class UniversitePicker extends StatefulWidget {
  final List<Universite> uniler;
  final String? secili;
  const UniversitePicker({super.key, required this.uniler, this.secili});
  @override
  State<UniversitePicker> createState() => _UniversitePickerState();
}

class _UniversitePickerState extends State<UniversitePicker> {
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ara = kucukTr(_ara);
    final gruplar = sehreGoreGrupla(widget.uniler
        .where((u) =>
            kucukTr(u.ad).contains(ara) ||
            kucukTr(u.kisa).contains(ara) ||
            kucukTr(u.sehir).contains(ara))
        .toList());
    return Scaffold(
      appBar: AppBar(title: const Text('Üniversite seç')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
              hintText: 'Üniversite veya şehir ara',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _ara = v)),
        ),
        Expanded(
          child: ListView(children: [
            for (final g in gruplar) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text('${g.key} · ${g.value.length}',
                    style: tema.textTheme.titleSmall?.copyWith(
                        color: tema.colorScheme.primary,
                        fontWeight: FontWeight.w800)),
              ),
              for (final u in g.value)
                ListTile(
                  leading: CircleAvatar(
                      child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: FittedBox(
                              child: Text(u.kisa.isEmpty ? u.ad[0] : u.kisa)))),
                  title: Text(u.ad),
                  subtitle: Text('${u.ogunler.length} öğün türü'),
                  trailing: u.id == widget.secili
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () => Navigator.of(context).pop(u.id),
                ),
            ],
            if (gruplar.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aramanla eşleşen üniversite yok.',
                    textAlign: TextAlign.center),
              ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Okulun listede yok mu? Yakında daha fazla üniversite eklenecek.',
                  textAlign: TextAlign.center),
            ),
          ]),
        ),
      ]),
    );
  }
}
