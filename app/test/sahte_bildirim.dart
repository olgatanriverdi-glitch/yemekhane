import 'dart:async';

import 'package:yemekhane/bildirim_plani.dart';
import 'package:yemekhane/bildirim_servisi.dart';

/// Gerçek bildirim eklentisine dokunmayan sahte servis: çağrıları sırayla kaydeder. Bildirim testlerinin ortak
/// yardımcısıdır (bkz. bildirim_*_test.dart).
class SahteBildirimServisi implements BildirimServisi {
  /// [izinIste]nin döndüreceği değer.
  bool izin;

  /// true ise [izinIste] istisna fırlatır.
  bool izinHata = false;

  /// true ise [planla] ve [hepsiniIptal] istisna fırlatır.
  bool planHata = false;

  /// Doluysa [hepsiniIptal] bu tamamlanana kadar bekler (sıralamayı sınamak için).
  Completer<void>? iptalKapisi;

  /// Çağrı günlüğü, sırayla: 'izin', 'iptal', 'planla'.
  final List<String> cagrilar = [];

  /// Her [planla] çağrısında verilen liste.
  final List<List<PlanliBildirim>> planlar = [];

  SahteBildirimServisi({this.izin = true});

  int sayi(String ad) => cagrilar.where((c) => c == ad).length;

  /// Son [planla] çağrısındaki liste (hiç çağrılmadıysa boş).
  List<PlanliBildirim> get sonPlan => planlar.isEmpty ? const [] : planlar.last;

  @override
  Future<bool> izinIste() async {
    cagrilar.add('izin');
    if (izinHata) throw Exception('izin penceresi açılamadı');
    return izin;
  }

  @override
  Future<void> planla(List<PlanliBildirim> bildirimler) async {
    cagrilar.add('planla');
    planlar.add(List.of(bildirimler));
    if (planHata) throw Exception('planlanamadı');
  }

  @override
  Future<void> hepsiniIptal() async {
    cagrilar.add('iptal');
    final kapi = iptalKapisi;
    if (kapi != null) await kapi.future;
    if (planHata) throw Exception('iptal edilemedi');
  }
}
