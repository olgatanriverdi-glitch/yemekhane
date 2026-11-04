import 'package:flutter/material.dart';

import '../favoriler.dart';
import '../hafta.dart';
import '../models.dart';
import '../paylas.dart';
import '../paylasim.dart';
import '../widgets/ogun_bilgi.dart';

/// Haftalık menü: seçili öğün türü için haftanın (pazartesiden pazara) 7 günü, her gün bir kart.
/// Başlangıçta [tarih]in haftası açılır; oklar yalnızca menünün kapsadığı haftalara götürür. Bir karta
/// dokununca sayfa o günün tarihi ('yyyy-MM-dd') ile kapanır, çağıran (ana sayfa) o güne geçer.
/// Menü aralığının dışındaki günlerin kartları dokunulmaz. Üst çubuktaki "Haftayı paylaş" haftanın
/// metnini [paylasim] ile paylaşır.
class HaftaSayfasi extends StatefulWidget {
  final Universite uni;
  final Menu menu;

  /// 'yyyy-MM-dd'; "Bugün" rozeti bu güne konur.
  final String bugun;

  /// 'yyyy-MM-dd'; açılışta bu günün haftası gösterilir.
  final String tarih;

  /// Gösterilen öğün türü ('lunch' vb.).
  final String ogun;

  /// Verilirse favori yemekler kalp ve kalın yazıyla öne çıkar.
  final FavoriDeposu? favoriler;
  final PaylasimServisi paylasim;
  const HaftaSayfasi(
      {super.key,
      required this.uni,
      required this.menu,
      required this.bugun,
      required this.tarih,
      required this.ogun,
      required this.paylasim,
      this.favoriler});

  @override
  State<HaftaSayfasi> createState() => _HaftaSayfasiState();
}

class _HaftaSayfasiState extends State<HaftaSayfasi> {
  late String _pazartesi = haftaBaslangici(widget.tarih);
  // favori deposu yoksa hiçbir şey dinlenmez
  late final Listenable _favoriDegisimi = Listenable.merge([widget.favoriler]);

  void _haftayaGit(int fark) =>
      setState(() => _pazartesi = tarihEkle(_pazartesi, 7 * fark));

