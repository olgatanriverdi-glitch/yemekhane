import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'gec_yukleme.dart';
import 'reklam_ayari.dart';
import 'reklam_servisi.dart';
import 'uzak_ayar.dart';

/// Gerçek servisi kurar (mobil). Hiçbir şey başlatılmaz: SDK ilk [ReklamServisi.hazirla] çağrısında açılır.
ReklamServisi gercekReklamServisiOlustur() => GercekReklamServisi();

class _GercekReklam implements ReklamNesnesi {
  _GercekReklam(this.reklam);
  final NativeAd reklam;
  @override
  // Anahtar: aynı AdWidget öğesi başka bir reklamla yeniden kullanılırsa (ör. tema değişimi) paket reklam kaydını
  // yalnızca initState/dispose içinde yönettiğinden platform görünümü eski reklamda kalır. Anahtar öğeyi yeniler.
  Widget olustur(BuildContext context) =>
      AdWidget(key: ObjectKey(reklam), ad: reklam);
  @override
  void dispose() => reklam.dispose();
}

/// Google AdMob yerel (native) reklam servisi. Kimlik yoksa (kimliksiz release, web) [kullanilabilir] false'tur ve
/// SDK'ya hiç dokunulmaz. Rıza: Google UMP; rıza alınamazsa (canRequestAds false) istek atılmaz.
class GercekReklamServisi
    implements ReklamServisi, IcerikDerecesiAyarlanabilir {
  GercekReklamServisi()
      : _birim = gecerliReklamBirimi(),
        _odulluBirim = gecerliOdulluBirimi();

  /// Birimi elle verir (testler); null reklamın kapalı olduğu anlamına gelir.
  GercekReklamServisi.birimle(this._birim, [this._odulluBirim]);
  final String? _birim;
  final String? _odulluBirim;
  bool _baslatildi = false;
  String _maxIcerik = varsayilanIcerikDerecesi;

  @override
  set maxIcerik(String derece) => _maxIcerik = derece;

  /// Uzaktan ayardaki derece -> SDK sabiti. Bilinmeyen değer en sıkı dereceye (G) düşer.
  static String icerikDerecesiSabiti(String derece) => switch (derece) {
        'T' => MaxAdContentRating.t,
        'PG' => MaxAdContentRating.pg,
        _ => MaxAdContentRating.g,
      };

  @override
  bool get kullanilabilir => _birim != null;

  // Ödüllü özellik yalnızca reklam da mümkünse (rıza + SDK hazırlığı aynı yoldan geçer) açıktır.
  @override
  bool get odulluKullanilabilir => kullanilabilir && _odulluBirim != null;

  @override
  Future<bool> hazirla() async {
    if (!kullanilabilir) return false;
    try {
      // 1) rıza bilgisini güncelle; gerekliyse (AB / Birleşik Krallık...) Google'ın formu bir kez gösterilir
      final bilgi = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
          ConsentRequestParameters(),
          () => bilgi.complete(),
          // güncelleme başarısızsa son bilinen rıza durumuyla devam edilir (canRequestAds karar verir)
          (_) => bilgi.complete());
      await bilgi.future;
      final form = Completer<void>();
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!form.isCompleted) form.complete();
      });
      await form.future;
      if (!await ConsentInformation.instance.canRequestAds()) return false;
      // 2) içerik derecesi (her hazırlıkta; uzaktan değişmiş olabilir) ve SDK yalnızca rıza uygunsa başlatılır
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
          // varsayılan G (herkes / PEGI 3 hedefi); uzaktan PG ya da T'ye çıkarılabilir
          maxAdContentRating: icerikDerecesiSabiti(_maxIcerik)));
      if (!_baslatildi) {
        await MobileAds.instance.initialize();
        _baslatildi = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ReklamNesnesi?> yukle(ReklamStili stil) async {
    final birim = _birim;
    if (birim == null) return null;
    final koruma = GecYuklemeKorumasi();
    NativeTemplateTextStyle yazi(Color renk, double boyut,
            [NativeTemplateFontStyle? kalin]) =>
        NativeTemplateTextStyle(textColor: renk, size: boyut, style: kalin);
    try {
      final reklam = NativeAd(
        adUnitId: birim,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: stil.buyuk ? TemplateType.medium : TemplateType.small,
          mainBackgroundColor: stil.arkaPlan,
          cornerRadius: stil.kose,
          primaryTextStyle: yazi(stil.birincilYazi, stil.baslikBoyutu,
              NativeTemplateFontStyle.bold),
          secondaryTextStyle: yazi(stil.ikincilYazi, stil.govdeBoyutu),
          tertiaryTextStyle: yazi(stil.ikincilYazi, stil.kucukBoyut),
          callToActionTextStyle: NativeTemplateTextStyle(
              textColor: stil.dugmeYazisi,
              backgroundColor: stil.dugme,
              style: NativeTemplateFontStyle.bold,
              size: stil.dugmeBoyutu),
        ),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            koruma.yuklendi(_GercekReklam(ad as NativeAd));
          },
          onAdFailedToLoad: (ad, hata) {
            ad.dispose();
            koruma.basarisiz();
          },
        ),
      );
      await reklam.load();
    } catch (_) {
      koruma.basarisiz();
    }
    // ağ yanıt vermezse sonsuza dek beklenmesin; geç gelen reklam dinleyicide serbest bırakılır (bkz. GecYuklemeKorumasi)
    return koruma.bekle(const Duration(seconds: 20));
  }

  @override
  Future<OdulluSonuc> odulluIzle() async {
    final birim = _odulluBirim;
    if (!odulluKullanilabilir || birim == null) return OdulluSonuc.yuklenemedi;
    final bitti = Completer<OdulluSonuc>();
    var zamanAsimi = false;
    var odulVerildi = false;
    var gosterimde = false;
    void bitir(OdulluSonuc s) {
      if (!bitti.isCompleted) bitti.complete(s);
    }

    try {
      await RewardedAd.load(
        adUnitId: birim,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (zamanAsimi || bitti.isCompleted) {
              // geç gelen reklam gösterilmez, serbest bırakılır
              ad.dispose();
              return;
            }
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (a) {
                a.dispose();
                // ödül yalnızca onUserEarnedReward gelmişse; kapatma ödül değildir
                bitir(odulVerildi ? OdulluSonuc.odul : OdulluSonuc.kapatildi);
              },
              onAdFailedToShowFullScreenContent: (a, _) {
                a.dispose();
                bitir(OdulluSonuc.yuklenemedi);
              },
            );
            gosterimde = true;
            ad.show(onUserEarnedReward: (_, __) => odulVerildi = true);
          },
          onAdFailedToLoad: (_) => bitir(OdulluSonuc.yuklenemedi),
        ),
      );
    } catch (_) {
      bitir(OdulluSonuc.yuklenemedi);
    }
    // yükleme 20 sn içinde bitmezse vazgeçilir; reklam sonradan gelirse yukarıda serbest bırakılır. Reklam
    // gösterilmeye başlandıysa kullanıcı izlerken süre sayılmaz (kapanışı beklenir).
    final sayac = Timer(const Duration(seconds: 20), () {
      if (gosterimde) return;
      zamanAsimi = true;
      bitir(OdulluSonuc.yuklenemedi);
    });
    final sonuc = await bitti.future;
    sayac.cancel();
    return sonuc;
  }

  @override
  Future<bool> tercihGerekli() async {
    if (!kullanilabilir) return false;
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> tercihleriAc() async {
    try {
      // form kapanınca (kullanıcı tercihi kaydedip döndüğünde) tamamlanır; yönetici o zaman hazırlığı yeniler
      final bitti = Completer<void>();
      await ConsentForm.showPrivacyOptionsForm((_) {
        if (!bitti.isCompleted) bitti.complete();
      });
      await bitti.future;
    } catch (_) {}
  }
}
