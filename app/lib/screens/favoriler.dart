import 'package:flutter/material.dart';

import '../favoriler.dart';
import '../models.dart';
import '../widgets/ogun_bilgi.dart';

/// Favori yemeklerin listesi: ad, seçili okulun menüsünde bir sonra görüneceği gün ve kaldırma düğmesi.
/// Okul ya da menü yoksa (ilk açılış) tarih satırı gösterilmez.
class FavorilerSayfasi extends StatelessWidget {
  final FavoriDeposu favoriler;
  final Universite? uni;
  final Menu? menu;

  /// 'yyyy-MM-dd'; sıradaki görünüm bugünden başlayarak aranır.
  final String bugun;
  const FavorilerSayfasi(
      {super.key,
      required this.favoriler,
      required this.bugun,
      this.uni,
      this.menu});

  void _cikar(BuildContext context, Favori f) {
    favoriler.cikar(f.anahtar);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${f.ad} favorilerden çıkarıldı'),
        action: SnackBarAction(
            label: 'Geri al', onPressed: () => favoriler.ekle(f.anahtar, f.ad)),
      ));
  }

  /// Her favorinin menüde bir sonraki görünümü (anahtar -> eşleşme); menüde olmayanlar yoktur.
  Map<String, FavoriEslesme> _siradakiler() {
    final m = menu;
    if (m == null) return const {};
    final sonuc = <String, FavoriEslesme>{};
    for (final e
        in favoriEslesmeleri(m, bugun, favoriler.anahtarlar, gunSayisi: 366)) {
      sonuc.putIfAbsent(e.anahtar, () => e);
    }
    return sonuc;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Favoriler')),
      body: ListenableBuilder(
        listenable: favoriler,
        builder: (context, _) {
          final liste = favoriler.liste;
          if (liste.isEmpty) return const _Bos();
          final siradaki = _siradakiler();
          final tarihGoster = menu != null;
          return Column(children: [
            if (tarihGoster && uni != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tarihler ${uni!.ad} menüsüne göre',
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final f = liste[i];
                  final e = siradaki[f.anahtar];
                  return ListTile(
                    key: ValueKey(f.anahtar),
                    leading:
                        Icon(Icons.favorite, color: tema.colorScheme.primary),
                    title: Text(f.ad,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    subtitle: !tarihGoster
                        ? null
                        : Text(e == null
                            ? 'Yayınlanan menüde görünmüyor'
                            : 'Sıradaki: ${favoriGunEtiketi(e.tarih, bugun, tamTarih: true)} (${kucukTr(ogunAdlari[e.ogun] ?? e.ogun)})'),
                    trailing: IconButton(
                        onPressed: () => _cikar(context, f),
                        // ekran okuyucu hangi yemeğin çıkarılacağını duyar; tooltip metni aynı kalır
                        icon: Icon(Icons.delete_outline,
                            semanticLabel:
                                favoriDugmeEtiketi(f.ad, favori: true)),
                        tooltip: 'Favorilerden çıkar'),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Bos extends StatelessWidget {
  const _Bos();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(
              child: Icon(Icons.favorite_border,
                  size: 56, color: tema.colorScheme.primary)),
          const SizedBox(height: 16),
          Text('Yemeklerin yanındaki kalbe dokunarak favori ekleyebilirsin.',
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium
                  ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