  void _paylas() => metniPaylas(ScaffoldMessenger.of(context), widget.paylasim,
      haftaMetni(widget.uni, widget.menu, _pazartesi, widget.ogun),
      konu: '${widget.uni.ad} haftalık menü');

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final tarihler = menu.tarihler;
    final ilk = tarihler.firstOrNull, son = tarihler.lastOrNull;
    final gunler = haftaGunleri(menu, _pazartesi, widget.ogun);
    final ogunAd = ogunAdlari[widget.ogun] ?? widget.ogun;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalık menü'),
        actions: [
          IconButton(
              onPressed: gunler.any((g) => g.veriVar) ? _paylas : null,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Haftayı paylaş'),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          _HaftaBasligi(
              aralik: haftaAraligi(_pazartesi),
              altBaslik: '$ogunAd · ${widget.uni.ad}',
              onceki: oncekiHaftaVar(menu, _pazartesi)
                  ? () => _haftayaGit(-1)
                  : null,
              sonraki: sonrakiHaftaVar(menu, _pazartesi)
                  ? () => _haftayaGit(1)
                  : null),
          Expanded(
            child: ListenableBuilder(
              listenable: _favoriDegisimi,
              builder: (context, _) {
                final favoriler = widget.favoriler?.anahtarlar ?? const {};
                return AnimatedSwitcher(
                  // hareket kapalıysa (erişilebilirlik) hafta geçişi anında olur
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: ListView(
                    key: ValueKey(_pazartesi),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      for (final g in gunler)
                        _GunKarti(
                            key: ValueKey('hafta-${g.tarih}'),
                            gun: g,
                            bugun: g.tarih == widget.bugun,
                            favoriler: favoriler,
                            // menü aralığının dışındaki gün ana sayfada açılamaz
                            sec: ilk != null &&
                                    g.tarih.compareTo(ilk) >= 0 &&
                                    g.tarih.compareTo(son!) <= 0
                                ? () => Navigator.of(context).pop(g.tarih)
                                : null),
                    ],
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Üstte "2 – 8 Kasım" aralığı, altında öğün ve okul; yanlarda önceki / sonraki hafta okları
/// (ana sayfadaki gün başlığıyla aynı görünüm). Menü aralığının dışına çıkılamayan ok pasiftir.
class _HaftaBasligi extends StatelessWidget {
  final String aralik, altBaslik;
  final VoidCallback? onceki, sonraki;
  const _HaftaBasligi(
      {required this.aralik,
      required this.altBaslik,
      required this.onceki,
      required this.sonraki});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(children: [
        IconButton.filledTonal(
            onPressed: onceki,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Önceki hafta'),
        Expanded(
          child: Column(children: [
            Semantics(
              header: true,
              child: Text(aralik,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Text(altBaslik,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ]),
        ),
        IconButton.filledTonal(
            onPressed: sonraki,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Sonraki hafta'),
      ]),
    );
  }
}

/// Bir günün kartı: gün başlığı ("Bugün" rozetli), yemekler virgüllü (ilk 4 + "+N", favoriler kalp ve kalın),
/// toplam kalori; menü yoksa açıklaması (tatil notu, "Hizmet yok", "Menü yayınlanmadı").
class _GunKarti extends StatelessWidget {
  final HaftaGunu gun;
  final bool bugun;

  /// Favori yemeklerin anahtarları.
  final Set<String> favoriler;

  /// Dokununca çağrılır; null ise kart dokunulmazdır.
  final VoidCallback? sec;
  const _GunKarti(
      {super.key,
      required this.gun,
      required this.bugun,
      required this.favoriler,
      required this.sec});

  bool _favoriMi(YemekOgesi o) =>
      o.anahtar != null && favoriler.contains(o.anahtar);

  /// Ekran okuyucu için kartın tamamını okuyan etiket.
  String _etiket(({List<YemekOgesi> gorunen, int gizli})? yemekler) {
    final parcalar = <String>[
      '${bugun ? 'Bugün, ' : ''}${gunTarihEtiketi(gun.tarih)}'
    ];
    if (yemekler == null) {
      parcalar.add(gun.mesaj);
    } else {
      parcalar.add([
        for (final o in yemekler.gorunen)
          _favoriMi(o) ? '${o.ad} (favori)' : o.ad
      ].join(', '));
      if (yemekler.gizli > 0) parcalar.add('${yemekler.gizli} yemek daha');
      if (gun.kcal != null) parcalar.add('Toplam ${gun.kcal} kkal');
    }
    return parcalar.join('. ');
  }

  IconData get _mesajIkonu => switch (gun.durum) {
        HaftaDurumu.tatil => Icons.celebration_outlined,
        HaftaDurumu.hizmetYok => Icons.weekend_outlined,
        _ => Icons.no_meals_outlined,
      };

  Widget _yemekler(
      BuildContext context, ({List<YemekOgesi> gorunen, int gizli}) yemekler) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    final kalp = MediaQuery.textScalerOf(context).scale(15);
    return Text.rich(TextSpan(style: tema.textTheme.bodyLarge, children: [
      for (var i = 0; i < yemekler.gorunen.length; i++) ...[
        if (i > 0) const TextSpan(text: ', '),
        if (_favoriMi(yemekler.gorunen[i]))
          WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(Icons.favorite, size: kalp, color: renk.primary),
              )),
        TextSpan(
            text: yemekler.gorunen[i].ad.trim(),
            style: _favoriMi(yemekler.gorunen[i])
                ? const TextStyle(fontWeight: FontWeight.w800)
                : null),
      ],
      if (yemekler.gizli > 0)
        TextSpan(
            text: ' +${yemekler.gizli}',
            style: TextStyle(
                color: renk.onSurfaceVariant, fontWeight: FontWeight.w600)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = tema.colorScheme;
    final yemekler = gun.durum == HaftaDurumu.menu
        ? haftaYemekleri(gun.yemekler, favoriler)
        : null;
    final soluk =
        tema.textTheme.bodyMedium?.copyWith(color: renk.onSurfaceVariant);
    return Semantics(
      container: true,
      button: sec != null,
      label: _etiket(yemekler),
      excludeSemantics: true,
      onTap: sec,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        // bugünün kartı birincil renkli çerçeveyle öne çıkar; diğerleri uygulamanın kart temasını kullanır
        shape: bugun
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: renk.primary, width: 2))
            : null,
        child: InkWell(
          onTap: sec,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(gunTarihEtiketi(gun.tarih),
                      style: tema.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (bugun)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: renk.primaryContainer,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('Bugün',
                        style: tema.textTheme.labelMedium?.copyWith(
                            color: renk.onPrimaryContainer,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
              const SizedBox(height: 8),
              if (yemekler != null) ...[
                _yemekler(context, yemekler),
                if (gun.kcal != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Toplam ${gun.kcal} kkal', style: soluk),
                  ),
              ] else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(_mesajIkonu, size: 20, color: renk.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(gun.mesaj, style: soluk)),
                ]),
            ]),
          ),
        ),
      ),
    );
  }
}
