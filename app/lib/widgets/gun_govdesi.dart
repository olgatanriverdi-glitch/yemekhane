import 'package:flutter/material.dart';

import '../favoriler.dart';
import '../geri_bildirim.dart';
import '../kalori_hedefi.dart';
import '../models.dart';
import '../reklam/reklam_yoneticisi.dart';
import '../repository.dart';
import '../screens/yemek_detay.dart';
import 'durum_ekranlari.dart';
import 'ogun_bilgi.dart';
import 'ogun_karti.dart';

/// Seçili günün / öğünün gövdesi: menü kartı ya da "yemek yok" bilgisi.
class GunGovdesi extends StatelessWidget {
  final Map<String, Ogun> gun;

  /// Seçili öğün türü ('lunch' vb.).
  final String aktif;

  /// Seçili gün, 'yyyy-MM-dd'.
  final String tarih;
  final Universite uni;
  final Depo depo;
  final GeriBildirimDeposu geriBildirim;
  final FavoriDeposu favoriler;

  /// Okulun menüsü ve bugünün tarihi ('yyyy-MM-dd'): yemek ayrıntı sayfasındaki "Bu yemek ne zaman var" için.
  final Menu menu;
  final String bugun;

  /// Ayrıntı sayfasından bir gün ve öğün seçilince çağrılır (ana sayfa o gün / öğüne geçer).
  final void Function(String tarih, String ogun) git;

  /// Günlük kalori hedefi ayarı; verilmezse öğün kartında hedef gösterilmez.
  final KaloriHedefi? kaloriHedefi;

  /// Verilirse yalnızca dolu öğün kartının altında reklam olabilir (yemek yok / tatil ekranlarında asla).
  final ReklamYoneticisi? reklam;
  const GunGovdesi(
      {super.key,
      required this.gun,
      required this.aktif,
      required this.tarih,
      required this.uni,
      required this.depo,
      required this.geriBildirim,
      required this.favoriler,
      required this.menu,
      required this.bugun,
      required this.git,
      this.kaloriHedefi,
      this.reklam});

  /// Yemeğin ayrıntı sayfasını açar. Sayfa bir gün ve öğünle kapanırsa [git] çağrılır.
  Future<void> _yemekAc(BuildContext context, YemekOgesi yemek) async {
    final foto = depo.yemekFotoUrl(yemek.img);
    final anahtar = yemek.anahtar;
    final secilen = await Navigator.of(context).push<YemekGorunumu>(
        MaterialPageRoute(
            builder: (_) => YemekDetaySayfasi(
                yemek: yemek,
                uni: uni,
                menu: menu,
                bugun: bugun,
                foto: foto == null ? null : NetworkImage(foto),
                // küçük fotoğraf varsa Commons bilgisi (yüksek çözünürlük + atıf) sayfa açılınca arka planda aranır
                fotoBilgisi: foto == null || anahtar == null || anahtar.isEmpty
                    ? null
                    : () => depo.yemekBilgisi(anahtar),
                geriBildirim: geriBildirim,
                favoriler: favoriler,
                reklam: reklam)));
    if (secilen != null && context.mounted) git(secilen.tarih, secilen.ogun);
  }

  @override
  Widget build(BuildContext context) {
    final ogun = gun[aktif];
    final haftaSonu = DateTime.parse(tarih).weekday >= 6;
    final ogunAd = ogunAdlari[aktif]?.toLowerCase() ?? '';
    if (gun.isEmpty) {
      return YemekYok(
          baslik: 'Bu gün yemek yok',
          // veri yokluğundan "hizmet verilmiyor" sonucu çıkmaz (hafta sonu da olsa okul menü yayınlamamış olabilir)
          alt: 'Bu gün için menü yayınlanmamış.',
          ikon: haftaSonu ? Icons.weekend_outlined : Icons.no_meals_outlined);
    }
    if (gun.values.every((o) => o.bos)) {
      // o gün hiçbir öğünde yemek yok (örn. tatil): tek, net bir mesaj
      // okul bir not verdiyse (tatil vb.) o gösterilir; not yoksa "hizmet verilmiyor" denmez
      final not = gun.values.map((o) => o.not).whereType<String>().firstOrNull;
      return YemekYok(
          baslik: not ?? 'Bu gün yemek yok',
          alt: not != null
              ? 'Bu gün yemekhane hizmeti verilmiyor.'
              : 'Bu gün için menü yayınlanmamış.',
          ikon: Icons.celebration_outlined);
    }
    if (ogun == null || ogun.bos) {
      if (ogun?.not != null) {
        return YemekYok(
            baslik: ogun!.not!,
            alt: 'Bu gün $ogunAd yemeği yok.',
            ikon: Icons.celebration_outlined);
      }
      if (aktif == 'vegetarian') return EtsizOneri(gun: gun);
      return YemekYok(
          baslik: 'Bu gün $ogunAd yemeği yok',
          alt: 'Okul bu öğün için menü yayınlamadı.',
          ikon: Icons.no_meals_outlined);
    }
    return OgunKarti(
        ogun: ogun,
        fiyat: uni.ogrenciFiyati(aktif),
        fotoUrl: depo.fotoUrl(uni.id, ogun.foto),
        fotoYaklasik: ogun.fotoYaklasik,
        saat: uni.saat(aktif),
        uniId: uni.id,
        yemekFoto: depo.yemekFotoUrl,
        geriBildirim: geriBildirim,
        favoriler: favoriler,
        yemekAc: (yemek) => _yemekAc(context, yemek),
        kaloriHedefi: kaloriHedefi,
        // öğle ve akşam sekmelerinde günün iki öğününün toplamı da gösterilir
        ogleAksamKcal: aktif == 'lunch' || aktif == 'dinner'
            ? ogleAksamKalorisi(gun)
            : null,
        slot: slotKimligi(uni.id, tarih, aktif),
        reklam: reklam,
        reklamAnahtari: '$tarih|$aktif');
  }
}
