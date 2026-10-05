import 'package:flutter/material.dart';

import '../models.dart';

/// Fotoğrafı tam ekrana yakın bir pencerede açar; iki parmakla yakınlaştırılabilir.
void fotoAc(BuildContext context, String url, String baslik) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(children: [
        SizedBox(
          width: double.infinity,
          height: 460,
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 48)),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filledTonal(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
              tooltip: 'Kapat'),
        ),
        Positioned(
          left: 16,
          right: 64,
          bottom: 14,
          child: Text(baslik,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    ),
  );
}

/// Öğünün ana yemeğini büyük fotoğrafla öne çıkaran kart ("Bugünün yemeği").
/// Fotoğraf: okulun yayınladığı tabldot fotoğrafı varsa o, yoksa ana yemeğin örnek fotoğrafı; ikisi de yoksa renkli bir zemin.
class GununYemegiKarti extends StatelessWidget {
  final String etiket; // 'Bugünün yemeği'
  final YemekOgesi ana;
  final String? fotoUrl;
  final bool
      fotoYaklasik; // tabldot fotoğrafı aynı menünün değil, benzer bir menünün fotoğrafı
  final bool tabldotFoto;
  final int? toplamKcal;
  final Widget? puan;
  const GununYemegiKarti(
      {super.key,
      required this.etiket,
      required this.ana,
      this.fotoUrl,
      this.fotoYaklasik = false,
      this.tabldotFoto = false,
      this.toplamKcal,
      this.puan});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    final zemin = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [renk.primaryContainer, renk.tertiaryContainer],
        ),
      ),
      child: Center(
          child: Icon(Icons.restaurant_rounded,
              size: 64, color: renk.onPrimaryContainer.withValues(alpha: 0.5))),
    );
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: renk.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 220,
          child: Stack(fit: StackFit.expand, children: [
            if (fotoUrl == null)
              zemin
            else
              InkWell(
                onTap: () => fotoAc(context, fotoUrl!, ana.ad),
                child: Image.network(
                  fotoUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, p) => p == null
                      ? child
                      : Container(color: renk.surfaceContainerHighest),
                  errorBuilder: (c, e, s) => zemin,
                ),
              ),
            // yazının okunması için alttan koyulaşan örtü
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72)
                    ],
                    stops: const [0.45, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: renk.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(buyukTr(etiket),
                    style: TextStyle(
                        color: renk.onPrimary,
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ana.ad,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.headlineSmall?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    if (fotoUrl != null && tabldotFoto && fotoYaklasik)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Örnek fotoğraf · benzer menü',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    if (fotoUrl != null && !tabldotFoto)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Örnek fotoğraf',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                  ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (ana.kcal != null)
                  Text('${ana.kcal} kkal',
                      style: tema.textTheme.bodyMedium
                          ?.copyWith(color: renk.onSurfaceVariant)),
                if (toplamKcal != null)
                  Text('Öğün toplamı $toplamKcal kkal',
                      style: tema.textTheme.bodyMedium
                          ?.copyWith(color: renk.onSurfaceVariant)),
                if (puan != null) puan!,
              ]),
        ),
      ]),
    );
  }
}

/// Menü yüklenirken dönen daire yerine ekranın iskeletini nabız gibi atan gri bloklarla gösterir.
class YuklemeIskeleti extends StatefulWidget {
  const YuklemeIskeleti({super.key});
  @override
  State<YuklemeIskeleti> createState() => _YuklemeIskeletiState();
}

class _YuklemeIskeletiState extends State<YuklemeIskeleti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);
  late final Animation<double> _opaklik = Tween<double>(begin: 0.4, end: 1)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _blok(BuildContext context, double yukseklik,
      {double? genislik, double yaricap = 12}) {
    return Container(
      width: genislik,
      height: yukseklik,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(yaricap)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Menü yükleniyor',
      child: FadeTransition(
        opacity: _opaklik,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Center(child: _blok(context, 26, genislik: 120)),
            const SizedBox(height: 8),
            Center(child: _blok(context, 14, genislik: 190)),
            const SizedBox(height: 16),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: _blok(context, 54, yaricap: 14))),
            ]),
            const SizedBox(height: 14),
            _blok(context, 40, yaricap: 20),
            const SizedBox(height: 16),
            _blok(context, 220, yaricap: 28),
            const SizedBox(height: 12),
            _blok(context, 280, yaricap: 24),
          ],
        ),
      ),
    );
  }
}
