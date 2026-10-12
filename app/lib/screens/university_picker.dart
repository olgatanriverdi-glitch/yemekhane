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

const _trSira = 'abcçdefgğhıijklmnoöprsştuüvyz';

/// Türkçe alfabe sırasına göre karşılaştırma (ç, ğ, ı, ö, ş, ü kendi yerinde).
int _trKarsilastir(String a, String b) {
  final x = kucukTr(a), y = kucukTr(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    final p = _trSira.indexOf(x[i]), q = _trSira.indexOf(y[i]);
    final c = (p < 0 ? 100 + x.codeUnitAt(i) : p)
        .compareTo(q < 0 ? 100 + y.codeUnitAt(i) : q);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
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
        return _trKarsilastir(a.ad, b.ad);
      });
    final sonuNot = liste.isEmpty
        ? 'Sonuç bulunamadı'
        : (q.isEmpty
            ? 'Okulun listede yok mu? Yakında daha fazla üniversite eklenecek.'
            : null);
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
          child: ListView.builder(
            itemCount: liste.length + (sonuNot == null ? 0 : 1),
            itemBuilder: (context, i) {
              if (i == liste.length) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(sonuNot!, textAlign: TextAlign.center),
                );
              }
              final u = liste[i];
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
                                child:
                                    Text(u.kisa.isEmpty ? u.ad[0] : u.kisa)))),
                  ),
                  title: Text(u.ad),
                  subtitle: Text(u.sehir),
                  trailing: secili ? const Icon(Icons.check_circle) : null,
                  onTap: () => Navigator.of(context).pop(u.id),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
