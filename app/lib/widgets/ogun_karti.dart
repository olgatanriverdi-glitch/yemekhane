import 'package:flutter/material.dart';

import '../favoriler.dart';
import '../geri_bildirim.dart';
import '../kalori_hedefi.dart';
import '../models.dart';
import '../tema.dart' show TemaImzasi;
import '../reklam/reklam_karti.dart';
import '../reklam/reklam_yoneticisi.dart';
import '../reklam/uzak_ayar.dart' show yerlesimAna;
import '../screens/geri_bildirim.dart';

/// Bir öğünün kartı: toplam kalori, servis saati, yemek satırları (puanlı) ve yorumlar.
class OgunKarti extends StatefulWidget {
  final Ogun ogun;
  final int? fiyat;
  final ServisSaati? saat;
  final String? fotoUrl;
  final bool fotoYaklasik;
  final String? Function(String?) yemekFoto;
  final GeriBildirimDeposu geriBildirim;
  final String slot;
  final String uniId;

  /// Verilirse anahtarı olan her yemek satırında favori kalbi gösterilir.
  final FavoriDeposu? favoriler;

  /// Verilirse yemek satırının adına, resmine ve puan satırına dokununca çağrılır (yemek ayrıntı sayfası).
  /// Sayfa kapanınca satırlardaki puanlar yeniden okunur.
  final Future<void> Function(YemekOgesi yemek)? yemekAc;

  /// Verilirse ve hedef açıksa öğün özetinde öğünün günlük hedefe oranı gösterilir (kalorisiz öğünde gösterilmez).
  final KaloriHedefi? kaloriHedefi;

  /// Aynı günün öğle + akşam toplam kalorisi ([ogleAksamKalorisi]); hedef açıkken özette ayrı satır olur.
  final int? ogleAksamKcal;

  /// Verilirse öğün kartının altında, "Öğün yorumları"ndan önce tek bir yerel reklam kartı olabilir (kapalıysa
  /// ya da yüklenemezse hiç yer kaplamaz). [reklamAnahtari] gün + öğündür (ör. '2026-11-05|lunch').
  final ReklamYoneticisi? reklam;
  final String? reklamAnahtari;
  const OgunKarti(
      {super.key,
      required this.ogun,
      this.fiyat,
      this.saat,
      this.fotoUrl,
      this.fotoYaklasik = false,
      required this.yemekFoto,
      required this.geriBildirim,
      required this.slot,
      required this.uniId,
      this.favoriler,
      this.yemekAc,
      this.kaloriHedefi,
      this.ogleAksamKcal,
      this.reklam,
      this.reklamAnahtari});

  @override
  State<OgunKarti> createState() => _OgunKartiState();
}

class _OgunKartiState extends State<OgunKarti> {
  YemekPuanlari? _puanlar;

  @override
  void initState() {
    super.initState();
    _puanlariYukle();
  }

  @override
  void didUpdateWidget(OgunKarti eski) {
    super.didUpdateWidget(eski);
    // menü yenilenince (aşağı çekme) aynı slot için yeni Ogun örneği gelir: puanlar da tazelenir
    if (eski.slot != widget.slot ||
        eski.uniId != widget.uniId ||
        !identical(eski.ogun, widget.ogun)) {
      _puanlar = null;
      _puanlariYukle();
    }
  }

  String? _yemekSlotu(YemekOgesi o) =>
      o.anahtar == null ? null : yemekSlotKimligi(widget.uniId, o.anahtar!);

  Future<void> _puanlariYukle() async {
    final slot = widget.slot;
    final slotlar = [
      for (final o in widget.ogun.ogeler)
        if (_yemekSlotu(o) != null) _yemekSlotu(o)!
    ];
    try {
      final p = await widget.geriBildirim.puanlar(slotlar);
      if (mounted && slot == widget.slot) setState(() => _puanlar = p);
    } catch (_) {
      // internet yoksa puan satırı "Puanla" olarak kalır
    }
  }

