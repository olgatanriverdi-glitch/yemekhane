import 'dart:async';

import 'package:flutter/material.dart';

import 'reklam_ayari.dart';
import 'reklam_servisi.dart';
import 'reklam_yoneticisi.dart';

/// Öğün kartının altındaki tek, rahatsız etmeyen yerel reklam. İçerikle birlikte kayar; yüklenene kadar ve
/// yüklenemezse hiç yer kaplamaz (boşluk bile bırakmaz), yüklenince [AnimatedSize] ile yumuşakça açılır
/// (hareket azaltma açıksa anında).
///
/// İstek, kart aynı gün + öğünde [ReklamYoneticisi.bekleme] (2 sn) kaldıktan sonra atılır; ondan önce kapanırsa
/// (gün / öğün gezerken) hiç istek gitmez. Reklamı aynı anda yalnızca tek bir [ReklamKarti] çizer
/// ([ReklamYoneticisi.sahiplen]); ikincisi boş kalır ve sahip bırakınca devralır. [yonetici] null ya da reklam
/// kapalıysa widget görünmez.
class ReklamKarti extends StatefulWidget {
  /// Gün + öğün anahtarı (ör. '2026-11-05|lunch'); önbellek ve sahiplik bununla tutulur.
  final String anahtar;
  final ReklamYoneticisi? yonetici;
  const ReklamKarti({super.key, required this.anahtar, required this.yonetici});

  @override
  State<ReklamKarti> createState() => _ReklamKartiState();
}

class _ReklamKartiState extends State<ReklamKarti> {
  Timer? _zaman;
  // Şu an istenen (tema imzalı) tam anahtar ve görünümü.
  String? _istenen;
  ReklamStili? _stil;
  // Bu widget'ın sahiplenip çizdiği tam anahtar.
  String? _sahipAnahtar;

  @override
  void initState() {
    super.initState();
    widget.yonetici?.addListener(_sahipDegisti);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _kontrol();
  }

  @override
  void didUpdateWidget(ReklamKarti eski) {
    super.didUpdateWidget(eski);
    if (eski.yonetici != widget.yonetici) {
      eski.yonetici?.removeListener(_sahipDegisti);
      _birak(eski.yonetici);
      widget.yonetici?.addListener(_sahipDegisti);
      _istenen = null;
    } else if (eski.anahtar != widget.anahtar) {
      // başka gün / öğün: eski reklam hemen bırakılır, yenisi için bekleme yeniden başlar
      _birak(widget.yonetici);
      _istenen = null;
    }
    _kontrol();
  }

  @override
  void dispose() {
    _zaman?.cancel();
    final y = widget.yonetici;
    y?.removeListener(_sahipDegisti);
    _birak(y, yenile: false);
    super.dispose();
  }

  void _birak(ReklamYoneticisi? y, {bool yenile = true}) {
    final a = _sahipAnahtar;
    _sahipAnahtar = null;
    if (a != null) y?.birak(a, this);
    if (yenile && mounted && a != null) setState(() {});
  }

  // Gün / öğün ya da görünüm (tema) değiştiyse yeni istek planlar; bellekte hazır reklam varsa bekleme olmadan dener.
  void _kontrol() {
    final y = widget.yonetici;
    if (y == null || !y.acik) return;
    final stil = ReklamStili.temadan(Theme.of(context));
    final tam = y.anahtarOlustur(widget.anahtar, stil);
    if (tam == _istenen) return;
    _istenen = tam;
    _stil = stil;
    _zaman?.cancel();
    if (y.nesne(tam) != null) {
      // bellekteki reklam: ağ isteği yok, bekleme gerekmez
      _zaman = null;
      _devral();
      return;
    }
    // tema geçiş animasyonunda imza her karede değişir: bekleme her seferinde sıfırlanır, yalnız sonuncusu yüklenir
    _zaman = Timer(y.bekleme, _yukle);
  }

  Future<void> _yukle() async {
    final y = widget.yonetici;
    final tam = _istenen, stil = _stil;
    if (y == null || tam == null || stil == null) return;
    if (!await y.gosterilebilir()) return;
    if (!mounted || tam != _istenen) return;
    final nesne = await y.iste(tam, stil);
    if (!mounted || tam != _istenen || nesne == null) return;
    _devral();
  }

  // Başka bir widget göstermiyorsa reklamı sahiplenir; gösteriyorsa boş kalır, sahip bırakınca [_sahipDegisti] dener.
  void _devral() {
    final y = widget.yonetici, tam = _istenen;
    if (y == null || tam == null || _sahipAnahtar == tam) return;
    if (!y.sahiplen(tam, this)) return;
    final eski = _sahipAnahtar;
    setState(() => _sahipAnahtar = tam);
    if (eski != null) y.birak(eski, this);
  }

  void _sahipDegisti() {
    final y = widget.yonetici, tam = _istenen;
    if (!mounted || y == null || tam == null || _sahipAnahtar == tam) return;
    if (y.nesne(tam) != null) _devral();
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.yonetici;
    final a = _sahipAnahtar;
    final nesne = a == null ? null : y?.nesne(a);
    final hareketYok = MediaQuery.disableAnimationsOf(context);
    final icerik = nesne == null
        ? const SizedBox(width: double.infinity)
        : _kart(context, nesne);
    // hareket azaltma açıkken animasyonsuz (sıfır süreli AnimatedSize yerleşim sırasında kendini kirletir)
    if (hareketYok) return icerik;
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: icerik,
    );
  }

  Widget _kart(BuildContext context, ReklamNesnesi nesne) {
    final tema = Theme.of(context);
    final stil = _stil ?? ReklamStili.temadan(tema);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Reklam',
      child: Padding(
        // üstte ve altta geniş boşluk: öğün kartındaki ve yorumlardaki dokunulabilir öğelerle karışmasın
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: ExcludeSemantics(
              child: Text('Reklam',
                  style: tema.textTheme.labelMedium
                      ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: stil.arkaPlan,
                borderRadius: BorderRadius.circular(stil.kose),
                border: Border.all(color: tema.colorScheme.outlineVariant)),
            child: ConstrainedBox(
                // Google'ın küçük şablon boyutu: en az 90, en çok 200 dp
                constraints:
                    const BoxConstraints(minHeight: 90, maxHeight: 200),
                child: nesne.olustur(context)),
          ),
        ]),
      ),
    );
  }
}
