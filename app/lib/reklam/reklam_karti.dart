import 'dart:async';

import 'package:flutter/material.dart';

import 'reklam_ayari.dart';
import 'reklam_servisi.dart';
import 'reklam_yoneticisi.dart';
import 'reklamsiz_gun.dart';
import 'uzak_ayar.dart';

/// Rahatsız etmeyen satır içi yerel reklam (ana ekranda öğün kartının altı, haftalık menüde 3. günden sonra, arama
/// sonuçlarında 5. sonuçtan sonra, yemek ayrıntısının altı). İçerikle birlikte kayar; yüklenene kadar ve
/// yüklenemezse hiç yer kaplamaz (boşluk bile bırakmaz), yüklenince [AnimatedSize] ile yumuşakça açılır
/// (hareket azaltma açıksa anında).
///
/// İstek, kart aynı gün + öğünde [ReklamYoneticisi.bekleme] (2 sn) kaldıktan sonra atılır; ondan önce kapanırsa
/// (gün / öğün gezerken) hiç istek gitmez. Reklamı aynı anda yalnızca tek bir [ReklamKarti] çizer
/// ([ReklamYoneticisi.sahiplen]); ikincisi boş kalır ve sahip bırakınca devralır. [yonetici] null ya da reklam
/// kapalıysa widget görünmez.
class ReklamKarti extends StatefulWidget {
  /// Bağlam anahtarı (ana ekranda gün + öğün, ör. '2026-11-05|lunch'); önbellek ve sahiplik [yerlesim] ile birlikte
  /// bununla tutulur.
  final String anahtar;
  final ReklamYoneticisi? yonetici;

  /// 'ana', 'hafta', 'arama' ya da 'detay' ([reklamYerlesimleri]); uzaktan ayarda yerleşim bazlı kapatılabilir.
  final String yerlesim;

  /// Uzun ekranda (>= 700 dp, yazı ölçeği <= 1.3) ve uzaktan ayar izin verirse görselli orta boy şablon.
  final bool buyukOlabilir;

  /// İstekten önce beklenecek süre; boşsa [ReklamYoneticisi.bekleme].
  final Duration? bekleme;

  /// Değişince (ör. arama sonuçları değişti) henüz reklam göstermiyorsa bekleme yeniden başlar; sonuç sabit
  /// kalınca istek atılır.
  final Object? tetik;
  const ReklamKarti(
      {super.key,
      required this.anahtar,
      required this.yonetici,
      this.yerlesim = yerlesimAna,
      this.buyukOlabilir = false,
      this.bekleme,
      this.tetik});

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
    } else if (eski.anahtar != widget.anahtar ||
        eski.yerlesim != widget.yerlesim) {
      // başka gün / öğün: eski reklam hemen bırakılır, yenisi için bekleme yeniden başlar
      _birak(widget.yonetici);
      _istenen = null;
    } else if (eski.tetik != widget.tetik && _sahipAnahtar == null) {
      // içerik değişti, henüz reklam yok: bekleme yeniden başlar
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
    if (y == null) return;
    if (!y.yerlesimIzinli(widget.yerlesim)) {
      // kapalı (uzaktan ayar, reklamsız gün...): istek yok, gösterilen varsa bırakılır
      _zaman?.cancel();
      _istenen = null;
      if (_sahipAnahtar != null) _birak(y);
      return;
    }
    final tema = Theme.of(context);
    final buyuk = widget.buyukOlabilir &&
        anaReklamBuyukMu(
            yukseklik: MediaQuery.sizeOf(context).height -
                MediaQuery.viewPaddingOf(context).vertical,
            yaziOlcegi: MediaQuery.textScalerOf(context).scale(1),
            izinli: y.ayar.anaBuyuk);
    final stil = ReklamStili.temadan(tema, buyuk: buyuk);
    final tam = y.anahtarOlustur('${widget.yerlesim}|${widget.anahtar}', stil);
    if (tam == _istenen) return;
    _istenen = tam;
    _stil = stil;
    _zaman?.cancel();
    if (y.taze(tam) != null) {
      // bellekteki reklam: ağ isteği yok, bekleme gerekmez
      _zaman = null;
      _devral();
      return;
    }
    // tema geçiş animasyonunda imza her karede değişir: bekleme her seferinde sıfırlanır, yalnız sonuncusu yüklenir
    _zaman = Timer(widget.bekleme ?? y.bekleme, _yukle);
  }

  Future<void> _yukle() async {
    final y = widget.yonetici;
    final tam = _istenen, stil = _stil;
    if (y == null || tam == null || stil == null) return;
    if (!await y.gosterilebilir(yerlesim: widget.yerlesim)) return;
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

  // Yönetici değişti: uzaktan ayar geldi, reklamsız gün başladı / bitti ya da başka bir kart reklamı bıraktı.
  void _sahipDegisti() {
    final y = widget.yonetici;
    if (!mounted || y == null) return;
    _kontrol();
    final tam = _istenen;
    if (tam != null && _sahipAnahtar != tam && y.taze(tam) != null) _devral();
    // ödüllü düğmesi ve görünürlük yeniden değerlendirilir
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final y = widget.yonetici;
    final a = _sahipAnahtar;
    final nesne = a == null || y == null || !y.yerlesimIzinli(widget.yerlesim)
        ? null
        : y.nesne(a);
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
    final renk = tema.colorScheme;
    final stil = _stil ?? ReklamStili.temadan(tema);
    final y = widget.yonetici;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Reklam',
      child: Padding(
        // üstte ve altta en az 16 dp boşluk: öğün kartındaki, listedeki ve yorumlardaki dokunulabilir öğelerle
        // karışmasın (yanlışlıkla tıklama)
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          // Card ile aynı köşe ve kenarlık
          decoration: BoxDecoration(
              color: stil.arkaPlan,
              borderRadius: BorderRadius.circular(stil.kose),
              border: Border.all(color: renk.outlineVariant)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: renk.secondaryContainer,
                      borderRadius: BorderRadius.circular(8)),
                  child: ExcludeSemantics(
                    child: Text('Reklam',
                        style: tema.textTheme.labelSmall?.copyWith(
                            color: renk.onSecondaryContainer,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Üni Yemek'i ücretsiz tutar",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: renk.onSurfaceVariant)),
                ),
              ]),
            ),
            ConstrainedBox(
                // Google şablon boyutları: küçük en az 90, en çok 200 dp; orta en az 355, en çok 500 dp
                constraints: stil.buyuk
                    ? const BoxConstraints(minHeight: 355, maxHeight: 500)
                    : const BoxConstraints(minHeight: 90, maxHeight: 200),
                // anahtar: reklam nesnesi değişince (ör. tema) alt ağaç yenilenir; platform görünümü eski reklamda kalmaz
                child: KeyedSubtree(
                    key: ObjectKey(nesne), child: nesne.olustur(context))),
            if (y != null && y.odulluAcik)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: renk.onSurfaceVariant,
                        textStyle: tema.textTheme.labelMedium),
                    onPressed: () => reklamsizGunIste(context, y),
                    child: const Text('Reklamları 24 saat kapat'),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