  /// Yemek ayrıntı sayfasını açar; dönünce (oy verilmiş olabilir) puanlar yeniden okunur.
  Future<void> _detayAc(YemekOgesi o) async {
    await widget.yemekAc?.call(o);
    if (mounted) _puanlariYukle();
  }

  Widget _puanSatiri(YemekOgesi o) {
    final tema = Theme.of(context);
    final slot = _yemekSlotu(o)!;
    final ozet = _puanlar?.ozet[slot];
    final benim = _puanlar?.benim[slot];
    final var_ = ozet?.ortalama != null;
    final metin = var_
        ? '${ozet!.ortalama!.toStringAsFixed(1)} · ${ozet.adet} oy${benim != null ? ' · senin: $benim' : ''}'
        : 'Puanla';
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(var_ ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16, color: tema.colorScheme.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(metin,
              style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.primary,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Future<void> _favoriDegistir(YemekOgesi o) async {
    final eklendi = await widget.favoriler!.degistir(o.anahtar!, o.ad);
    if (!eklendi && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text(
                'En fazla ${FavoriDeposu.enCok} favori ekleyebilirsin. Önce birini çıkar.')));
    }
  }

  /// Dolu / boş kalp. Dokunma hedefi 48dp; renkler temadan (seçiliyken birincil renk).
  Widget _favoriKalbi(YemekOgesi o) => ListenableBuilder(
        listenable: widget.favoriler!,
        builder: (context, _) {
          final fav = widget.favoriler!.varMi(o.anahtar!);
          // ekran okuyucu yemek adını da duyar (simgenin semanticLabel'i düğümün etiketi olur);
          // tooltip (görsel ipucu) metni aynı kalır
          final etiket = favoriDugmeEtiketi(o.ad, favori: fav);
          return IconButton(
            isSelected: fav,
            tooltip: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
            icon: Icon(Icons.favorite_border, semanticLabel: etiket),
            selectedIcon: Icon(Icons.favorite, semanticLabel: etiket),
            onPressed: () => _favoriDegistir(o),
          );
        },
      );

  Widget _kcalPill(YemekOgesi o, ThemeData tema) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: tema.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20)),
        child: Text('${o.kcal} kkal',
            style: tema.textTheme.labelMedium
                ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      );

  Widget _yemekSatiri(YemekOgesi o, ThemeData tema) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(builder: (context, kisit) {
          // dar ekran ya da büyük yazıda kalori hapı sağa değil adın altına geçer (taşma olmasın)
          final dar = kisit.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(16) > 22;
          // anahtarsız yemeğin puanı / ayrıntı sayfası yoktur (kalbi ve puan satırı gibi): satır dokunulmaz
          final ac = o.anahtar != null && widget.yemekAc != null;
          return Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: ac ? () => _detayAc(o) : null,
                child: Row(children: [
                  YemekResmi(url: widget.yemekFoto(o.img), ad: o.ad),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(o.ad,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.titleMedium),
                        if (o.anahtar != null) _puanSatiri(o),
                        if (dar && o.kcal != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _kcalPill(o, tema)),
                      ])),
                ]),
              ),
            ),
            if (!dar && o.kcal != null) ...[
              const SizedBox(width: 10),
              _kcalPill(o, tema),
            ],
            if (o.anahtar != null && widget.favoriler != null) _favoriKalbi(o),
          ]);
        }),
      );

  /// Öğün özeti; kalori hedefi değişince (Ayarlar'dan) yalnızca bu kısım yenilenir.
  Widget _ozet() {
    final kalori = widget.kaloriHedefi;
    Widget ozet(int? hedef) => OgunOzeti(
        kcal: widget.ogun.kcal,
        saat: widget.saat,
        fiyat: widget.fiyat,
        hedef: hedef,
        ogleAksamKcal: widget.ogleAksamKcal);
    if (kalori == null) return ozet(null);
    return ListenableBuilder(
        listenable: kalori,
        builder: (context, _) => ozet(kalori.acik ? kalori.hedef : null));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ogun = widget.ogun;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.fotoUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: Stack(fit: StackFit.expand, children: [
                  Image.network(
                    widget.fotoUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, child, p) => p == null
                        ? child
                        : Container(
                            color: tema.colorScheme.surfaceContainerHighest,
                            child: const Center(
                                child: CircularProgressIndicator())),
                    errorBuilder: (c, e, s) => Container(
                        color: tema.colorScheme.surfaceContainerHighest,
                        child: const Center(
                            child: Icon(Icons.restaurant, size: 40))),
                  ),
                  if (widget.fotoYaklasik)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: tema.colorScheme.inverseSurface
                                .withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('Örnek fotoğraf · benzer menü',
                            style: TextStyle(
                                color: tema.colorScheme.onInverseSurface,
                                fontSize: 12)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ozet(),
              for (var i = 0; i < ogun.ogeler.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _yemekSatiri(ogun.ogeler[i], tema),
              ],
              if (ogun.ogeler.any((o) => o.img != null))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.info_outline,
                              size: 16,
                              color: tema.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'Yemeklerin yanındaki küçük resimler örnektir (Wikimedia Commons, CC lisanslı); okuldaki yemek birebir aynı görünmeyebilir.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                  color: tema.colorScheme.onSurfaceVariant)),
                        ),
                      ]),
                ),
            ]),
          ),
        ),
        if (widget.reklam != null)
          ReklamKarti(
              anahtar: widget.reklamAnahtari ?? widget.slot,
              yonetici: widget.reklam,
              yerlesim: yerlesimAna,
              // uzun ekranda görselli (medium), değilse küçük şablon
              buyukOlabilir: true),
        const SizedBox(height: 12),
        GeriBildirimBolumu(
            key: ValueKey(widget.slot),
            depo: widget.geriBildirim,
            slot: widget.slot,
            puanGoster: false,
            baslik: 'Öğün yorumları'),
      ],
    );
  }
}

