import 'package:flutter/material.dart';

import '../bildirim_ayari.dart';
import '../bildirim_plani.dart';

/// Ayarlar'daki günlük menü bildirimi bölümü: anahtar (varsayılan kapalı); açıkken saat satırı ("Bildirim saati",
/// dokununca Türkçe saat seçici) ve bildirimin nasıl hazırlandığını anlatan not. Açarken izin istenir; izin
/// verilmezse anahtar kapalı kalır ve kısa bir açıklama gösterilir. Değişiklikler hemen [ayar]a işlenir ve
/// cihaza kaydedilir.
class BildirimAyariBolumu extends StatefulWidget {
  final BildirimAyari ayar;
  const BildirimAyariBolumu({super.key, required this.ayar});

  @override
  State<BildirimAyariBolumu> createState() => _BildirimAyariBolumuState();
}

class _BildirimAyariBolumuState extends State<BildirimAyariBolumu> {
  // son açma denemesinde izin verilmedi: anahtar kapalı kalır, açıklama görünür
  bool _izinVerilmedi = false;
  // izin penceresi / planlama sürerken ikinci dokunuş yok sayılır
  bool _mesgul = false;

  Future<void> _anahtar(bool aciliyor) async {
    if (_mesgul) return;
    _mesgul = true;
    try {
      if (aciliyor) {
        final tamam = await widget.ayar.ac();
        if (mounted) setState(() => _izinVerilmedi = !tamam);
      } else {
        if (mounted) setState(() => _izinVerilmedi = false);
        await widget.ayar.kapat();
      }
    } finally {
      _mesgul = false;
    }
  }

  Future<void> _saatSec() async {
    final dk = widget.ayar.saatDk;
    final secilen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: dk ~/ 60, minute: dk % 60),
      helpText: 'Bildirim saati',
      // Türkiye'de saat 24'lüktür; yerelleştirme başka bir dile düşse de AM / PM çıkmasın
      builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: w!),
    );
    if (secilen == null) return;
    await widget.ayar.saatSec(secilen.hour * 60 + secilen.minute);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.textTheme.bodySmall
        ?.copyWith(color: tema.colorScheme.onSurfaceVariant);
    return ListenableBuilder(
      listenable: widget.ayar,
      builder: (context, _) => Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Günlük menü bildirimi'),
          subtitle: const Text('Seçtiğin saatte günün menüsünü bildirir'),
          value: widget.ayar.acik,
          onChanged: _anahtar,
        ),
        if (widget.ayar.acik)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Bildirim saati'),
            subtitle: Text(bildirimSaatMetni(widget.ayar.saatDk)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _saatSec,
          ),
        if (_izinVerilmedi)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            // ekran okuyucu, anahtar geri kapanınca nedenini de duysun
            child: Semantics(
              liveRegion: true,
              child: Text(
                  'Bildirim izni verilmedi. Bildirim almak için telefonun '
                  "ayarlarından Üni Yemek'e izin verip tekrar dene.",
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.error)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
              'Bildirim, uygulamayı son açtığın andaki menüyle hazırlanır; '
              'menüyü güncel tutmak için uygulamayı ara sıra aç.',
              style: soluk),
        ),
      ]),
    );
  }
}
