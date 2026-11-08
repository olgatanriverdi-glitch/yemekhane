import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';
import 'ogun_bilgi.dart';

// Öğün adı + "-e" hali: "Öğle yemeğine 25 dk".
const _ogunYonelme = {
  'breakfast': 'Kahvaltıya',
  'lunch': 'Öğle yemeğine',
  'dinner': 'Akşam yemeğine',
  'vegetarian': 'Vejetaryen menüye',
};

// Sayının son okunuşuna göre "-de / -da / -te / -ta" eki (0-59).
const _birlerEki = {
  1: 'de',
  2: 'de',
  3: 'te',
  4: 'te',
  5: 'te',
  6: 'da',
  7: 'de',
  8: 'de',
  9: 'da'
};
const _onlarEki = {1: 'da', 2: 'de', 3: 'da', 4: 'ta', 5: 'de'};

String _sayiEki(int n) =>
    n % 10 != 0 ? _birlerEki[n % 10]! : (_onlarEki[n ~/ 10] ?? 'da');

/// Kalan süre: "25 dk", "1 sa", "1 sa 10 dk".
String sureMetni(int dk) {
  if (dk < 60) return '$dk dk';
  final s = dk ~/ 60, d = dk % 60;
  return d == 0 ? '$s sa' : '$s sa $d dk';
}

/// Gün başından itibaren dakikayı "11:00'de" gibi yazar: ":00" ise saat, değilse dakika okunuşuna uyan ek
/// ("11:00'de", "11:30'da", "14:15'te").
String saatMetniEkli(int dk) {
  final s = dk ~/ 60 % 24, d = dk % 60;
  final hhmm =
      '${s.toString().padLeft(2, '0')}:${d.toString().padLeft(2, '0')}';
  return "$hhmm'${_sayiEki(d == 0 ? s : d)}";
}

/// "Şimdi" şeridinin metni; saat biçimi bozuksa null.
/// Başlamadı: "Öğle yemeğine 25 dk" (yaklaşık saatte "Genelde 11:00'de başlar · 25 dk");
/// devam: "Servis açık · bitmesine 1 sa 10 dk" (yaklaşık saatte "Genelde 14:00'te biter · 1 sa 10 dk");
/// bitti: "Öğle servisi bitti".
String? simdiSeridiMetni(String ogun, ServisSaati saat, DateTime simdi) {
  final durum = ogunDurumu(saat, simdi);
  final aralik = saat.aralik();
  if (durum == null || aralik == null) return null;
  final sure = sureMetni(durum.kalanDk);
  switch (durum.asama) {
    case OgunAsama.baslamadi:
      return saat.yaklasik
          ? "Genelde ${saatMetniEkli(aralik.$1)} başlar · $sure"
          : '${_ogunYonelme[ogun] ?? 'Öğüne'} $sure';
    case OgunAsama.devam:
      return saat.yaklasik
          ? "Genelde ${saatMetniEkli(aralik.$2)} biter · $sure"
          : 'Servis açık · bitmesine $sure';
    case OgunAsama.bitti:
      return '${ogunAdlari[ogun] ?? 'Öğün'} servisi bitti';
  }
}

/// Tek satır: sığmazsa yazı küçülür ama alt satıra inmez; büyük yazı ölçeğinde şerit dikey alanı yemesin.
class _TekSatir extends StatelessWidget {
  final String metin;
  final TextStyle? stil;
  const _TekSatir({required this.metin, this.stil});

  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(metin, maxLines: 1, softWrap: false, style: stil));
}

Duration _sure(BuildContext context) => MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 200);

/// Öğün seçicinin altında, yalnızca bugün seçiliyken ve öğünün servis saati varsa görünen ince şerit:
/// başlamasına / bitmesine kalan süre. 30 saniyede bir kendini yeniler. [simdi] Türkiye duvar saatini verir.
class SimdiSeridi extends StatelessWidget {
  final String ogun;
  final ServisSaati? saat;

  /// Seçili gün bugün mü? Değilse şerit görünmez.
  final bool bugunMu;
  final DateTime Function() simdi;
  const SimdiSeridi(
      {super.key,
      required this.ogun,
      required this.saat,
      required this.bugunMu,
      required this.simdi});