/// Yemek adından uygun simge (Türkçe harf duyarsız; bilinmeyen -> tabak/çatal).
IconData yemekIkonu(String ad) {
  final k = sadeTr(ad);
  bool var_(List<String> anahtarlar) => anahtarlar.any(k.contains);
  final kelimeler = k.split(RegExp(r'[^a-z0-9]+'));
  if (var_(['corba'])) return Icons.soup_kitchen;
  if (var_(
      ['meyve suyu', 'ayran', 'icecek', 'komposto', 'serbet', 'limonata'])) {
    return Icons.local_drink;
  }
  if (var_(['tatli', 'baklava', 'sutlac', 'puding', 'revani', 'kadayif']) ||
      kelimeler.any((w) => w == 'kek' || w.endsWith('kek'))) {
    return Icons.cake;
  }
  if (var_(['salata', 'cacik'])) return Icons.eco;
  if (var_(['pilav', 'makarna', 'bulgur', 'eriste', 'spagetti', 'noodle'])) {
    return Icons.rice_bowl;
  }
  if (var_(['meyve', 'muz', 'elma', 'portakal', 'mandalina', 'armut'])) {
    return Icons.apple;
  }
  return Icons.restaurant;
}

/// Yemek satırının başındaki küçük yuvarlak fotoğraf; yoksa ya da yüklenemezse yemek adından simgeli degrade zemin.
class YemekResmi extends StatelessWidget {
  final String? url;
  final String ad;
  const YemekResmi({super.key, this.url, this.ad = ''});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final yerTutucu = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              renk.primaryContainer,
              Color.alphaBlend(
                  renk.primary.withValues(alpha: 0.18), renk.primaryContainer)
            ]),
      ),
      child: Icon(yemekIkonu(ad), size: 24, color: renk.onPrimaryContainer),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 48,
        height: 48,
        child: url == null
            ? yerTutucu
            : Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: 144,
                errorBuilder: (c, e, s) => yerTutucu,
                // ilk kare gelene kadar (ilerleme bilgisi olmasa da) boş kalmasın
                frameBuilder: (c, child, kare, hemen) =>
                    (hemen || kare != null) ? child : yerTutucu,
              ),
      ),
    );
  }
}

