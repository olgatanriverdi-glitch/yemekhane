import 'package:flutter/material.dart';

import '../favoriler.dart';
import '../models.dart';
import 'ogun_bilgi.dart';

/// Şeritte gösterilecek eşleşmeler: bugünküler varsa yalnızca onlar, yoksa hepsi. [eslesmeler]
/// [favoriEslesmeleri] çıktısıdır (tarih, öğün sırasında).
List<FavoriEslesme> seritHedefleri(
    List<FavoriEslesme> eslesmeler, String bugun) {
  final bugunku = eslesmeler.where((e) => e.tarih == bugun).toList();
  return bugunku.isNotEmpty ? bugunku : eslesmeler;
}

String _kisalt(String ad) =>
    ad.length > 28 ? '${ad.substring(0, 27).trimRight()}…' : ad;

String _ogunEk(String ogun) => kucukTr(ogunAdlari[ogun] ?? ogun);

/// Şerit metni. Bugün varsa "Bugün menüde: Mantı (öğle)", yoksa "Favorin Mantı: Cuma (öğle)";
/// birden çok eşleşmede ilk 2'si yazılır, kalanı "+N" olur. [hedefler] boş olmamalıdır.
String favoriSeridiMetni(List<FavoriEslesme> hedefler, String bugun) {
  final ilkler = hedefler.take(2).toList();
  final kalan = hedefler.length - ilkler.length;
  final ek = kalan > 0 ? ' +$kalan' : '';
  if (hedefler.first.tarih == bugun) {
    final liste =
        ilkler.map((e) => '${_kisalt(e.ad)} (${_ogunEk(e.ogun)})').join(', ');
    return 'Bugün menüde: $liste$ek';
  }
  String zaman(FavoriEslesme e) =>
      '${favoriGunEtiketi(e.tarih, bugun)}, ${_ogunEk(e.ogun)}';
  if (hedefler.length == 1) {
    final e = hedefler.first;
    return 'Favorin ${_kisalt(e.ad)}: ${favoriGunEtiketi(e.tarih, bugun)} (${_ogunEk(e.ogun)})';
  }
  final liste = ilkler.map((e) => '${_kisalt(e.ad)} (${zaman(e)})').join(', ');
  return 'Favorilerin: $liste$ek';
}

/// Dokununca gidilecek eşleşme: seçili gün / öğün zaten bir eşleşmedeyse sıradaki (sonda başa döner),
/// değilse ilki. [hedefler] boş olmamalıdır.
FavoriEslesme sonrakiHedef(
    List<FavoriEslesme> hedefler, String tarih, String ogun) {
  final i = hedefler.lastIndexWhere((e) => e.tarih == tarih && e.ogun == ogun);
  if (i < 0 || i + 1 >= hedefler.length) return hedefler.first;
  return hedefler[i + 1];
}

/// Gün seçicinin altındaki favori şeridi: önümüzdeki günlerde menüde çıkacak favoriler.
/// Eşleşme yoksa görünmez. Dokununca o gün ve öğüne geçer ([git]); birden çok eşleşmede
/// tekrar dokunmak sıradakine götürür.
class FavoriSeridi extends StatelessWidget {
  final List<FavoriEslesme> eslesmeler;
  final String bugun, seciliTarih, seciliOgun;
  final void Function(String tarih, String ogun) git;
  const FavoriSeridi(
      {super.key,
      required this.eslesmeler,
      required this.bugun,
      required this.seciliTarih,
      required this.seciliOgun,
      required this.git});

  @override
  Widget build(BuildContext context) {
    final hedefler = seritHedefleri(eslesmeler, bugun);
    final renk = Theme.of(context).colorScheme;
    Widget? serit;
    if (hedefler.isNotEmpty) {
      final metin = favoriSeridiMetni(hedefler, bugun);
      serit = Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Semantics(
          button: true,
          label: metin,
          excludeSemantics: true,
          onTap: () {
            final e = sonrakiHedef(hedefler, seciliTarih, seciliOgun);
            git(e.tarih, e.ogun);
          },
          child: Material(
            color: renk.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                final e = sonrakiHedef(hedefler, seciliTarih, seciliOgun);
                git(e.tarih, e.ogun);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Icon(Icons.favorite,
                        size: 18, color: renk.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(metin,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: renk.onSecondaryContainer,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedSize(
      // şerit belirirken / kaybolurken altındaki içerik sıçramasın; hareket kapalıysa anında
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: serit ?? const SizedBox(width: double.infinity, height: 0),
    );
  }
}