  @override
  Widget build(BuildContext context) {
    final s = saat;
    final gorunur = bugunMu && s != null && s.aralik() != null;
    return AnimatedSize(
      // şerit belirirken / kaybolurken altındaki içerik sıçramasın; hareket kapalıysa anında
      duration: _sure(context),
      alignment: Alignment.topCenter,
      child: gorunur
          ? _SeritGovdesi(ogun: ogun, saat: s, simdi: simdi)
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

class _SeritGovdesi extends StatefulWidget {
  final String ogun;
  final ServisSaati saat;
  final DateTime Function() simdi;
  const _SeritGovdesi(
      {required this.ogun, required this.saat, required this.simdi});
  @override
  State<_SeritGovdesi> createState() => _SeritGovdesiState();
}

class _SeritGovdesiState extends State<_SeritGovdesi> {
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    _zamanlayici = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simdi = widget.simdi();
    final metin = simdiSeridiMetni(widget.ogun, widget.saat, simdi);
    final durum = ogunDurumu(widget.saat, simdi);
    if (metin == null || durum == null) return const SizedBox.shrink();
    final renk = Theme.of(context).colorScheme;
    final (zemin, yazi, ikon) = switch (durum.asama) {
      OgunAsama.devam => (
          renk.primaryContainer,
          renk.onPrimaryContainer,
          Icons.restaurant_outlined
        ),
      OgunAsama.baslamadi => (
          renk.surfaceContainerHigh,
          renk.onSurface,
          Icons.schedule
        ),
      OgunAsama.bitti => (
          renk.surfaceContainerHighest,
          renk.onSurfaceVariant,
          Icons.event_busy_outlined
        ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Semantics(
        container: true,
        label: metin,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: zemin, borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(children: [
              Icon(ikon, size: 16, color: yazi),
              const SizedBox(width: 8),
              Expanded(
                child: _TekSatir(
                    metin: metin,
                    stil: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: yazi, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Menü-bitti bandının içeriği: [bitti] true ise bugün menünün son gününden sonradır (belirgin bant),
/// false ise menü çok yakında bitiyor (hafif bilgi).
class MenuBandBilgisi {
  final bool bitti;
  final String metin;
  const MenuBandBilgisi(this.bitti, this.metin);
}

/// "31 Ekim'e" gibi yönelme hali: yalnızca Eylül ve Ekim ince ünlülü olduğundan "-e" alır.
String _gunYonelme(DateTime d) =>
    "${d.day} ${ayAdlari[d.month - 1]}'${d.month == 9 || d.month == 10 ? 'e' : 'a'}";

/// Bugün menünün son gününden sonraysa "yayınlanmadı" bandı; son güne 0-2 gün varsa hafif bilgi;
/// yoksa (ya da menü boşsa) null.
MenuBandBilgisi? menuBandBilgisi(Menu menu, String bugun) {
  final b = DateTime.tryParse(bugun);
  final t = menu.tarihler;
  final son = t.isEmpty ? null : DateTime.tryParse(t.last);
  if (b == null || son == null) return null;
  final fark = DateTime.utc(son.year, son.month, son.day)
      .difference(DateTime.utc(b.year, b.month, b.day))
      .inDays;
  if (fark < 0) {
    return MenuBandBilgisi(
        true,
        'Bu okulun yeni menüsü henüz yayınlanmadı. '
        'Gösterilen son menü: ${son.day} ${ayAdlari[son.month - 1]}.');
  }
  if (fark <= 2) {
    return MenuBandBilgisi(false, "Menü ${_gunYonelme(son)} kadar yayınlandı.");
  }
  return null;
}

/// Gün çubuğunun üstündeki menü bandı: [MenuBandBilgisi.bitti] ise renkli ince bant, değilse tek satırlık hafif not.
class MenuBandi extends StatelessWidget {
  final MenuBandBilgisi bilgi;
  const MenuBandi({super.key, required this.bilgi});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    final yazi = bilgi.bitti ? renk.onTertiaryContainer : renk.onSurfaceVariant;
    final govde = Row(children: [
      Icon(Icons.info_outline, size: bilgi.bitti ? 18 : 14, color: yazi),
      const SizedBox(width: 8),
      Expanded(
        child: bilgi.bitti
            ? Text(bilgi.metin,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: yazi, fontWeight: FontWeight.w600))
            : _TekSatir(
                metin: bilgi.metin,
                stil: tema.textTheme.bodySmall
                    ?.copyWith(color: yazi, fontWeight: FontWeight.w500)),
      ),
    ]);
    return Semantics(
      container: true,
      label: bilgi.metin,
      excludeSemantics: true,
      child: bilgi.bitti
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: renk.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: govde),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0), child: govde),
    );
  }
}
