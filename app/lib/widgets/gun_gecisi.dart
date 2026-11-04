import 'package:flutter/material.dart';

/// Gün / öğün içeriğinin geçişi. [yon] 1 ise sonraki gün (yeni içerik sağdan kayarak ve solarak gelir, eskisi
/// sola çıkar), -1 ise önceki gün (ters yön), 0 ise (öğün değişimi, yükleme) yalnızca solma. [anahtar] içeriği
/// ayırt eder; değişince geçiş oynar. Hareket kapalıysa (erişilebilirlik) geçiş anında olur.
class GunGecisi extends StatefulWidget {
  final int yon;
  final String anahtar;
  final Widget child;
  const GunGecisi(
      {super.key,
      required this.yon,
      required this.anahtar,
      required this.child});

  @override
  State<GunGecisi> createState() => _GunGecisiState();
}

class _GunGecisiState extends State<GunGecisi> {
  // İçeriğin kalıcı anahtarı. Çıkan içeriğin geçiş sarmalayıcısı yön değişince yeniden üretilir (kayma eklenir ya da
  // kalkar); anahtar olmasa çıkan içerik her gün değişiminde baştan kurulurdu (durumu sıfırlanır, puan ve yorum
  // istekleri yeniden atılırdı). Her yeni gün / öğün için yeni anahtar üretilir: aynı sayfaya hızla dönülürse
  // çıkan ve giren içerik aynı anahtarı paylaşmaz.
  GlobalKey _icerikAnahtari = GlobalKey();

  @override
  void didUpdateWidget(GunGecisi eski) {
    super.didUpdateWidget(eski);
    if (eski.anahtar != widget.anahtar) _icerikAnahtari = GlobalKey();
  }

  Widget _gecis(Widget c, Animation<double> anim) {
    if (widget.yon == 0) return FadeTransition(opacity: anim, child: c);
    // yeni içerik gidilen yönden gelir, eski içerik ters yöne çıkar
    final giris = c.key == ValueKey<String>(widget.anahtar);
    final x = (giris ? 0.08 : -0.08) * widget.yon;
    return FadeTransition(
        opacity: anim,
        child: SlideTransition(
            position: Tween<Offset>(begin: Offset(x, 0), end: Offset.zero)
                .animate(anim),
            child: c));
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        // her yapıda yeni bir işlev: çıkan içeriğin geçişi yeni yönle yeniden üretilsin
        transitionBuilder: (c, anim) => _gecis(c, anim),
        layoutBuilder: (cur, onceki) => Stack(
            alignment: Alignment.topCenter,
            children: [...onceki, if (cur != null) cur]),
        child: KeyedSubtree(
            key: ValueKey(widget.anahtar),
            child: KeyedSubtree(key: _icerikAnahtari, child: widget.child)),
      );
}

/// Yatay hızlı kaydırmayla gün değiştirme: sola kaydırma [tarihler] içinde sonraki, sağa kaydırma önceki gün
/// ([degisti] ile bildirilir). Dokunuşları ve dikey kaydırmayı engellemez (içerik aşağı çekip yenilenebilir).
class GunKaydirma extends StatelessWidget {
  final List<String> tarihler;
  final String secili;
  final ValueChanged<String> degisti;
  final Widget child;
  const GunKaydirma(
      {super.key,
      required this.tarihler,
      required this.secili,
      required this.degisti,
      required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          final i = tarihler.indexOf(secili);
          if (v < -250 && i >= 0 && i < tarihler.length - 1) {
            degisti(tarihler[i + 1]);
          }
          if (v > 250 && i > 0) degisti(tarihler[i - 1]);
        },
        child: child,
      );
}
