import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'reklam_ayari.dart';
import 'reklam_servisi.dart';

/// Gerçek servisi kurar (mobil). Hiçbir şey başlatılmaz: SDK ilk [ReklamServisi.hazirla] çağrısında açılır.
ReklamServisi gercekReklamServisiOlustur() => GercekReklamServisi();

class _GercekReklam implements ReklamNesnesi {
  _GercekReklam(this.reklam);
  final NativeAd reklam;
  @override
  Widget olustur(BuildContext context) => AdWidget(ad: reklam);
  @override
  void dispose() => reklam.dispose();
}

/// Google AdMob yerel (native) reklam servisi. Kimlik yoksa (kimliksiz release, web) [kullanilabilir] false'tur ve
/// SDK'ya hiç dokunulmaz. Rıza: Google UMP; rıza alınamazsa (canRequestAds false) istek atılmaz.
class GercekReklamServisi implements ReklamServisi {
  GercekReklamServisi() : _birim = gecerliReklamBirimi();

  /// Birimi elle verir (testler); null reklamın kapalı olduğu anlamına gelir.
  GercekReklamServisi.birimle(this._birim);
  final String? _birim;
  bool _baslatildi = false;

  @override
  bool get kullanilabilir => _birim != null;

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
      // 2) SDK yalnızca rıza uygunsa başlatılır
      if (!_baslatildi) {
        await MobileAds.instance
            .updateRequestConfiguration(RequestConfiguration(
                // genel izleyici: T (genç) ya da daha sıkı içerik
                maxAdContentRating: MaxAdContentRating.t));
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
    final sonuc = Completer<ReklamNesnesi?>();
    NativeAd? reklam;
    NativeTemplateTextStyle yazi(Color renk, double boyut,
            [NativeTemplateFontStyle? kalin]) =>
        NativeTemplateTextStyle(textColor: renk, size: boyut, style: kalin);
    try {
      reklam = NativeAd(
        adUnitId: birim,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.small,
          mainBackgroundColor: stil.arkaPlan,
          cornerRadius: stil.kose,
          primaryTextStyle:
              yazi(stil.birincilYazi, 15, NativeTemplateFontStyle.bold),
          secondaryTextStyle: yazi(stil.ikincilYazi, 13),
          tertiaryTextStyle: yazi(stil.ikincilYazi, 12),
          callToActionTextStyle: NativeTemplateTextStyle(
              textColor: stil.dugmeYazisi,
              backgroundColor: stil.dugme,
              style: NativeTemplateFontStyle.bold,
              size: 14),
        ),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!sonuc.isCompleted) {
              sonuc.complete(_GercekReklam(ad as NativeAd));
            }
          },
          onAdFailedToLoad: (ad, hata) {
            ad.dispose();
            if (!sonuc.isCompleted) sonuc.complete(null);
          },
        ),
      );
      await reklam.load();
    } catch (_) {
      if (!sonuc.isCompleted) sonuc.complete(null);
    }
    // ağ yanıt vermezse sonsuza dek beklenmesin
    return sonuc.future.timeout(const Duration(seconds: 20), onTimeout: () {
      // geç gelen reklam sızmasın
      reklam?.dispose();
      return null;
    });
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
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }
}
