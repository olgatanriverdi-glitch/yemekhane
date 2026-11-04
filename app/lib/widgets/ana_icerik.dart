import 'package:flutter/material.dart';

import '../favoriler.dart';
import '../geri_bildirim.dart';
import '../gun_secimi.dart';
import '../kalori_hedefi.dart';
import '../models.dart';
import '../repository.dart';
import 'favori_seridi.dart';
import 'gun_gecisi.dart';
import 'gun_govdesi.dart';
import 'gun_secici.dart';
import 'ogun_bilgi.dart';
import 'simdi_seridi.dart';
import 'son_guncelleme.dart';

/// Menü yüklenmişken ana sayfanın gövdesi (home.dart'ın küçük kalması için ayrı dosyada): menü bandı, gün
/// başlığı ve haftası, favori şeridi, öğün sekmeleri, "şimdi" şeridi, aşağı çekip yenilenen gün gövdesi ve
/// son güncelleme notu. Durumu tutmaz; seçimler ve yenileme [AnaSayfa]'ya geri bildirilir.
class AnaIcerik extends StatelessWidget {
  final Universite uni;
  final Menu menu;

  /// Bugünün ve seçili günün tarihi ('yyyy-MM-dd').
  final String bugun, tarih;

  /// Seçili öğün türü; okulda yoksa okulun ilk öğünü gösterilir ([aktifOgun]).
  final String ogun;

  /// Son gün değişiminin yönü: 1 sonraki gün, -1 önceki gün, 0 yön yok ([GunGecisi]).
  final int yon;
  final Depo depo;
  final GeriBildirimDeposu geriBildirim;
  final FavoriDeposu favoriler;
  final KaloriHedefi kaloriHedefi;

  /// Şimdiki Türkiye saati ([SimdiSeridi]).
  final DateTime Function() simdi;
  final ValueChanged<String> gunSec;

  /// Favori şeridinden ya da yemek ayrıntısından bir gün ve öğün seçilince.
  final void Function(String tarih, String ogun) eslesmeyeGit;
  final ValueChanged<String> ogunSec;

  /// Aşağı çekip yenileme.
  final Future<void> Function() yenile;
  const AnaIcerik(
      {super.key,
      required this.uni,
      required this.menu,
      required this.bugun,
      required this.tarih,
      required this.ogun,
      required this.yon,
      required this.depo,
      required this.geriBildirim,
      required this.favoriler,
      required this.kaloriHedefi,
      required this.simdi,
      required this.gunSec,
      required this.eslesmeyeGit,
      required this.ogunSec,
      required this.yenile});

  @override
  Widget build(BuildContext context) {
    final tarihler = gunCubugu(menu, bugun, tarih);
    final gun = menu.gunler[tarih] ?? {};
    final turler = okulOgunleri(uni);
    final aktif = aktifOgun(uni, ogun);
    final anahtar = '$tarih$aktif';
    final bant = menuBandBilgisi(menu, bugun);
    return Column(children: [
      if (bant != null) MenuBandi(bilgi: bant),
      GunBasligi(
          tarihler: tarihler, secili: tarih, bugun: bugun, degisti: gunSec),
      HaftaSeridi(
          tarihler: tarihler, secili: tarih, bugun: bugun, degisti: gunSec),
      ListenableBuilder(
        listenable: favoriler,
        builder: (context, _) => FavoriSeridi(
            eslesmeler: favoriEslesmeleri(menu, bugun, favoriler.anahtarlar),
            bugun: bugun,
            seciliTarih: tarih,
            seciliOgun: aktif,
            git: eslesmeyeGit),
      ),
      OgunSecici(turler: turler, aktif: aktif, degisti: ogunSec),
      SimdiSeridi(
          ogun: aktif,
          saat: uni.saat(aktif),
          bugunMu: tarih == bugun,
          simdi: simdi),
      Expanded(
        child: RefreshIndicator(
          onRefresh: yenile,
          child: GunKaydirma(
            tarihler: tarihler,
            secili: tarih,
            degisti: gunSec,
            child: GunGecisi(
              yon: yon,
              anahtar: anahtar,
              child: GunGovdesi(
                  gun: gun,
                  aktif: aktif,
                  tarih: tarih,
                  uni: uni,
                  depo: depo,
                  geriBildirim: geriBildirim,
                  favoriler: favoriler,
                  menu: menu,
                  bugun: bugun,
                  git: eslesmeyeGit,
                  kaloriHedefi: kaloriHedefi),
            ),
          ),
        ),
      ),
      if (menu.guncellendi != null)
        SonGuncelleme(
            zaman: menu.guncellendi!,
            cevrimdisi: depo.cevrimdisi,
            eskimis: uni.eskimis),
    ]);
  }
}
