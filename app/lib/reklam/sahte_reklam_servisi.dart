import 'dart:async';

import 'package:flutter/material.dart';

import 'reklam_ayari.dart';
import 'reklam_servisi.dart';

/// Sahte reklam: ağ ve platform kanalı yok, yalnızca bir kart çizer. Testlerde ve mağaza görseli üretirken kullanılır.
class SahteReklamNesnesi implements ReklamNesnesi {
  SahteReklamNesnesi(this.no, {this.stil});
  final int no;
  final ReklamStili? stil;
  bool kapandi = false;

  @override
  Widget olustur(BuildContext context) {
    assert(!kapandi, 'serbest bırakılmış reklam çizilemez');
    final r = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('sahte-reklam-$no'),
      height: stil?.buyuk == true ? 360 : 91,
      color: stil?.arkaPlan,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: r.primaryContainer,
                borderRadius: BorderRadius.circular(12)),
            child:
                Icon(Icons.local_offer_outlined, color: r.onPrimaryContainer)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Örnek reklam başlığı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: stil?.birincilYazi ?? r.onSurface,
                      fontWeight: FontWeight.w600)),
              Text('Reklam açıklaması burada görünür',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: stil?.ikincilYazi ?? r.onSurfaceVariant)),
            ])),
      ]),
    );
  }

  @override
  void dispose() => kapandi = true;
}

/// Sahte servis; çağrı sayaçları testlerde doğrulanır. [gecikme] verilirse yükleme o kadar sürer.
class SahteReklamServisi implements ReklamServisi, IcerikDerecesiAyarlanabilir {
  SahteReklamServisi(
      {this.kullanilabilir = true,
      this.rizaVar = true,
      this.basarili = true,
      this.tercih = false,
      this.odulluVar = true,
      this.odulluSonucu = OdulluSonuc.odul,
      this.gecikme = Duration.zero});
  @override
  bool kullanilabilir;
  bool rizaVar;

  /// false ise [yukle] null döner (yüklenemedi / dolu reklam yok).
  bool basarili;
  bool tercih;

  /// Ödüllü reklam bu derlemede mümkün mü?
  bool odulluVar;

  /// [odulluIzle]nin döneceği sonuç.
  OdulluSonuc odulluSonucu;
  Duration gecikme;
  int odulluSayisi = 0;
  final List<ReklamStili> istenenStiller = [];

  /// Yöneticinin verdiği içerik derecesi.
  @override
  String maxIcerik = 'G';

  /// [hazirla] her çağrıldığında sırayla bu sonuçlar kullanılır (boşalınca [rizaVar]); tercih değişimi testleri için.
  final List<bool> hazirlaSonuclari = [];
  final List<String> hazirlaDereceleri = [];
  int hazirlaSayisi = 0;
  int yukleSayisi = 0;
  int tercihAcSayisi = 0;
  final List<SahteReklamNesnesi> yuklenenler = [];

  /// Serbest bırakılmamış (dispose edilmemiş) reklam sayısı.
  int get acikReklam => yuklenenler.where((r) => !r.kapandi).length;

  @override
  Future<bool> hazirla() async {
    hazirlaSayisi++;
    hazirlaDereceleri.add(maxIcerik);
    return hazirlaSonuclari.isNotEmpty ? hazirlaSonuclari.removeAt(0) : rizaVar;
  }

  @override
  Future<ReklamNesnesi?> yukle(ReklamStili stil) async {
    yukleSayisi++;
    istenenStiller.add(stil);
    if (gecikme > Duration.zero) await Future<void>.delayed(gecikme);
    if (!basarili) return null;
    final r = SahteReklamNesnesi(yukleSayisi, stil: stil);
    yuklenenler.add(r);
    return r;
  }

  @override
  bool get odulluKullanilabilir => odulluVar;

  @override
  Future<OdulluSonuc> odulluIzle() async {
    odulluSayisi++;
    if (gecikme > Duration.zero) await Future<void>.delayed(gecikme);
    return odulluSonucu;
  }

  @override
  Future<bool> tercihGerekli() async => tercih;

  @override
  Future<void> tercihleriAc() async => tercihAcSayisi++;
}
