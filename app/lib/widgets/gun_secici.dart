import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../config.dart';
import '../favoriler.dart' show favoriGunEtiketi;

/// Üstte büyük "Bugün / Cuma" başlığı, altında tek satırlık tarih ("2 Ekim 2026 · Cuma") ve yanlarda önceki /
/// sonraki gün okları. Dar ekranda (320 dp) ya da büyük yazıda iki satır da sarmaz, sığacak kadar küçülür;
/// böylece başlık yüksekliği okların boyunu (48 dp) çok aşmaz ve menüye dikey yer kalır.
class GunBasligi extends StatelessWidget {
  final List<String> tarihler;
  final String secili, bugun;
  final ValueChanged<String> degisti;
  const GunBasligi(
      {super.key,
      required this.tarihler,
      required this.secili,
      required this.bugun,
      required this.degisti});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final i = tarihler.indexOf(secili);
    final d = DateTime.parse(secili);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(children: [
        IconButton.filledTonal(
            onPressed: i > 0 ? () => degisti(tarihler[i - 1]) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Önceki gün'),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              // "Bugün" / "Yarın" / gün adı; fark UTC takvim günleriyle hesaplanır (yaz saati geçişinde sapmaz)
              child: Text(favoriGunEtiketi(secili, bugun),
                  maxLines: 1,
                  style: tema.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                  '${d.day} ${ayAdlari[d.month - 1]} ${d.year} · ${gunAdlari[d.weekday - 1]}',
                  maxLines: 1,
                  style: tema.textTheme.bodyMedium
                      ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ),
          ]),
        ),
        IconButton.filledTonal(
            onPressed: i >= 0 && i < tarihler.length - 1
                ? () => degisti(tarihler[i + 1])
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Sonraki gün'),
      ]),
    );
  }
}

/// Bir gün hücresinin en az genişliği (dp): dokunma hedefi 48 dp'den dar olmasın.
const double gunHucresiEnAz = 48;

/// [genislik] dp'lik şeride en az [gunHucresiEnAz] genişliğinde kaç gün hücresi sığar (en çok 7, en az 1).
/// 320 dp'de 6, 360 dp ve üstünde 7.
int haftaSeridiHucreSayisi(double genislik) =>
    (genislik / gunHucresiEnAz).floor().clamp(1, 7);

/// Seçili günün etrafındaki günler (en çok 7): eşit genişlikte, kaydırma yok. Dokununca o güne geçer.
/// Dar ekranda hücre sayısı azalır, böylece her hücre en az 48 dp genişliğinde (dokunma hedefi) kalır.
class HaftaSeridi extends StatelessWidget {
  final List<String> tarihler;
  final String secili, bugun;
  final ValueChanged<String> degisti;
  const HaftaSeridi(
      {super.key,
      required this.tarihler,
      required this.secili,
      required this.bugun,
      required this.degisti});

  @override
  Widget build(BuildContext context) {
    final n = tarihler.length;
    if (n == 0) return const SizedBox.shrink();
    final renk = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: LayoutBuilder(builder: (context, kisit) {
        final adet = min(n, haftaSeridiHucreSayisi(kisit.maxWidth));
        final i = tarihler.indexOf(secili).clamp(0, n - 1);
        final baslangic = (i - adet ~/ 2).clamp(0, n - adet);
        final pencere = tarihler.sublist(baslangic, baslangic + adet);
        return Row(children: [
          for (final t in pencere)
            Expanded(
              child: GunHucresi(
                  tarih: t,
                  secili: t == secili,
                  bugun: t == bugun,
                  renk: renk,
                  tikla: () => degisti(t)),
            ),
        ]);
      }),
    );
  }
}

class GunHucresi extends StatelessWidget {
  final String tarih;
  final bool secili, bugun;
  final ColorScheme renk;
  final VoidCallback tikla;
  const GunHucresi(
      {super.key,
      required this.tarih,
      required this.secili,
      required this.bugun,
      required this.renk,
      required this.tikla});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(tarih);
    final haftaSonu = d.weekday >= 6;
    // hafta sonu biraz soluk (onSurfaceVariant) ama yarı saydam değil: saydam renk AA kontrastın (4.5) altına düşer
    final yaziRenk = secili
        ? renk.onPrimary
        : (haftaSonu ? renk.onSurfaceVariant : renk.onSurface);
    final etiket =
        '${gunAdlari[d.weekday - 1]} ${d.day} ${ayAdlari[d.month - 1]}'
        '${bugun ? ', bugün' : ''}${secili ? ', seçili' : ''}';
    return Semantics(
        button: true,
        selected: secili,
        label: etiket,
        excludeSemantics: true,
        onTap: tikla,
        // dokunma alanı (ve anlam düğümü) hücrenin tamamıdır: görünen kutu yanlardan 2.5 dp daha dardır
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tikla,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: secili ? renk.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: secili
                        ? renk.primary
                        : (bugun
                            ? renk.primary.withValues(alpha: 0.7)
                            : renk.outlineVariant.withValues(alpha: 0.5)),
                    width: bugun && !secili ? 1.6 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: tikla,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  // büyük yazı ölçeğinde kısaltma / rakam hücreden taşmasın diye sığacak kadar küçülür
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(gunKisa[d.weekday - 1],
                          style: TextStyle(
                              color: yaziRenk,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${d.day}',
                          style: TextStyle(
                              color: yaziRenk,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}