/// Öğün kartının üstü: büyük toplam kalori, servis saati ve öğrenci fiyatı. Hiçbiri yoksa görünmez.
/// [hedef] (günlük kalori hedefi) doluysa ve öğünün kalorisi varsa ince bir ilerleme çubuğu, öğünün hedefe
/// oranı ("Bu öğün günlük hedefinin %37'si"), varsa öğle + akşam toplamı ve genel bilgi uyarısı eklenir;
/// kalorisiz öğünde bunların hiçbiri görünmez.
class OgunOzeti extends StatelessWidget {
  final int? kcal, fiyat;
  final ServisSaati? saat;

  /// Günlük kalori hedefi (kkal); boşsa hedef kapalıdır.
  final int? hedef;

  /// Aynı günün öğle + akşam toplam kalorisi; hedef gösterilirken "Öğle + akşam: N kkal" satırı olur.
  final int? ogleAksamKcal;
  const OgunOzeti(
      {super.key,
      this.kcal,
      this.fiyat,
      this.saat,
      this.hedef,
      this.ogleAksamKcal});

  @override
  Widget build(BuildContext context) {
    if (kcal == null && fiyat == null && saat == null) {
      return const SizedBox.shrink();
    }
    final tema = Theme.of(context);
    final imza = TemaImzasi.of(context);
    final on = imza.zeminUstu;
    final hedefli = hedef != null && hedef! > 0 && (kcal ?? 0) > 0;
    Widget kucuk(IconData ikon, String metin) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, size: 18, color: on),
          const SizedBox(width: 6),
          Flexible(
            child: Text(metin,
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: on, fontWeight: FontWeight.w600)),
          ),
        ]);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: imza.zemin,
          gradient: imza.degrade,
          borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (kcal != null)
          Row(children: [
            Icon(Icons.local_fire_department_outlined, size: 28, color: on),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Toplam $kcal kkal',
                  style: tema.textTheme.headlineSmall
                      ?.copyWith(color: on, fontWeight: FontWeight.w800)),
            ),
          ]),
        if (hedefli) ...[
          const SizedBox(height: 10),
          // çubuk süs: aynı bilgiyi altındaki yazı verir, ekran okuyucu "%37" diye ikinci kez okumasın
          ExcludeSemantics(
            child: LinearProgressIndicator(
              value: (kcal! / hedef!).clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: tema.colorScheme.primary,
              backgroundColor: on.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 6),
          Text(kaloriYuzdeMetni(kcal!, hedef!),
              style: tema.textTheme.bodyMedium
                  ?.copyWith(color: on, fontWeight: FontWeight.w600)),
          if (ogleAksamKcal != null)
            Text('Öğle + akşam: $ogleAksamKcal kkal',
                style: tema.textTheme.bodyMedium?.copyWith(color: on)),
        ],
        if (kcal != null && (saat != null || fiyat != null))
          const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 6, children: [
          if (saat != null)
            kucuk(Icons.schedule,
                saat!.yaklasik ? 'Genelde ${saat!.t}' : 'Servis ${saat!.t}'),
          if (fiyat != null) kucuk(Icons.payments_outlined, 'Öğrenci $fiyat ₺'),
        ]),
        if (hedefli) ...[
          const SizedBox(height: 8),
          Text('Genel bilgidir, tıbbi tavsiye değildir.',
              style: tema.textTheme.bodySmall?.copyWith(color: on)),
        ],
      ]),
    );
  }
}
