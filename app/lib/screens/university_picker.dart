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
    final liste = widget.uniler.where((u) => u.ad.toLowerCase().contains(_ara.toLowerCase()) || u.sehir.toLowerCase().contains(_ara.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Üniversite seç')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(hintText: 'Üniversite veya şehir ara', leading: const Icon(Icons.search), onChanged: (v) => setState(() => _ara = v)),
        ),
        Expanded(
          child: ListView(children: [
            for (final u in liste)
              ListTile(
                leading: CircleAvatar(child: Text(u.kisa.isEmpty ? u.ad[0] : u.kisa)),
                title: Text(u.ad),
                subtitle: Text('${u.sehir} · ${u.ogunler.length} öğün türü'),
                trailing: u.id == widget.secili ? const Icon(Icons.check_circle) : null,
                onTap: () => Navigator.of(context).pop(u.id),
              ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Okulun listede yok mu? Yakında daha fazla üniversite eklenecek.', textAlign: TextAlign.center),
            ),
          ]),
        ),
      ]),
    );
  }
}
